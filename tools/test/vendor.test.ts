import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

import { loadManifest, sha256 } from '../src/commands/vendor.ts';
import { paths } from '../src/lib/paths.ts';

describe('vendor manifest', () => {
  it('a repository vendor.json-ja érvényes', () => {
    const manifest = loadManifest();
    expect(manifest.resources.length).toBeGreaterThan(0);
  });

  it('minden függőségnek van licence és adatlapja a repóban', () => {
    const manifest = loadManifest();
    for (const resource of manifest.resources) {
      expect(resource.license, `${resource.name} licenc`).toMatch(/GPL|MIT|Apache|BSD/);
      // Az adatlap létezését a `nova vendor:verify` is ellenőrzi; itt azt
      // rögzítjük, hogy a hivatkozás egyáltalán a docs/ alá mutat.
      expect(resource.docs).toMatch(/^docs\/dependencies\/.+\.md$/);
    }
  });

  it('elutasítja a checksum nélküli tételt', () => {
    const raw = JSON.stringify({
      installDir: 'resources/[vendor]',
      resources: [{
        name: 'x', version: 'v1', repository: 'https://example.invalid',
        asset: 'https://example.invalid/x.zip', license: 'MIT',
        docs: 'docs/dependencies/x.md', purpose: 'teszt',
      }],
    });
    expect(() => loadManifest(raw)).toThrow(/sha256/);
  });

  it('elutasítja a hibás formátumú checksumot', () => {
    const raw = JSON.stringify({
      installDir: 'resources/[vendor]',
      resources: [{
        name: 'x', version: 'v1', repository: 'https://example.invalid',
        asset: 'https://example.invalid/x.zip', sha256: 'túl-rövid', license: 'MIT',
        docs: 'docs/dependencies/x.md', purpose: 'teszt',
      }],
    });
    expect(() => loadManifest(raw)).toThrow(/SHA-256/);
  });

  it('elutasítja a nem HTTPS letöltési címet', () => {
    const raw = JSON.stringify({
      installDir: 'resources/[vendor]',
      resources: [{
        name: 'x', version: 'v1', repository: 'https://example.invalid',
        asset: 'http://example.invalid/x.zip', sha256: 'a'.repeat(64), license: 'MIT',
        docs: 'docs/dependencies/x.md', purpose: 'teszt',
      }],
    });
    expect(() => loadManifest(raw)).toThrow(/HTTPS/);
  });
});

describe('sha256', () => {
  it('az ismert referenciaértéket adja', () => {
    expect(sha256(Buffer.from('abc'))).toBe(
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });
});

describe('repoRoot', () => {
  it('a gyökérből találja a vendor.json-t', () => {
    const manifestPath = join(paths.root(), 'vendor.json');
    expect(() => readFileSync(manifestPath, 'utf8')).not.toThrow();
  });
});
