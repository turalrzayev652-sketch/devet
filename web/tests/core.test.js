import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { t, plural, displayName, greeting, resolveLang } from '../public/core/i18n.js';
import { countdownParts, safeUrl, mapLinks, formatTime, isColor } from '../public/core/format.js';
import { renderStrings, readSource } from '../scripts/build-strings.mjs';

test('public/core/strings.js is in sync with spec/i18n/invite.json (run npm run build)', () => {
  const generated = readFileSync(new URL('../public/core/strings.js', import.meta.url), 'utf8');
  assert.equal(generated, renderStrings(readSource()));
});

test('displayName matches server display_name_forms for seed guests', () => {
  // Expected values are the same as get_preview in backend/supabase/tests/guest_rpc.test.sql.
  assert.equal(displayName({ name: 'Elçin', salutation: 'muellim', with_family: true }, 'az'), 'Elçin müəllim və ailəsi');
  assert.equal(displayName({ name: 'Rəşad', salutation: 'bey', with_family: true }, 'ru'), 'Rəşad бей с семьёй');
  assert.equal(displayName({ name: 'Aytən', salutation: 'none', with_family: false }, 'en'), 'Aytən');
  assert.equal(displayName({ name: 'Səbinə', salutation: 'xanim', with_family: true }, 'tr'), 'Səbinə Hanım ve ailesi');
  assert.equal(displayName({ name: ' Vüqar ', salutation: 'muellim', with_family: false }, 'az'), 'Vüqar müəllim');
  assert.equal(displayName({ name: 'X', salutation: 'weird', with_family: false }, 'az'), 'X');
});

test('greeting picks the form by salutation / family', () => {
  assert.equal(greeting({ name: 'Leyla', salutation: 'xanim', with_family: false }, 'ru'), 'Уважаемая Leyla ханум!');
  assert.equal(greeting({ name: 'Elçin', salutation: 'muellim', with_family: true }, 'ru'), 'Уважаемые Elçin муаллим с семьёй!');
  assert.equal(greeting({ name: 'Aytən', salutation: 'none', with_family: false }, 'en'), 'Dear Aytən,');
});

test('t fills placeholders and never returns undefined', () => {
  assert.equal(t('table.number', 'az', { table_no: '12' }), 'Masa № 12');
  assert.equal(t('rsvp.count_hint', 'tr', { max: 4 }), 'En fazla 4 kişi');
  assert.equal(t('no.such.key', 'az'), '');
  assert.equal(t('table.number', 'az'), 'Masa № ');
});

test('plural uses Intl.PluralRules categories', () => {
  assert.equal(plural('countdown.days', 1, 'ru'), 'день');
  assert.equal(plural('countdown.days', 3, 'ru'), 'дня');
  assert.equal(plural('countdown.days', 5, 'ru'), 'дней');
  assert.equal(plural('countdown.days', 21, 'ru'), 'день');
  assert.equal(plural('countdown.hours', 1, 'en'), 'hour');
  assert.equal(plural('countdown.hours', 2, 'en'), 'hours');
  assert.equal(plural('countdown.minutes', 5, 'az'), 'dəqiqə');
});

test('resolveLang falls back to az', () => {
  assert.equal(resolveLang('ru'), 'ru');
  assert.equal(resolveLang(null, 'tr'), 'tr');
  assert.equal(resolveLang('de'), 'az');
});

test('countdownParts', () => {
  const now = Date.parse('2027-07-01T10:00:00Z');
  assert.deepEqual(countdownParts('2027-07-02T12:30:00Z', now), { days: 1, hours: 2, minutes: 30 });
  assert.equal(countdownParts('2027-07-01T10:00:00Z', now), null);
  assert.equal(countdownParts('2027-06-01T10:00:00Z', now), null);
  assert.equal(countdownParts('not a date', now), null);
});

test('safeUrl allows only http(s)', () => {
  assert.equal(safeUrl('https://maps.google.com/?q=1'), 'https://maps.google.com/?q=1');
  assert.equal(safeUrl('javascript:alert(1)'), null);
  assert.equal(safeUrl('data:text/html,hi'), null);
  assert.equal(safeUrl(''), null);
  assert.equal(safeUrl(null), null);
});

test('mapLinks: maps_url, coordinates, unsafe url', () => {
  assert.deepEqual(mapLinks({ maps_url: 'https://maps.app/x', lat: 40.4, lng: 49.8 }),
    { google: 'https://maps.app/x', waze: 'https://waze.com/ul?ll=40.4,49.8&navigate=yes' });
  assert.deepEqual(mapLinks({ maps_url: null, lat: 40.4, lng: 49.8 }).google, 'https://www.google.com/maps/search/?api=1&query=40.4,49.8');
  assert.deepEqual(mapLinks({ maps_url: 'javascript:x', lat: null, lng: null }), { google: null, waze: null });
});

test('event time is shown in Asia/Baku', () => {
  assert.equal(formatTime('2027-07-10T18:00:00+04:00', 'az'), '18:00');
  assert.equal(formatTime('2027-07-10T14:00:00Z', 'en'), '18:00');
});

test('isColor', () => {
  assert.ok(isColor('#a0522d'));
  assert.ok(!isColor('red'));
  assert.ok(!isColor('#fff'));
});

test('fixture template.json follows the template contract basics', () => {
  const meta = JSON.parse(readFileSync(new URL('./fixtures/template/template.json', import.meta.url), 'utf8'));
  const html = readFileSync(new URL('./fixtures/template/index.html', import.meta.url), 'utf8');
  for (const block of meta.blocks) assert.match(html, new RegExp(`data-block="${block}"`), block);
});

test('dates use invite.json names, not Intl locale data', async () => {
  const { formatDate, formatWeekday } = await import('../public/core/format.js');
  const iso = '2027-07-10T18:00:00+04:00';
  assert.equal(formatDate(iso, 'az'), '10 iyul 2027');
  assert.equal(formatDate(iso, 'ru'), '10 июля 2027 г.');
  assert.equal(formatDate(iso, 'en'), 'July 10, 2027');
  assert.equal(formatDate(iso, 'tr'), '10 Temmuz 2027');
  assert.equal(formatWeekday(iso, 'az'), 'şənbə');
  assert.equal(formatWeekday(iso, 'tr'), 'Cumartesi');
  // 23:30 UTC on 31 Dec is already 1 Jan in Baku (UTC+4).
  assert.equal(formatDate('2026-12-31T23:30:00Z', 'en'), 'January 1, 2027');
  assert.equal(formatWeekday('2026-12-31T23:30:00Z', 'en'), 'Friday');
});
