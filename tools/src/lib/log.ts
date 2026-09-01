/**
 * Konzol-kimenet a NOVA eszközökhöz.
 *
 * Színezés csak akkor, ha a kimenet terminál ÉS nincs NO_COLOR beállítva —
 * CI-logban a szökési szekvenciák csak zajt csinálnak.
 */

const useColor = process.stdout.isTTY === true && !process.env['NO_COLOR'];

const paint = (code: string, text: string): string =>
  useColor ? `\x1b[${code}m${text}\x1b[0m` : text;

export const color = {
  dim: (text: string) => paint('2', text),
  bold: (text: string) => paint('1', text),
  red: (text: string) => paint('31', text),
  green: (text: string) => paint('32', text),
  yellow: (text: string) => paint('33', text),
  cyan: (text: string) => paint('36', text),
};

export const log = {
  info: (message: string) => console.log(message),
  step: (message: string) => console.log(`${color.cyan('›')} ${message}`),
  ok: (message: string) => console.log(`${color.green('✔')} ${message}`),
  warn: (message: string) => console.log(`${color.yellow('▲')} ${message}`),
  fail: (message: string) => console.log(`${color.red('✖')} ${message}`),
  detail: (message: string) => console.log(`  ${color.dim(message)}`),
  blank: () => console.log(''),
};

/** Nem elkapott hibánál is olvasható maradjon a kimenet. */
export class NovaError extends Error {
  readonly hint: string | undefined;

  constructor(message: string, hint?: string) {
    super(message);
    this.name = 'NovaError';
    this.hint = hint;
  }
}
