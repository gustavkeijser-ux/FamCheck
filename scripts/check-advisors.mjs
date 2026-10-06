#!/usr/bin/env node
// Hämtar Supabase Security Advisor för ett projekt och fallerar på ERROR och WARN.
// Kräver SUPABASE_ACCESS_TOKEN och projektets ref (argument eller SUPABASE_PROJECT_REF).
// Medvetet godkända anmärkningar listas i ALLOWED med motivering.
const ref = process.argv[2] ?? process.env.SUPABASE_PROJECT_REF;
const token = process.env.SUPABASE_ACCESS_TOKEN;
if (!ref || !token) {
  console.error('Kräver projektets ref och SUPABASE_ACCESS_TOKEN');
  process.exit(2);
}

/** name -> motivering. Håll listan tom om möjligt. */
const ALLOWED = {};

const response = await fetch(`https://api.supabase.com/v1/projects/${ref}/advisors/security`, {
  headers: { Authorization: `Bearer ${token}` },
});
if (!response.ok) {
  console.error(`Advisor-anropet misslyckades: HTTP ${response.status}`);
  process.exit(1);
}
const { lints = [] } = await response.json();

const blocking = lints.filter(
  (lint) => ['ERROR', 'WARN'].includes(lint.level) && !(lint.name in ALLOWED),
);
for (const lint of lints) {
  console.warn(`[${lint.level}] ${lint.name}: ${lint.detail ?? lint.title ?? ''}`);
}
if (blocking.length > 0) {
  console.error(`${blocking.length} blockerande anmärkningar från Security Advisor`);
  process.exit(1);
}
console.warn(`Security Advisor: ${lints.length} anmärkningar, inga blockerande`);
