import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';

import { log, color } from '../lib/log.ts';
import { paths } from '../lib/paths.ts';

/**
 * Környezet-ellenőrzés.
 *
 * Célja, hogy egy új fejlesztő EGY parancsból megtudja, mi hiányzik, és
 * pontosan mit kell tennie — ne szerver-indítási hibaüzenetből kelljen
 * visszafejtenie.
 */

export interface Check {
  name: string;
  status: 'ok' | 'warn' | 'fail';
  detail: string;
  hint?: string;
}

/** Egy parancs verziójának lekérdezése. `null`, ha a parancs nem található. */
function probeVersion(command: string, args: string[]): string | null {
  try {
    return execFileSync(command, args, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
      timeout: 10_000,
    }).trim().split('\n')[0] ?? null;
  } catch {
    return null;
  }
}

/** "v22.11.0" / "22.11.0" -> 22 */
export function majorVersion(raw: string): number | null {
  const match = /(\d+)\.(\d+)\.(\d+)/.exec(raw);
  return match ? Number(match[1]) : null;
}

export function runChecks(): Check[] {
  const root = paths.root();
  const checks: Check[] = [];

  // ── Node.js ────────────────────────────────────────────────────────────────
  const nodeMajor = majorVersion(process.version);
  checks.push(
    nodeMajor !== null && nodeMajor >= 22
      ? { name: 'Node.js', status: 'ok', detail: process.version }
      : {
          name: 'Node.js',
          status: 'fail',
          detail: `${process.version} — legalább 22 (LTS) kell`,
          hint: 'Telepítsd az .nvmrc-ben rögzített verziót: nvm install && nvm use',
        },
  );

  // ── Git ────────────────────────────────────────────────────────────────────
  const git = probeVersion('git', ['--version']);
  checks.push(
    git
      ? { name: 'Git', status: 'ok', detail: git }
      : { name: 'Git', status: 'fail', detail: 'nincs telepítve', hint: 'https://git-scm.com/downloads' },
  );

  // ── Lua (a unit tesztekhez) ────────────────────────────────────────────────
  const lua = probeVersion('lua5.4', ['-v']) ?? probeVersion('lua', ['-v']);
  checks.push(
    lua
      ? { name: 'Lua 5.4', status: 'ok', detail: lua }
      : {
          name: 'Lua 5.4',
          status: 'warn',
          detail: 'nincs telepítve — a Lua unit tesztek nem futtathatók',
          hint: 'Debian/Ubuntu: sudo apt-get install lua5.4 luarocks liblua5.4-dev',
        },
  );

  const busted = probeVersion('busted', ['--version']);
  checks.push(
    busted
      ? { name: 'busted', status: 'ok', detail: busted }
      : {
          name: 'busted',
          status: 'warn',
          detail: 'nincs telepítve — a Lua unit tesztek nem futtathatók',
          hint: 'luarocks --lua-version=5.4 install busted',
        },
  );

  // ── Projekt-fájlok ─────────────────────────────────────────────────────────
  const serverCfg = join(root, 'server', 'server.cfg');
  checks.push(
    existsSync(serverCfg)
      ? { name: 'server.cfg', status: 'ok', detail: 'létezik' }
      : {
          name: 'server.cfg',
          status: 'warn',
          detail: 'még nincs létrehozva',
          hint: 'cp server/server.cfg.example server/server.cfg',
        },
  );

  const localCfg = join(root, 'server', 'cfg', '90-local.cfg');
  checks.push(
    existsSync(localCfg)
      ? { name: 'cfg/90-local.cfg', status: 'ok', detail: 'létezik (titkok itt élnek)' }
      : {
          name: 'cfg/90-local.cfg',
          status: 'warn',
          detail: 'még nincs létrehozva — licenckulcs nélkül a szerver nem indul',
          hint: 'cp server/cfg/90-local.cfg.example server/cfg/90-local.cfg',
        },
  );

  const vendorDir = join(root, 'resources', '[vendor]');
  checks.push(
    existsSync(vendorDir)
      ? { name: 'vendor függőségek', status: 'ok', detail: 'telepítve' }
      : {
          name: 'vendor függőségek',
          status: 'warn',
          detail: 'nincsenek telepítve',
          hint: 'cd tools && npm run vendor:install',
        },
  );

  // ── Titok-szivárgás ellenőrzése ────────────────────────────────────────────
  // Olcsó, de sokat érő védelem: ha a titkos cfg valaha verziókövetésbe kerül,
  // az azonnal derüljön ki, ne egy publikus repóból.
  try {
    const tracked = execFileSync('git', ['ls-files', 'server/cfg/90-local.cfg', 'server/server.cfg'], {
      cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    checks.push(
      tracked === ''
        ? { name: 'titok-szivárgás', status: 'ok', detail: 'a titkos fájlok nincsenek verziókövetve' }
        : {
            name: 'titok-szivárgás',
            status: 'fail',
            detail: `verziókövetés alatt: ${tracked.replace(/\n/g, ', ')}`,
            hint: 'git rm --cached <fájl> — és cseréld le az érintett titkokat!',
          },
    );
  } catch {
    checks.push({ name: 'titok-szivárgás', status: 'warn', detail: 'nem ellenőrizhető (nincs git repo?)' });
  }

  return checks;
}

/** @returns a folyamat kilépési kódja (0 = rendben) */
export function doctor(): number {
  log.info(color.bold('NOVA RP — környezet-ellenőrzés'));
  log.blank();

  const checks = runChecks();
  for (const check of checks) {
    const line = `${check.name.padEnd(22)} ${check.detail}`;
    if (check.status === 'ok') log.ok(line);
    else if (check.status === 'warn') log.warn(line);
    else log.fail(line);
    if (check.hint && check.status !== 'ok') log.detail(check.hint);
  }

  const failures = checks.filter((check) => check.status === 'fail').length;
  const warnings = checks.filter((check) => check.status === 'warn').length;

  log.blank();
  if (failures > 0) {
    log.fail(`${failures} hiba, ${warnings} figyelmeztetés. A hibákat javítsd, mielőtt továbbmész.`);
    return 1;
  }
  if (warnings > 0) {
    log.warn(`${warnings} figyelmeztetés. A szerver ezekkel még nem indul el — lásd QUICKSTART.md`);
    return 0;
  }
  log.ok('Minden rendben.');
  return 0;
}
