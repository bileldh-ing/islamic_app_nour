#!/usr/bin/env python3
"""Cross-checks Noor's prayer-time engine against the Aladhan API.

For 8 cities x 3 dates it fetches
  https://api.aladhan.com/v1/timings/DD-MM-YYYY?latitude=..&longitude=..&method=N&school=0&latitudeAdjustmentMethod=1
converts the local HH:MM to UTC with the timezone Aladhan reports, runs our Dart engine
(scripts/verify/engine_dump.dart -> lib/services/prayer_calc.dart) on the same inputs and
asserts |diff| <= 2 minutes for every prayer. Writes scripts/verify/aladhan_expected.json
(the fixture embedded in test/prayer_accuracy_test.dart).

Run from the project root:  python3 scripts/verify/verify_prayer_times.py
Exit code 1 on any mismatch.
"""
import json
import math
import os
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

CITIES = [
    # id, lat, lng, our method id, Aladhan method id
    ("tunis", 36.8065, 10.1815, "tunisia", 18),
    ("makkah", 21.4225, 39.8262, "ummAlQura", 4),
    ("cairo", 30.0444, 31.2357, "egyptian", 5),
    ("istanbul", 41.0082, 28.9784, "turkiye", 13),
    ("london", 51.5074, -0.1278, "muslimWorldLeague", 3),
    ("newyork", 40.7128, -74.0060, "northAmerica", 2),
    ("jakarta", -6.2088, 106.8456, "indonesian", 20),
    ("karachi", 24.8607, 67.0011, "karachi", 1),
]
DATES = [(2026, 3, 20), (2026, 6, 21), (2026, 10, 23)]
PRAYERS = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"]
KEYS = {"fajr": "Fajr", "sunrise": "Sunrise", "dhuhr": "Dhuhr", "asr": "Asr", "maghrib": "Maghrib", "isha": "Isha"}
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UA = "NoorIslamicApp-verification/2.0"


def fetch(city, y, m, d):
    _, lat, lng, _, mid = city
    url = (f"https://api.aladhan.com/v1/timings/{d:02d}-{m:02d}-{y}?latitude={lat}&longitude={lng}"
           f"&method={mid}&school=0&latitudeAdjustmentMethod=1")
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=30) as r:
                return url, json.load(r)["data"]
        except Exception:
            time.sleep(2 + attempt * 2)
    raise RuntimeError("fetch failed: " + url)


def _jd(y, m, d):
    if m <= 2:
        y -= 1
        m += 12
    a = y // 100
    return int(365.25 * (y + 4716)) + int(30.6001 * (m + 1)) + d + 2 - a + a // 4 - 1524.5


def _sun(j):
    """NOAA / Meeus solar declination (rad) and equation of time (hours)."""
    t = (j - 2451545) / 36525
    l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360
    mm = math.radians(357.52911 + t * (35999.05029 - 0.0001537 * t))
    e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
    c = math.sin(mm) * (1.914602 - t * (0.004817 + 0.000014 * t)) + math.sin(2 * mm) * (0.019993 - 0.000101 * t) + math.sin(3 * mm) * 0.000289
    om = math.radians(125.04 - 1934.136 * t)
    lam = math.radians(l0 + c - 0.00569 - 0.00478 * math.sin(om))
    eps0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
    eps = math.radians(eps0 + 0.00256 * math.cos(om))
    dec = math.asin(math.sin(eps) * math.sin(lam))
    y = math.tan(eps / 2) ** 2
    l0r = math.radians(l0)
    eqt = 4 * math.degrees(y * math.sin(2 * l0r) - 2 * e * math.sin(mm) + 4 * e * y * math.sin(mm) * math.cos(2 * l0r)
                           - 0.5 * y * y * math.sin(4 * l0r) - 1.25 * e * e * math.sin(2 * mm))
    return dec, eqt / 60


def precise_asr_utc_minutes(y, m, d, lat, lng):
    """Independent reference: bisection on the Sun's true altitude (Meeus/NOAA ephemeris),
    shadow = 1 x height + noon shadow (Shafi'i), noon shadow from the declination at transit."""
    j = _jd(y, m, d)
    p = math.radians(lat)

    def alt(t):
        dec, eqt = _sun(j + t / 24)
        ha = math.radians((t + lng / 15 + eqt - 12) * 15)
        return math.asin(math.sin(p) * math.sin(dec) + math.cos(p) * math.cos(dec) * math.cos(ha))

    t = 12 - lng / 15
    for _ in range(5):
        t = 12 - lng / 15 - _sun(j + t / 24)[1]
    target = math.atan(1 / (1 + math.tan(abs(p - _sun(j + t / 24)[0]))))
    lo, hi = t, t + 9
    for _ in range(60):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if alt(mid) > target else (lo, mid)
    return lo * 60


def fetch_qibla(lat, lng):
    req = urllib.request.Request(f"https://api.aladhan.com/v1/qibla/{lat}/{lng}", headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)["data"]["direction"]


def to_utc_minutes(hhmm, tzname, y, m, d):
    hh, mm = hhmm.split(" ")[0].split(":")
    local = datetime(y, m, d, int(hh), int(mm), tzinfo=ZoneInfo(tzname))
    base = datetime(y, m, d, tzinfo=timezone.utc)
    return int((local.astimezone(timezone.utc) - base).total_seconds() // 60)


def c_method_has_no_asr_adjustment(method):
    # Turkiye (Diyanet) adds +4 min to Asr by convention, so the raw ephemeris check does not apply.
    return method != "turkiye"


def main():
    cases, expected = [], []
    for c in CITIES:
        for (y, m, d) in DATES:
            url, data = fetch(c, y, m, d)
            tzname = data["meta"]["timezone"]
            exp = {p: to_utc_minutes(data["timings"][KEYS[p]], tzname, y, m, d) for p in PRAYERS}
            # Isha after UTC midnight of the previous local date is fine: minutes may exceed 1440.
            if exp["isha"] < exp["maghrib"]:
                exp["isha"] += 1440
            cid = f"{c[0]}-{y}{m:02d}{d:02d}"
            exp_precise_asr = precise_asr_utc_minutes(y, m, d, c[1], c[2])
            expected.append({"id": cid, "city": c[0], "lat": c[1], "lng": c[2], "y": y, "m": m, "d": d,
                             "method": c[3], "aladhanMethod": c[4], "timezone": tzname,
                             "local": {p: data["timings"][KEYS[p]] for p in PRAYERS}, "utcMinutes": exp, "url": url,
                             "preciseAsrUtcMinutes": round(exp_precise_asr, 2)})
            cases.append({"id": cid, "lat": c[1], "lng": c[2], "y": y, "m": m, "d": d, "method": c[3]})
            time.sleep(0.3)

    env = dict(os.environ)
    env["PATH"] = "/workspace/work/sdk/flutter/bin:" + env.get("PATH", "")
    res = subprocess.run(["dart", "run", "scripts/verify/engine_dump.dart"], input=json.dumps(cases) + "\n",
                         capture_output=True, text=True, cwd=ROOT, env=env, timeout=600)
    if res.returncode != 0:
        print(res.stderr)
        sys.exit(2)
    ours = {o["id"]: o for o in json.loads(res.stdout.strip().splitlines()[-1])}

    worst, failures = 0, []
    for e in expected:
        o = ours[e["id"]]
        row = []
        for p in PRAYERS:
            ov = o[p]
            if p == "isha" and ov < o["maghrib"]:
                ov += 1440
            diff = ov - e["utcMinutes"][p]
            worst = max(worst, abs(diff))
            row.append(f"{p}:{diff:+d}")
            if abs(diff) > 2:
                failures.append((e["id"], p, diff))
        pa = o["asr"] - e["preciseAsrUtcMinutes"]
        if abs(pa) > 1.0 and c_method_has_no_asr_adjustment(e["method"]):
            failures.append((e["id"], "asr-vs-ephemeris", round(pa, 2)))
        print(f"{e['id']:<22} {' '.join(row)}   asr vs NOAA ephemeris: {pa:+.2f}")

    qiblas = {}
    for c in CITIES:
        if abs(c[1] - 21.4225) < 0.05 and abs(c[2] - 39.8262) < 0.05:
            continue  # at the Kaaba itself the bearing is undefined
        exp_q = fetch_qibla(c[1], c[2])
        our_q = next(o["qibla"] for k, o in ours.items() if k.startswith(c[0] + "-"))
        qiblas[c[0]] = {"aladhan": exp_q, "ours": our_q}
        print(f"qibla {c[0]:<10} aladhan {exp_q:8.3f}  ours {our_q:8.3f}  diff {our_q - exp_q:+.4f}")
        if abs(our_q - exp_q) > 0.5:
            failures.append((c[0], "qibla", our_q - exp_q))

    with open(os.path.join(ROOT, "scripts/verify/aladhan_expected.json"), "w") as f:
        json.dump({"fetched": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                   "source": "https://api.aladhan.com/v1/timings", "cases": expected, "qibla": qiblas}, f, ensure_ascii=False, indent=1)
    print(f"\n{len(expected)} city-days x 6 times, worst |diff| = {worst} min, failures = {len(failures)}")
    for fl in failures:
        print("FAIL", fl)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
