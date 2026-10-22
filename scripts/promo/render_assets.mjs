// Renders promo stills (background, phone frame, screen mask, captions, title cards) with Chromium.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const out = path.resolve(here, '../../build/promo/assets');
fs.mkdirSync(out, { recursive: true });
const caps = JSON.parse(fs.readFileSync(path.join(here, 'captions.json'), 'utf8'));
const page_ = 'file://' + path.join(here, 'assets.html');

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
async function shot(query, file, sel, transparent = true) {
  await page.goto(`${page_}?${query}`);
  await page.waitForSelector('body[data-ready="1"]');
  await page.waitForTimeout(150);
  await page.locator(sel).screenshot({ path: path.join(out, file), omitBackground: transparent });
  console.log('asset', file);
}
await shot('w=bg', 'bg.png', '#bg', false);
await shot('w=bg-light', 'bg-light.png', '#bg', false);
await shot('w=frame', 'frame.png', '#frame');
await shot('w=mask', 'mask.png', '#mask', false);
for (const [id, c] of Object.entries(caps)) {
  const q = new URLSearchParams(c);
  if (id.startsWith('title')) {
    q.set('w', 'title');
    await shot(q.toString(), `${id}.png`, '#title');
  } else {
    q.set('w', 'cap');
    await shot(q.toString(), `${id}.png`, '#cap');
  }
}
await browser.close();
