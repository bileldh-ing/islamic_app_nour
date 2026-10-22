#!/usr/bin/env python3
"""Verify assets/data/quran.json against api.alquran.cloud (Tanzil-derived Hafs data).

Checks: 114 surahs, 6236 ayahs, per-surah ayah counts (meta), surah names and
revelation type, page / juz / sajda / global number of EVERY ayah, Uthmani text
of every ayah (ayah 1 of surahs 2-113 stores the text without the leading
basmala, which the reader renders separately), tafsir muyassar of every ayah
(ar.muyassar edition), juz starts (meta + standard
spot checks), page starts (meta), 15 sajda ayahs, and non-empty tafsir.
Exit code 0 = all checks passed.

Usage: python3 scripts/verify/verify_quran.py [--cache DIR]
"""
import json
import os
import sys
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATA = os.path.join(ROOT, 'assets', 'data', 'quran.json')
META_URL = 'https://api.alquran.cloud/v1/meta'
UTH_URL = 'https://api.alquran.cloud/v1/quran/quran-uthmani'
TAFSIR_URL = 'https://api.alquran.cloud/v1/quran/ar.muyassar'
BASMALA = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ'

cache = None
if '--cache' in sys.argv:
    cache = sys.argv[sys.argv.index('--cache') + 1]
    os.makedirs(cache, exist_ok=True)


def fetch(url, name):
    if cache:
        p = os.path.join(cache, name)
        if os.path.exists(p):
            with open(p, encoding='utf-8') as f:
                return json.load(f)
    req = urllib.request.Request(url, headers={'User-Agent': 'noor-verify/1.0'})
    with urllib.request.urlopen(req, timeout=120) as r:
        raw = r.read().decode('utf-8')
    if cache:
        with open(os.path.join(cache, name), 'w', encoding='utf-8') as f:
            f.write(raw)
    return json.loads(raw)


def strip_marks(t):
    return ''.join(c for c in t if not ('\u064b' <= c <= '\u065f' or c == '\u0670'))


errors = []
checks = 0


def check(cond, msg):
    global checks
    checks += 1
    if not cond:
        errors.append(msg)


with open(DATA, encoding='utf-8') as f:
    data = json.load(f)
meta = fetch(META_URL, 'meta.json')['data']
uth = fetch(UTH_URL, 'quran-uthmani.json')['data']['surahs']
muy = fetch(TAFSIR_URL, 'ar-muyassar.json')['data']['surahs']

# --- counts
check(len(data) == 114, f'surah count {len(data)} != 114')
total = sum(len(s['a']) for s in data)
check(total == 6236, f'ayah count {total} != 6236')
check(meta['ayahs']['count'] == 6236, 'meta ayah count mismatch')

ms = meta['surahs']['references']
rev = {'Meccan': 'مكية', 'Medinan': 'مدنية'}
for s, m, u, t in zip(data, ms, uth, muy):
    n = s['n']
    check(n == m['number'], f'surah order at {n}')
    check(len(s['a']) == m['numberOfAyahs'], f'surah {n}: {len(s["a"])} ayahs, standard {m["numberOfAyahs"]}')
    check(s['name'] == m['name'], f'surah {n}: name {s["name"]} != {m["name"]}')
    check(s['en'] == m['englishName'], f'surah {n}: english name {s["en"]} != {m["englishName"]}')
    check(s['type'] == rev[m['revelationType']], f'surah {n}: revelation {s["type"]} != {m["revelationType"]}')
    for i, (a, ua, ta) in enumerate(zip(s['a'], u['ayahs'], t['ayahs']), start=1):
        ref = f'{n}:{i}'
        text, tafsir, page, juz, sajda, glob = a
        usaj = bool(ua['sajda'])
        check(page == ua['page'], f'{ref} page {page} != {ua["page"]}')
        check(juz == ua['juz'], f'{ref} juz {juz} != {ua["juz"]}')
        check(bool(sajda) == usaj, f'{ref} sajda {sajda} != {usaj}')
        check(glob == ua['number'], f'{ref} global {glob} != {ua["number"]}')
        ut = ua['text'].lstrip('\ufeff')
        if i == 1 and n not in (1, 9):
            words = ut.split(' ')
            # The source prefixes the basmala (4 words) to ayah 1; the app stores it without.
            check(strip_marks(' '.join(words[:4])) == strip_marks(BASMALA), f'{ref} unexpected prefix in source')
            ut = ' '.join(words[4:])
        check(text == ut, f'{ref} text differs from quran-uthmani')
        check(isinstance(tafsir, str) and len(tafsir.strip()) > 0, f'{ref} empty tafsir')
        check(tafsir.strip() == ta['text'].lstrip('\ufeff').strip(), f'{ref} tafsir differs from ar.muyassar')

# --- juz starts
first = {}
pages_first = {}
for s in data:
    for i, a in enumerate(s['a'], start=1):
        first.setdefault(a[3], (s['n'], i))
        pages_first.setdefault(a[2], (s['n'], i))
mj = meta['juzs']['references']
check(len(first) == 30 and len(mj) == 30, 'juz count != 30')
for j, r in enumerate(mj, start=1):
    check(first.get(j) == (r['surah'], r['ayah']), f'juz {j} starts {first.get(j)} != {r["surah"]}:{r["ayah"]}')
standard = {1: (1, 1), 2: (2, 142), 3: (2, 253), 4: (3, 93), 5: (4, 24), 6: (4, 148), 7: (5, 82), 8: (6, 111),
            9: (7, 88), 10: (8, 41), 11: (9, 93), 12: (11, 6), 13: (12, 53), 14: (15, 1), 15: (17, 1), 16: (18, 75),
            17: (21, 1), 18: (23, 1), 19: (25, 21), 20: (27, 56), 21: (29, 46), 22: (33, 31), 23: (36, 28),
            24: (39, 32), 25: (41, 47), 26: (46, 1), 27: (51, 31), 28: (58, 1), 29: (67, 1), 30: (78, 1)}
for j, v in standard.items():
    check(first.get(j) == v, f'juz {j} start {first.get(j)} != standard {v}')

# --- pages
mp = meta['pages']['references']
check(len(pages_first) == 604 and len(mp) == 604, f'page count {len(pages_first)} != 604')
for p, r in enumerate(mp, start=1):
    check(pages_first.get(p) == (r['surah'], r['ayah']), f'page {p} starts {pages_first.get(p)} != {r["surah"]}:{r["ayah"]}')

# --- sajdas
sj = [(s['n'], i) for s in data for i, a in enumerate(s['a'], start=1) if a[4]]
msj = [(r['surah'], r['ayah']) for r in meta['sajdas']['references']]
expected_sj = [(7, 206), (13, 15), (16, 50), (17, 109), (19, 58), (22, 18), (22, 77), (25, 60), (27, 26), (32, 15),
               (38, 24), (41, 38), (53, 62), (84, 21), (96, 19)]
check(len(sj) == 15, f'sajda count {len(sj)} != 15')
check(sj == msj, f'sajdas {sj} != meta {msj}')
check(sj == expected_sj, 'sajdas differ from standard list')

print(f'quran.json: {len(data)} surahs, {total} ayahs, {len(first)} juz, {len(pages_first)} pages, {len(sj)} sajdas')
print(f'{checks} checks run against {META_URL}, {UTH_URL} and {TAFSIR_URL}')
if errors:
    print(f'FAILED: {len(errors)} mismatches')
    for e in errors[:50]:
        print('  -', e)
    sys.exit(1)
print('PASS: all checks passed')
