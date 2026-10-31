#!/usr/bin/env node
// Checks spec/api.md against the backend (T31):
//  - §9 writable-columns table == column grants to `authenticated` in the migrations
//  - every /rpc/<fn> mentioned exists and is executable by `authenticated`
//  - every /functions/v1/<name> mentioned has a folder in backend/supabase/functions
//  - every RPC / Edge Function error code in the backend appears in api.md
// Usage: node tools/check-api.mjs   (exit 1 on any mismatch)
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const api = readFileSync(join(repo, 'spec/api.md'), 'utf8');
const migDir = join(repo, 'backend/supabase/migrations');
const sql = readdirSync(migDir).filter((f) => f.endsWith('.sql')).sort().map((f) => readFileSync(join(migDir, f), 'utf8')).join('\n');
const errors = [];

// ---- column grants to authenticated
const grants = {}; // "table op" -> sorted columns
for (const m of sql.matchAll(/grant\s+([^;]+?)\s+on\s+public\.(\w+)\s+to\s+([^;]+);/gi)) {
  const [, privs, table, roles] = m;
  if (!/\bauthenticated\b/.test(roles)) continue;
  for (const p of privs.matchAll(/(insert|update)\s*\(([^)]*)\)/gi)) {
    grants[`${table} ${p[1].toLowerCase()}`] = p[2].split(',').map((c) => c.trim()).filter(Boolean).sort();
  }
}
const block = /<!-- writable-columns[^>]*-->([\s\S]*?)<!-- \/writable-columns -->/.exec(api);
if (!block) errors.push('api.md: writable-columns block missing');
else {
  const documented = {};
  for (const row of block[1].split('\n')) {
    const cells = row.split('|').map((c) => c.trim());
    if (cells.length < 4 || !/^(insert|update)$/.test(cells[2])) continue;
    documented[`${cells[1]} ${cells[2]}`] = cells[3].split(',').map((c) => c.trim()).sort();
  }
  for (const key of new Set([...Object.keys(grants), ...Object.keys(documented)])) {
    const a = (grants[key] || []).join(',');
    const b = (documented[key] || []).join(',');
    if (a !== b) errors.push(`writable columns differ for "${key}":\n    migrations: ${a || '(none)'}\n    api.md:     ${b || '(none)'}`);
  }
}

// ---- RPCs
const rpcs = new Set([...api.matchAll(/\/rpc\/(\w+)/g)].map((m) => m[1]));
const section3 = api.slice(api.indexOf('## 3.'), api.indexOf('## 4.'));
for (const t of section3.matchAll(/^\| `(\w+)` \|/gm)) rpcs.add(t[1]); // §3 RPC table rows
for (const fn of rpcs) {
  if (['get_preview', 'get_invite', 'submit_rsvp'].includes(fn)) continue;
  if (!new RegExp(`create (or replace )?function public\\.${fn}\\(`).test(sql)) { errors.push(`rpc ${fn}: not defined in migrations`); continue; }
  if (!new RegExp(`grant execute on function public\\.${fn}\\([^)]*\\) to [^;]*\\bauthenticated\\b`).test(sql)) errors.push(`rpc ${fn}: not granted to authenticated`);
}

// ---- Edge Functions
for (const m of api.matchAll(/\/functions\/v1\/([\w-]+)/g)) {
  if (!existsSync(join(repo, 'backend/supabase/functions', m[1], 'index.ts'))) errors.push(`edge function ${m[1]}: folder missing`);
}

// ---- error codes
const codes = new Set();
for (const m of sql.matchAll(/'error', '(\w+)'/g)) codes.add(m[1]);
const verify = readFileSync(join(repo, 'backend/supabase/functions/_shared/verify.ts'), 'utf8');
for (const m of verify.matchAll(/^  (\w+): \d{3},$/gm)) codes.add(m[1]);
const account = readFileSync(join(repo, 'backend/supabase/functions/_shared/account.ts'), 'utf8');
for (const m of account.matchAll(/error: '(\w+)'/g)) codes.add(m[1]);
for (const guestOnly of ['event_past', 'invalid_count']) codes.delete(guestOnly); // guest web RPCs: PRODUCT.md §6
for (const c of codes) if (!api.includes(`\`${c}\``)) errors.push(`error code ${c} not documented`);

if (errors.length) {
  console.error(`api.md: ${errors.length} problem(s)`);
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}
console.log(`api.md OK — ${Object.keys(grants).length} grant lists, ${rpcs.size} RPCs, ${codes.size} error codes checked`);
