import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';

import { log, color, NovaError } from '../lib/log.ts';
import { paths } from '../lib/paths.ts';
import { readZip, isSafeEntryPath } from '../lib/zip.ts';

interface VendorResource {
  name: string;
  version: string;
  repository: string;
  asset: string;
  sha256: string;
  license: string;
  docs: string;
  purpose: string;
}

interface VendorManifest {
  installDir: string;
  resources: VendorResource[];
}

const REQUIRED_FIELDS: (keyof VendorResource)[] = [
  'name', 'version', 'repository', 'asset', 'sha256', 'license', 'docs', 'purpose',
];

/** A vendor.json beolvasása és ellenőrzése. Hiányos tétel = hiba, nem figyelmeztetés. */
export function loadManifest(raw?: string): VendorManifest {
  const text = raw ?? readFileSync(paths.vendorManifest(), 'utf8');
  const parsed = JSON.parse(text) as Partial<VendorManifest>;

  if (typeof parsed.installDir !== 'string' || !Array.isArray(parsed.resources)) {
    throw new NovaError('Hibás vendor.json: hiányzik az installDir vagy a resources.');
  }

  parsed.resources.forEach((resource, index) => {
    for (const field of REQUIRED_FIELDS) {
      if (typeof resource[field] !== 'string' || resource[field] === '') {
        throw new NovaError(
          `Hibás vendor.json: a(z) #${index + 1}. tételből hiányzik a "${field}" mező.`,
          'Minden függőséghez kötelező a verzió, a checksum, a licenc és az adatlap.',
        );
      }
    }
    if (!/^[0-9a-f]{64}$/.test(resource.sha256)) {
      throw new NovaError(`Hibás SHA-256 a(z) "${resource.name}" tételnél.`);
    }
    if (!resource.asset.startsWith('https://')) {
      throw new NovaError(`A(z) "${resource.name}" letöltési címe nem HTTPS.`);
    }
  });

  return parsed as VendorManifest;
}

async function download(url: string): Promise<Buffer> {
  const response = await fetch(url, { redirect: 'follow' });
  if (!response.ok) {
    throw new NovaError(
      `Letöltés sikertelen (HTTP ${response.status}): ${url}`,
      'Ellenőrizd az internetkapcsolatot, illetve hogy a megadott verzió létezik-e.',
    );
  }
  return Buffer.from(await response.arrayBuffer());
}

export function sha256(buffer: Buffer): string {
  return createHash('sha256').update(buffer).digest('hex');
}

/** Egy vendor-resource telepítése: letöltés → checksum → kicsomagolás. */
async function installResource(resource: VendorResource, installRoot: string): Promise<void> {
  log.step(`${color.bold(resource.name)} ${resource.version} (${resource.license})`);

  const archive = await download(resource.asset);
  const actual = sha256(archive);

  if (actual !== resource.sha256) {
    throw new NovaError(
      `Checksum-eltérés: ${resource.name}`,
      `Várt:    ${resource.sha256}\n  Kapott:  ${actual}\n` +
        '  A letöltött csomag NEM az, amit a vendor.json rögzít. Ne telepítsd.\n' +
        '  Ha szándékosan emeltél verziót, frissítsd a vendor.json-t is (külön PR-ben).',
    );
  }
  log.detail(`checksum rendben (${actual.slice(0, 16)}…)`);

  const target = join(installRoot, resource.name);
  rmSync(target, { recursive: true, force: true });

  const entries = readZip(archive);
  let written = 0;

  for (const entry of entries) {
    if (!isSafeEntryPath(entry.path)) {
      throw new NovaError(`Gyanús útvonal az archívumban: ${entry.path}`);
    }
    // A release-zipek gyökere maga a resource mappa (pl. "ox_lib/..."),
    // ezt levágjuk, hogy ne legyen ox_lib/ox_lib/ szerkezet.
    const relative = entry.path.replace(/^[^/]+\//, '');
    if (relative === '' || entry.isDirectory) continue;

    const destination = join(target, relative);
    mkdirSync(dirname(destination), { recursive: true });
    writeFileSync(destination, entry.data);
    written += 1;
  }

  log.ok(`${resource.name}: ${written} fájl → ${target.replace(paths.root(), '.')}`);
}

export async function vendorInstall(): Promise<void> {
  const manifest = loadManifest();
  const installRoot = join(paths.root(), manifest.installDir);
  mkdirSync(installRoot, { recursive: true });

  log.info(color.bold('Third-party függőségek telepítése'));
  log.detail('Forrás: vendor.json (pinelt verzió + SHA-256 integritás-ellenőrzés)');
  log.blank();

  for (const resource of manifest.resources) {
    await installResource(resource, installRoot);
  }

  log.blank();
  log.ok(`${manifest.resources.length} függőség telepítve.`);
  log.detail('Ne felejtsd bekapcsolni őket a server/cfg/20-resources.cfg-ben.');
}

/** Csak ellenőrzés: megvan-e minden vendor-resource és az adatlapja. */
export function vendorVerify(): number {
  const manifest = loadManifest();
  const installRoot = join(paths.root(), manifest.installDir);
  let problems = 0;

  for (const resource of manifest.resources) {
    const target = join(installRoot, resource.name);
    const docs = join(paths.root(), resource.docs);

    if (!existsSync(target)) {
      log.fail(`${resource.name}: nincs telepítve (futtasd: nova vendor:install)`);
      problems += 1;
    } else if (!existsSync(join(target, 'fxmanifest.lua'))) {
      log.fail(`${resource.name}: hiányzik az fxmanifest.lua — sérült telepítés`);
      problems += 1;
    } else {
      log.ok(`${resource.name} ${resource.version} — ${resource.license}`);
    }

    if (!existsSync(docs)) {
      log.fail(`${resource.name}: hiányzik a függőség-adatlap (${resource.docs})`);
      problems += 1;
    }
  }

  return problems;
}
