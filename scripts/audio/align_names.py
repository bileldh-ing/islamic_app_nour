"""Builds assets/data/names_timings.json from Whisper (faster-whisper "medium",
word timestamps) output for assets/audio/asma_husna.mp3.

The recitation follows the Tirmidhi (3507) order exactly, so each name is
matched in sequence to the next recognised word with a fuzzy (skeleton) match.
Run: python scripts/audio/align_names.py
"""
import difflib, json, re, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
words = json.load(open(ROOT / 'scripts/audio/asma_husna_words_whisper_medium.json'))
names = json.load(open(ROOT / 'assets/data/names.json'))

def skel(s):
    s = re.sub(r'[\u064B-\u0652\u0670\u0640]', '', s)          # harakat, tatweel
    s = re.sub('[أإآٱ]', 'ا', s).replace('ة', 'ه').replace('ى', 'ي').replace('ؤ', 'و').replace('ئ', 'ي').replace('ء', '')
    s = re.sub(r'^[وف]?ال', '', s)
    return s

LEAD = 0.12          # start the highlight a hair before the onset
OPENING_END = 22.9   # "...نسألك يا من هو" then name 1 (الله) at ~23.0 s
KEY = {84: 'مالك', 85: 'الجلال'}
# Global monotonic alignment (Needleman-Wunsch style): every name maps to one
# recognised word, in order; extra words (the opening/closing text, "الملك",
# "والإكرام") are skipped. Maximises total skeleton similarity, so a single
# mis-heard word can never shift the names after it.
k0 = next(k for k, w in enumerate(words) if w[0] >= OPENING_END - 0.2)
W = words[k0:]
T = [skel(KEY.get(n['n'], n['ar'])) for n in names]
sim = [[difflib.SequenceMatcher(None, t, skel(w[2])).ratio() for w in W] for t in T]
NEG = -1e9
J, K = len(T), len(W)
dp = [[NEG] * (K + 1) for _ in range(J + 1)]
bt = [[0] * (K + 1) for _ in range(J + 1)]
for k in range(K + 1):
    dp[0][k] = 0
for j in range(1, J + 1):
    for k in range(1, K + 1):
        skip = dp[j][k - 1]                     # word k unused
        take = dp[j - 1][k - 1] + sim[j - 1][k - 1]
        dp[j][k], bt[j][k] = (take, 1) if take >= skip else (skip, 0)
match, j, k = [0] * J, J, K
while j > 0:
    if bt[j][k] == 1:
        match[j - 1] = k - 1; j -= 1
    k -= 1

starts, used = [], []
for n, m in zip(names, match):
    t = W[m][0]
    if n['n'] == 85:            # "ذو" is fused into the next token: start where "الملك" ends
        t = W[m - 1][1]
    starts.append(round(max(0, t - LEAD), 2))
    used.append((n['n'], n['ar'], W[m][2], round(t, 2), round(sim[n['n'] - 1][m], 2)))
i = k0 + match[-1] + 1

closing = next(w[0] for w in words[i:] if skel(w[2]).startswith('جل'))
assert all(b > a for a, b in zip(starts, starts[1:])), 'non-monotonic timings'
out = {
    'audio': 'assets/audio/asma_husna.mp3',
    'title': 'أسماء الله الحسنى',
    'reciter': 'لطفي بوشناق',
    'source': 'https://youtu.be/cM8FGjYc1Io',
    'method': 'faster-whisper medium word timestamps, global monotonic alignment to names.json (scripts/audio/align_names.py)',
    'starts': starts,
    'closing_start': round(closing - LEAD, 2),
}
json.dump(out, open(ROOT / 'assets/data/names_timings.json', 'w'), ensure_ascii=False, indent=1)
for u in used:
    print(*u)
print('closing', closing)
