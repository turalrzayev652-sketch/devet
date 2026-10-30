// Pure helpers (no DOM) so they can be unit-tested in Node.
import { t } from './i18n.js';

// Event times are shown in venue time; events have no time zone field yet (templates.md §8).
export const TIME_ZONE = 'Asia/Baku';

// Month/weekday names come from invite.json, not Intl: reduced ICU builds (e.g. Android Chrome)
// report "az" as supported but format it as "2027 M07 10". Intl is used only for the time zone math,
// through en-US which every build ships.
const PARTS = new Intl.DateTimeFormat('en-US', {
  timeZone: TIME_ZONE, year: 'numeric', month: 'numeric', day: 'numeric',
  hour: '2-digit', minute: '2-digit', hourCycle: 'h23', weekday: 'short',
});
const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export function venueParts(iso) {
  const p = Object.fromEntries(PARTS.formatToParts(new Date(iso)).map((x) => [x.type, x.value]));
  return {
    year: Number(p.year), month: Number(p.month), day: Number(p.day),
    hour: p.hour, minute: p.minute, weekday: WEEKDAYS.indexOf(p.weekday),
  };
}

export function formatDate(iso, lang) {
  const p = venueParts(iso);
  return t('date.long', lang, { day: p.day, month: t(`date.month.${p.month}`, lang), year: p.year });
}
export const formatWeekday = (iso, lang) => t(`date.weekday.${venueParts(iso).weekday}`, lang);
export function formatTime(iso) {
  const p = venueParts(iso);
  return `${p.hour}:${p.minute}`;
}

// Whole days/hours/minutes until start, or null once the event has started.
export function countdownParts(startsAtIso, now = Date.now()) {
  const ms = new Date(startsAtIso).getTime() - now;
  if (!(ms > 0)) return null;
  const totalMinutes = Math.floor(ms / 60000);
  return {
    days: Math.floor(totalMinutes / 1440),
    hours: Math.floor((totalMinutes % 1440) / 60),
    minutes: totalMinutes % 60,
  };
}

// Only http(s) URLs may reach href/src (maps_url and media come from family input / storage).
export function safeUrl(value) {
  if (typeof value !== 'string' || !value.trim()) return null;
  try {
    const url = new URL(value.trim());
    return url.protocol === 'https:' || url.protocol === 'http:' ? url.href : null;
  } catch {
    return null;
  }
}

const isCoord = (v, max) => typeof v === 'number' && Number.isFinite(v) && Math.abs(v) <= max;

export function mapLinks(event) {
  const hasCoords = isCoord(event.lat, 90) && isCoord(event.lng, 180);
  const google = safeUrl(event.maps_url)
    ?? (hasCoords ? `https://www.google.com/maps/search/?api=1&query=${event.lat},${event.lng}` : null);
  const waze = hasCoords ? `https://waze.com/ul?ll=${event.lat},${event.lng}&navigate=yes` : null;
  return { google, waze };
}

export const isColor = (v) => typeof v === 'string' && /^#[0-9a-fA-F]{6}$/.test(v);
