#!/usr/bin/env node
// Kontrollerar en BYGGD appbundle (expo export) efter hemligheter.
// Användning: node scripts/check-bundle.mjs <exportkatalog>
// Miljövariabler med kända hemliga värden (t.ex. SUPABASE_SECRET_KEY) söks också efter.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const dir = process.argv[2];
if (!dir) {
  console.error('Ange katalogen från expo export');
  process.exit(2);
}

const patterns = [
  { name: 'Supabase secret key', test: (text) => /sb_secret_[A-Za-z0-9_-]{10,}/.test(text) },
  {
    name: 'service_role-JWT',
    test: (text) => /"role"\s*:\s*"service_role"/.test(text) || text.includes('c2VydmljZV9yb2xl'),
  },
  { name: 'Privat nyckel', test: (text) => /-----BEGIN [A-Z ]*PRIVATE KEY-----/.test(text) },
  {
    name: 'Testmiljöns admin-hjälpare',
    test: (text) => text.includes('obtainOtp') || text.includes('deleteTestUsers'),
  },
];
for (const name of ['SUPABASE_SECRET_KEY', 'SUPABASE_DB_PASSWORD', 'SUPABASE_ACCESS_TOKEN']) {
  const value = process.env[name];
  if (value && value.length >= 8)
    patterns.push({ name: `värdet av ${name}`, test: (text) => text.includes(value) });
}

function* walk(path) {
  for (const entry of readdirSync(path)) {
    const full = join(path, entry);
    if (statSync(full).isDirectory()) yield* walk(full);
    else yield full;
  }
}

let files = 0;
const findings = [];
for (const file of walk(dir)) {
  if (!/\.(js|hbc|json|map)$/.test(file)) continue;
  files += 1;
  const text = readFileSync(file).toString('latin1');
  for (const pattern of patterns) if (pattern.test(text)) findings.push(`${file}: ${pattern.name}`);
}

if (files === 0) {
  console.error('Inga bundlefiler hittades – kontrollen kan inte bekräfta något.');
  process.exit(1);
}
if (findings.length > 0) {
  console.error('Hemligheter i appbundeln:\n' + findings.map((f) => `  ${f}`).join('\n'));
  process.exit(1);
}
console.warn(`check-bundle: ${files} filer kontrollerade, inga hemligheter`);
