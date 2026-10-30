// Copies /spec/i18n/invite.json into web/public/core/strings.js for the guest page.
// Run: npm run build (also runs before `npm run dev`). Do not edit strings.js by hand.
import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const source = new URL('../../spec/i18n/invite.json', import.meta.url);
const target = new URL('../public/core/strings.js', import.meta.url);

export function renderStrings(json) {
  return `// Generated from spec/i18n/invite.json by web/scripts/build-strings.mjs. Do not edit.\nexport default ${JSON.stringify(json)};\n`;
}

export function readSource() {
  return JSON.parse(readFileSync(source, 'utf8'));
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  writeFileSync(target, renderStrings(readSource()));
  console.log('wrote public/core/strings.js');
}
