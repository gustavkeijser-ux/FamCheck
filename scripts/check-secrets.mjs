#!/usr/bin/env node
// Söker efter hemligheter i klientkod och delade paket. Körs i CI.
// Allt i apps/ och packages/ kan hamna i appen och är därmed publikt.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const ROOT = new URL('..', import.meta.url).pathname;
const SCAN_DIRS = ['apps', 'packages'];
const SKIP_DIRS = new Set(['node_modules', '.expo', 'dist', 'ios', 'android']);
const EXTENSIONS = /\.(ts|tsx|js|jsx|mjs|cjs|json)$/;

const RULES = [
  { name: 'Supabase secret key', pattern: /sb_secret_[A-Za-z0-9_-]{10,}/ },
  { name: 'service_role-referens', pattern: /service_role/i },
  { name: 'SUPABASE_SERVICE_ROLE/SECRET-variabel', pattern: /SUPABASE_(SERVICE_ROLE|SECRET)_KEY/ },
  { name: 'JWT', pattern: /eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/ },
  { name: 'Privat nyckel', pattern: /-----BEGIN [A-Z ]*PRIVATE KEY-----/ },
];

// Filer som medvetet nämner mönstren för att SKYDDA mot dem. Undantaget gäller bara angivna regler.
const ALLOWED = {
  'apps/mobile/src/lib/env.ts': ['service_role-referens'],
  'apps/mobile/src/lib/env.test.ts': ['service_role-referens', 'Supabase secret key'],
};

function* walk(dir) {
  for (const entry of readdirSync(dir)) {
    if (SKIP_DIRS.has(entry)) continue;
    const path = join(dir, entry);
    const stats = statSync(path);
    if (stats.isDirectory()) yield* walk(path);
    else if (EXTENSIONS.test(entry)) yield path;
  }
}

const findings = [];
for (const dir of SCAN_DIRS) {
  for (const file of walk(join(ROOT, dir))) {
    const relativePath = relative(ROOT, file);
    const allowed = ALLOWED[relativePath] ?? [];
    const lines = readFileSync(file, 'utf8').split('\n');
    lines.forEach((line, index) => {
      for (const rule of RULES) {
        if (allowed.includes(rule.name)) continue;
        if (rule.pattern.test(line)) {
          findings.push(`${relativePath}:${index + 1}  ${rule.name}`);
        }
      }
    });
  }
}

if (findings.length > 0) {
  console.error('Möjliga hemligheter i klientkod:\n' + findings.map((f) => `  ${f}`).join('\n'));
  process.exit(1);
}
console.warn('check-secrets: inga fynd');
