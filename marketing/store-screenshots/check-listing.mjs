// Checks every field of the store listings against App Store Connect's limits
// (marketing/STORE_SUBMISSION.md §3): characters for text fields, UTF-8 bytes for
// the keywords. Run: node marketing/store-screenshots/check-listing.mjs
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const marketing = join(dirname(fileURLToPath(import.meta.url)), '..');

const limits = {
  'App name': { max: 30, min: 2 },
  'Subtitle': { max: 30 },
  'Promotional text': { max: 170 },
  'Description': { max: 4000 },
  'Keywords': { max: 100, bytes: true },
};

let failed = false;
for (const file of ['STORE_LISTING_EN.md', 'STORE_LISTING_DE.md']) {
  const text = readFileSync(join(marketing, file), 'utf8');
  // Each field is a "## <name> — …" heading followed by a ```text block.
  for (const [, heading, body] of text.matchAll(/^## ([^\n—]+?) —[^\n]*\n+```text\n([\s\S]*?)\n```/gm)) {
    const limit = limits[heading.trim()];
    if (!limit) continue;
    const used = limit.bytes ? Buffer.byteLength(body, 'utf8') : [...body].length;
    const ok = used <= limit.max && used >= (limit.min ?? 1);
    if (!ok) failed = true;
    console.log(`${ok ? 'ok  ' : 'FAIL'} ${file} ${heading.trim()}: ${used}/${limit.max}${limit.bytes ? ' bytes' : ''}`);
  }
}
process.exit(failed ? 1 : 0);
