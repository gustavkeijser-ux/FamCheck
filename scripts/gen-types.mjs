#!/usr/bin/env node
// Genererar packages/types/src/database.ts från den lokala databasen.
//   pnpm gen:types            skriver filen
//   pnpm check:types-drift    fallerar om filen inte matchar migreringarna (CI)
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';

const TARGET = new URL('../packages/types/src/database.ts', import.meta.url);
const HEADER =
  '// GENERERAD FIL – redigera inte. Kör `pnpm gen:types` efter en ändrad migrering.\n' +
  '// Källa: supabase gen types typescript --local --schema public\n\n';

const generated =
  HEADER +
  execFileSync(
    'pnpm',
    ['exec', 'supabase', 'gen', 'types', 'typescript', '--local', '--schema', 'public'],
    {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'inherit'],
    },
  );

if (process.argv.includes('--check')) {
  const current = readFileSync(TARGET, 'utf8');
  if (current !== generated) {
    console.error(
      'packages/types/src/database.ts är inte i synk med migreringarna. Kör `pnpm gen:types` och checka in.',
    );
    process.exit(1);
  }
  console.warn('Databastyperna är i synk.');
} else {
  writeFileSync(TARGET, generated);
  console.warn('Skrev packages/types/src/database.ts');
}
