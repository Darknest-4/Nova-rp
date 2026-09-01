import { existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { NovaError } from './log.ts';

/**
 * A repository gyökerének megkeresése.
 *
 * Nem a munkakönyvtárból indul ki, hanem a saját fájl helyéből: így a parancsok
 * bárhonnan futtathatók (tools/-ból, gyökérből, IDE-ből egyaránt).
 */
export function repoRoot(): string {
  let dir = dirname(fileURLToPath(import.meta.url));

  for (let depth = 0; depth < 10; depth += 1) {
    if (existsSync(join(dir, 'vendor.json')) && existsSync(join(dir, 'resources'))) {
      return dir;
    }
    const parent = resolve(dir, '..');
    if (parent === dir) break;
    dir = parent;
  }

  throw new NovaError(
    'Nem találom a repository gyökerét.',
    'A vendor.json és a resources/ mappa alapján keresem. Klónozott repóban futtasd.',
  );
}

export const paths = {
  root: repoRoot,
  vendorManifest: () => join(repoRoot(), 'vendor.json'),
  resources: () => join(repoRoot(), 'resources'),
  serverCfg: () => join(repoRoot(), 'server', 'cfg'),
  docs: () => join(repoRoot(), 'docs'),
};
