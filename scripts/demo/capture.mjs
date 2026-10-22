// Captures real screenshots and a walkthrough video of the Noor web build.
// Usage: node capture.mjs <baseUrl> <outDir>
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';

const base = process.argv[2] ?? 'http://localhost:8080/islamic_app_nour/';
const out = process.argv[3] ?? 'media';
fs.mkdirSync(out, { recursive: true });

const W = 412, H = 915;
const args = ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--lang=ar'];
const url = (q) => `${base}?demo${q ? '&' + q : ''}`;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function ready(page, extra = 3500) {
  await page.waitForSelector('flutter-view, flt-glass-pane', { timeout: 60000 });
  await sleep(extra);
}

// v2 RTL nav bar: 5 tabs, tab 0 on the right. Bar spans x 16..396 (6px inner padding), 70px tall, 12px from the bottom.
const tab = (i) => ({ x: 390 - 73.6 * (i + 0.5), y: H - 12 - 35 });

const shots = [
  ['01-home', ''],
  ['02-qibla', 'screen=qibla'],
  ['03-quran', 'screen=quran'],
  ['04-reader-fatiha', 'screen=reader&surah=1'],
  ['05-reader-yasin', 'screen=reader&surah=36'],
  ['06-azkar', 'screen=azkar'],
  ['07-duas', 'screen=duas'],
  ['08-tasbih', 'screen=tasbih'],
  ['09-tracker', 'screen=tracker'],
  ['10-calendar', 'screen=calendar'],
  ['11-names', 'screen=names'],
  ['12-fasting', 'screen=fasting'],
  ['13-shahada', 'screen=shahada'],
  ['14-settings', 'screen=settings'],
  ['15-onboarding', 'screen=onboarding'],
  ['16-prayer', 'screen=prayer'],
  ['17-home-light', 'theme=light'],
  ['18-prayer-light', 'screen=prayer&theme=light'],
  ['19-khatma', 'screen=khatma'],
  ['20-hadith', 'screen=hadith'],
  ['21-more', 'screen=more'],
  ['22-azkar-morning', 'screen=azkar-morning'],
  ['23-timetable', 'screen=timetable'],
  ['24-zakat', 'screen=zakat&theme=light'],
  ['25-quran-light', 'screen=quran&theme=light'],
];

const browser = await chromium.launch({ args });

// ---------- Screenshots ----------
{
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, locale: 'ar', timezoneId: 'Africa/Tunis' });
  const page = await ctx.newPage();
  for (const [name, q] of shots) {
    await page.goto(url(q));
    await ready(page, name === '02-qibla' ? 8000 : name.startsWith('04') || name.startsWith('05') ? 6000 : 4000);
    await page.screenshot({ path: path.join(out, `${name}.png`) });
    console.log('shot', name);
  }
  await ctx.close();
}

// ---------- Walkthrough video ----------
{
  const ctx = await browser.newContext({
    viewport: { width: W, height: H },
    deviceScaleFactor: 2,
    locale: 'ar',
    timezoneId: 'Africa/Tunis',
    recordVideo: { dir: path.join(out, 'raw'), size: { width: W * 2, height: H * 2 } },
  });
  const page = await ctx.newPage();
  await page.mouse.move(W / 2, H / 2);
  const scroll = async (dy, steps = 6, pause = 120) => {
    for (let i = 0; i < steps; i++) { await page.mouse.wheel(0, dy / steps); await sleep(pause); }
  };
  const visit = async (q, hold, act) => {
    await page.goto(url(q));
    await ready(page, 2500);
    if (act) await act();
    await sleep(hold);
  };

  // Home dashboard, then every tab through the liquid nav bar.
  await visit('', 1500, async () => { await scroll(1100, 12, 160); await sleep(800); await scroll(-1100, 6, 100); });
  await page.mouse.click(tab(1).x, tab(1).y); await sleep(2200);              // Prayer
  await page.mouse.move(W / 2, H / 2); await scroll(800, 8, 150); await sleep(600);
  await page.mouse.click(tab(2).x, tab(2).y); await sleep(1800);              // Quran
  await page.mouse.move(W / 2, H / 2); await scroll(1200, 10, 140); await sleep(600);
  await page.mouse.click(tab(3).x, tab(3).y); await sleep(7000);              // Qibla locks on
  await page.mouse.click(tab(4).x, tab(4).y); await sleep(1500);              // More
  await page.mouse.move(W / 2, H / 2); await scroll(900, 8, 140); await sleep(800);

  // Feature screens.
  await visit('screen=reader&surah=1', 1500);
  await visit('screen=reader&surah=36', 800, async () => { await page.mouse.move(W / 2, H / 2); await scroll(1500, 12, 180); });
  await visit('screen=khatma', 1800);
  await visit('screen=azkar', 1200, async () => { await scroll(700, 6, 150); });
  await visit('screen=azkar-morning', 1500);
  await visit('screen=tasbih', 800, async () => {
    for (let i = 0; i < 12; i++) { await page.mouse.click(W / 2, H * 0.52); await sleep(260); }
  });
  await visit('screen=names', 800, async () => { await page.mouse.move(W / 2, H / 2); await scroll(1600, 12, 160); });
  await visit('screen=calendar', 1800);
  await visit('screen=hadith', 1500);
  await visit('screen=tracker', 1800);
  await visit('theme=light', 1500, async () => { await page.mouse.move(W / 2, H / 2); await scroll(900, 8, 150); });
  await visit('screen=prayer&theme=light', 1800);
  await visit('', 2500);

  const v = page.video();
  await ctx.close();
  fs.renameSync(await v.path(), path.join(out, 'demo.webm'));
  fs.rmSync(path.join(out, 'raw'), { recursive: true, force: true });
}

await browser.close();
console.log('done');
