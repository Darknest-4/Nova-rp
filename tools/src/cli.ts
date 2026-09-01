#!/usr/bin/env node
/**
 * NOVA RP fejlesztői CLI.
 *
 * Használat a tools/ mappából:
 *     npm run nova -- <parancs>
 *
 * A parancsok listája szándékosan rövid: minden fázis csak azt teszi hozzá,
 * amit valóban meg is valósít. Kitalált, "majd lesz" parancsot nem hirdetünk.
 */

import { log, color, NovaError } from './lib/log.ts';
import { doctor } from './commands/doctor.ts';
import { vendorInstall, vendorVerify } from './commands/vendor.ts';

interface Command {
  description: string;
  run: () => Promise<number> | number;
}

const commands: Record<string, Command> = {
  doctor: {
    description: 'Környezet-ellenőrzés: mi hiányzik a fejlesztéshez és az indításhoz',
    run: () => doctor(),
  },
  'vendor:install': {
    description: 'Third-party függőségek telepítése a vendor.json alapján (checksummal)',
    run: async () => {
      await vendorInstall();
      return 0;
    },
  },
  'vendor:verify': {
    description: 'Ellenőrzi, hogy a vendor függőségek és az adatlapjaik a helyükön vannak-e',
    run: () => (vendorVerify() > 0 ? 1 : 0),
  },
};

function usage(): void {
  log.info(color.bold('NOVA RP — fejlesztői eszközök'));
  log.blank();
  log.info('Használat:  npm run nova -- <parancs>');
  log.blank();
  for (const [name, command] of Object.entries(commands)) {
    log.info(`  ${color.cyan(name.padEnd(18))} ${command.description}`);
  }
  log.blank();
}

async function main(): Promise<void> {
  const name = process.argv[2];

  if (!name || name === '--help' || name === '-h') {
    usage();
    process.exitCode = name ? 0 : 1;
    return;
  }

  const command = commands[name];
  if (!command) {
    log.fail(`Ismeretlen parancs: ${name}`);
    log.blank();
    usage();
    process.exitCode = 1;
    return;
  }

  process.exitCode = await command.run();
}

main().catch((error: unknown) => {
  if (error instanceof NovaError) {
    log.blank();
    log.fail(error.message);
    if (error.hint) log.detail(error.hint);
    log.blank();
  } else {
    log.fail('Váratlan hiba:');
    console.error(error);
  }
  process.exitCode = 1;
});
