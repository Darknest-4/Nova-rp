import { deflateRawSync } from 'node:zlib';
import { describe, expect, it } from 'vitest';

import { crc32, readZip, isSafeEntryPath } from '../src/lib/zip.ts';

/**
 * A ZIP-olvasót valódi, kézzel összeállított archívumokon teszteljük.
 * Így a teszt nem függ külső fájltól, és a formátum minden ágát lefedi.
 */

interface FileSpec {
  name: string;
  content: Buffer;
  method: 0 | 8;
}

function buildZip(files: FileSpec[]): Buffer {
  const locals: Buffer[] = [];
  const centrals: Buffer[] = [];
  let offset = 0;

  for (const file of files) {
    const nameBytes = Buffer.from(file.name, 'utf8');
    const payload = file.method === 8 ? deflateRawSync(file.content) : file.content;
    const crc = crc32(file.content);

    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x0403_4b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(file.method, 8);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(payload.length, 18);
    local.writeUInt32LE(file.content.length, 22);
    local.writeUInt16LE(nameBytes.length, 26);
    locals.push(Buffer.concat([local, nameBytes, payload]));

    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x0201_4b50, 0);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(file.method, 10);
    central.writeUInt32LE(crc, 16);
    central.writeUInt32LE(payload.length, 20);
    central.writeUInt32LE(file.content.length, 24);
    central.writeUInt16LE(nameBytes.length, 28);
    central.writeUInt32LE(offset, 42);
    centrals.push(Buffer.concat([central, nameBytes]));

    offset += 30 + nameBytes.length + payload.length;
  }

  const localBlock = Buffer.concat(locals);
  const centralBlock = Buffer.concat(centrals);
  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x0605_4b50, 0);
  eocd.writeUInt16LE(files.length, 8);
  eocd.writeUInt16LE(files.length, 10);
  eocd.writeUInt32LE(centralBlock.length, 12);
  eocd.writeUInt32LE(localBlock.length, 16);

  return Buffer.concat([localBlock, centralBlock, eocd]);
}

describe('crc32', () => {
  it('az ismert referenciaértéket adja', () => {
    // A "123456789" CRC-32 értéke szabvány szerint 0xCBF43926.
    expect(crc32(Buffer.from('123456789'))).toBe(0xcbf4_3926);
  });
});

describe('readZip', () => {
  it('kicsomagolja a deflate-tömörített bejegyzést', () => {
    const content = Buffer.from('fx_version "cerulean"\n'.repeat(50), 'utf8');
    const entries = readZip(buildZip([{ name: 'ox_lib/fxmanifest.lua', content, method: 8 }]));

    expect(entries).toHaveLength(1);
    expect(entries[0]?.path).toBe('ox_lib/fxmanifest.lua');
    expect(entries[0]?.data.toString('utf8')).toBe(content.toString('utf8'));
  });

  it('kicsomagolja a tömörítetlen bejegyzést', () => {
    const content = Buffer.from('árvíztűrő tükörfúrógép', 'utf8');
    const entries = readZip(buildZip([{ name: 'a.txt', content, method: 0 }]));
    expect(entries[0]?.data.toString('utf8')).toBe('árvíztűrő tükörfúrógép');
  });

  it('több bejegyzést helyes sorrendben olvas', () => {
    const entries = readZip(buildZip([
      { name: 'a.lua', content: Buffer.from('a'), method: 0 },
      { name: 'b/c.lua', content: Buffer.from('c'), method: 8 },
    ]));
    expect(entries.map((entry) => entry.path)).toEqual(['a.lua', 'b/c.lua']);
  });

  it('sérült adatot CRC-hibaként jelez', () => {
    const zip = buildZip([{ name: 'a.txt', content: Buffer.from('eredeti'), method: 0 }]);
    zip.write('X', 30 + 'a.txt'.length); // az adat első bájtjának átírása
    expect(() => readZip(zip)).toThrow(/CRC/);
  });

  it('érvénytelen archívumot érthető hibával utasít el', () => {
    expect(() => readZip(Buffer.from('nem zip'))).toThrow(/központi könyvtár/);
  });
});

describe('isSafeEntryPath (zip slip elleni védelem)', () => {
  it('elfogadja a normál relatív útvonalat', () => {
    expect(isSafeEntryPath('ox_lib/imports/init.lua')).toBe(true);
  });

  it('elutasítja a könyvtárból kilépő útvonalat', () => {
    expect(isSafeEntryPath('../etc/passwd')).toBe(false);
    expect(isSafeEntryPath('ox_lib/../../evil.lua')).toBe(false);
    expect(isSafeEntryPath('ox_lib\\..\\evil.lua')).toBe(false);
  });

  it('elutasítja az abszolút útvonalat', () => {
    expect(isSafeEntryPath('/etc/passwd')).toBe(false);
    expect(isSafeEntryPath('C:\\Windows\\evil.dll')).toBe(false);
  });
});
