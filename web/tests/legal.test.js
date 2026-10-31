import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const LANGS = ['az', 'ru', 'en', 'tr'];
const read = (doc, lang) => readFileSync(new URL(`../public/legal/${doc}/${lang}.html`, import.meta.url), 'utf8');
const sections = (html) => [...html.matchAll(/<section id="([^"]+)">/g)].map((m) => m[1]);
const count = (html, re) => (html.match(re) ?? []).length;
const placeholders = (html) => [...new Set(html.match(/\{\{[A-Z_]+\}\}/g) ?? [])].sort();

test('terms of use exist in all four languages with the same structure', () => {
  const docs = Object.fromEntries(LANGS.map((l) => [l, read('terms', l)]));
  const base = docs.az;
  for (const lang of LANGS) {
    const html = docs[lang];
    assert.match(html, new RegExp(`<html lang="${lang}">`), `${lang}: html lang`);
    assert.deepEqual(sections(html), sections(base), `${lang}: same sections`);
    assert.equal(count(html, /<li>/g), count(base, /<li>/g), `${lang}: same list items`);
    assert.equal(count(html, /<p>/g), count(base, /<p>/g), `${lang}: same paragraphs`);
    assert.deepEqual(placeholders(html), placeholders(base), `${lang}: same placeholders`);
    assert.match(html, /<meta name="robots" content="noindex">/, `${lang}: noindex while draft`);
    assert.match(html, /data-draft/, `${lang}: visible draft notice`);
    assert.match(html, new RegExp(`<a href="${lang}.html" aria-current="page">`), `${lang}: current language marked`);
    for (const other of LANGS) assert.match(html, new RegExp(`href="${other}.html"`), `${lang}: links to ${other}`);
  }
  assert.equal(sections(base).length, 13);
});

test('legal pages load nothing from outside and only link out by mailto', () => {
  for (const lang of LANGS) {
    const html = read('terms', lang);
    assert.doesNotMatch(html, /<script/i, `${lang}: no scripts`);
    const external = [...html.matchAll(/(?:href|src)="([^"]+)"/g)].map((m) => m[1]).filter((u) => /^[a-z]+:/i.test(u));
    assert.deepEqual(external.filter((u) => !u.startsWith('mailto:')), [], `${lang}: no external resources`);
  }
});

test('placeholders still to fill before publishing are the agreed ones', () => {
  assert.deepEqual(placeholders(read('terms', 'az')), ['{{BRAND_NAME}}', '{{CONTACT_EMAIL}}', '{{EFFECTIVE_DATE}}', '{{LEGAL_ENTITY}}', '{{VOEN}}']);
});
