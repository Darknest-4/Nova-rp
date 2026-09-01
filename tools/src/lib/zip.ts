import { inflateRawSync } from 'node:zlib';

import { NovaError } from './log.ts';

/**
 * Minimális ZIP-kicsomagoló.
 *
 * Miért saját, és nem npm-csomag?
 *   - Egy telepítő eszköznek a lehető legkevesebb függősége legyen: minél
 *     kevesebb idegen kód fut privilegizált helyzetben (fájlt ír a repóba).
 *   - A Node beépített zlib-je mindent tud, ami egy release-zip-hez kell.
 *   - Így a `nova vendor:install` Windows/Linux/macOS alatt egyformán működik,
 *     külső `unzip` parancs nélkül.
 *
 * Amit tud: "stored" (0) és "deflate" (8) tömörítés, CRC-32 ellenőrzéssel.
 * Amit NEM tud: ZIP64, titkosított bejegyzés — ezeket felismeri és
 * érthető hibával elutasítja, nem csendben rontja el a kimenetet.
 */

const SIG_EOCD = 0x0605_4b50;
const SIG_CENTRAL = 0x0201_4b50;
const SIG_LOCAL = 0x0403_4b50;
const METHOD_STORED = 0;
const METHOD_DEFLATE = 8;

export interface ZipEntry {
  /** A bejegyzés útvonala a zip-en belül, `/` elválasztóval. */
  path: string;
  /** Igaz, ha könyvtár-bejegyzés (nincs tartalma). */
  isDirectory: boolean;
  data: Buffer;
}

const crcTable = ((): Uint32Array => {
  const table = new Uint32Array(256);
  for (let index = 0; index < 256; index += 1) {
    let value = index;
    for (let bit = 0; bit < 8; bit += 1) {
      value = value & 1 ? 0xedb8_8320 ^ (value >>> 1) : value >>> 1;
    }
    table[index] = value >>> 0;
  }
  return table;
})();

export function crc32(buffer: Buffer): number {
  let crc = 0xffff_ffff;
  for (const byte of buffer) {
    crc = (crc >>> 8) ^ (crcTable[(crc ^ byte) & 0xff] as number);
  }
  return (crc ^ 0xffff_ffff) >>> 0;
}

/** Az End of Central Directory rekord megkeresése a fájl végéről visszafelé. */
function findEndOfCentralDirectory(buffer: Buffer): number {
  const minimumSize = 22;
  const searchLimit = Math.min(buffer.length, 0xffff + minimumSize);

  for (let offset = buffer.length - minimumSize; offset >= buffer.length - searchLimit; offset -= 1) {
    if (offset < 0) break;
    if (buffer.readUInt32LE(offset) === SIG_EOCD) return offset;
  }

  throw new NovaError(
    'Érvénytelen ZIP: nem található a központi könyvtár vége.',
    'Valószínűleg félbeszakadt letöltés. Töröld a gyorsítótárat és próbáld újra.',
  );
}

/**
 * Kicsomagolja a ZIP tartalmát a memóriába.
 * @param buffer a teljes ZIP fájl
 */
export function readZip(buffer: Buffer): ZipEntry[] {
  const eocd = findEndOfCentralDirectory(buffer);
  const entryCount = buffer.readUInt16LE(eocd + 10);
  const centralOffset = buffer.readUInt32LE(eocd + 16);

  if (centralOffset === 0xffff_ffff || entryCount === 0xffff) {
    throw new NovaError('A ZIP64 formátumot ez az eszköz nem támogatja.');
  }

  const entries: ZipEntry[] = [];
  let cursor = centralOffset;

  for (let index = 0; index < entryCount; index += 1) {
    if (buffer.readUInt32LE(cursor) !== SIG_CENTRAL) {
      throw new NovaError(`Érvénytelen ZIP: sérült központi bejegyzés (#${index + 1}).`);
    }

    const flags = buffer.readUInt16LE(cursor + 8);
    const method = buffer.readUInt16LE(cursor + 10);
    const expectedCrc = buffer.readUInt32LE(cursor + 16);
    const compressedSize = buffer.readUInt32LE(cursor + 20);
    const uncompressedSize = buffer.readUInt32LE(cursor + 24);
    const nameLength = buffer.readUInt16LE(cursor + 28);
    const extraLength = buffer.readUInt16LE(cursor + 30);
    const commentLength = buffer.readUInt16LE(cursor + 32);
    const localOffset = buffer.readUInt32LE(cursor + 42);
    const name = buffer.toString('utf8', cursor + 46, cursor + 46 + nameLength);

    if ((flags & 0x1) !== 0) {
      throw new NovaError(`Titkosított ZIP-bejegyzés nem támogatott: ${name}`);
    }
    if (compressedSize === 0xffff_ffff || uncompressedSize === 0xffff_ffff) {
      throw new NovaError('A ZIP64 formátumot ez az eszköz nem támogatja.');
    }

    const isDirectory = name.endsWith('/');
    if (!isDirectory) {
      if (buffer.readUInt32LE(localOffset) !== SIG_LOCAL) {
        throw new NovaError(`Érvénytelen ZIP: hiányzó lokális fejléc (${name}).`);
      }
      const localNameLength = buffer.readUInt16LE(localOffset + 26);
      const localExtraLength = buffer.readUInt16LE(localOffset + 28);
      const dataStart = localOffset + 30 + localNameLength + localExtraLength;
      const raw = buffer.subarray(dataStart, dataStart + compressedSize);

      let data: Buffer;
      if (method === METHOD_STORED) {
        data = Buffer.from(raw);
      } else if (method === METHOD_DEFLATE) {
        data = inflateRawSync(raw);
      } else {
        throw new NovaError(`Nem támogatott tömörítés (${method}) ebben a bejegyzésben: ${name}`);
      }

      if (data.length !== uncompressedSize) {
        throw new NovaError(`Méreteltérés a kicsomagolás után: ${name}`);
      }
      if (crc32(data) !== expectedCrc) {
        throw new NovaError(`CRC hiba (sérült adat): ${name}`);
      }

      entries.push({ path: name, isDirectory: false, data });
    } else {
      entries.push({ path: name, isDirectory: true, data: Buffer.alloc(0) });
    }

    cursor += 46 + nameLength + extraLength + commentLength;
  }

  return entries;
}

/**
 * Biztonságos célútvonal ellenőrzése.
 *
 * A "zip slip" támadás lényege, hogy az archívum `../../etc/valami` nevű
 * bejegyzést tartalmaz, és a kicsomagoló a célmappán KÍVÜLRE ír. Ezt itt
 * kizárjuk, mert a vendor-csomagok kívülről érkeznek.
 */
export function isSafeEntryPath(entryPath: string): boolean {
  if (entryPath.startsWith('/') || entryPath.startsWith('\\')) return false;
  if (/^[a-zA-Z]:/.test(entryPath)) return false;
  return !entryPath
    .split(/[\\/]/)
    .some((segment) => segment === '..');
}
