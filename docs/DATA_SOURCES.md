# Noor — data sources

Every religious dataset shipped in the app, where it comes from and how it is verified.

## Quran (`assets/data/quran.json`) — Quran suite

- **Text**: Uthmani script, Hafs ʿan ʿĀṣim, from the `quran-uthmani` edition of Al Quran Cloud (Tanzil-derived): https://api.alquran.cloud/v1/quran/quran-uthmani. Ayah 1 of surahs 2–8 and 10–114 is stored without the leading basmala (the source prefixes it); the reader renders the basmala separately. Al-Fatiha 1:1 is the basmala itself; At-Tawba has none.
- **Tafsir**: التفسير الميسر (King Fahd Complex), edition `ar.muyassar`: https://api.alquran.cloud/v1/quran/ar.muyassar.
- **Structure** (page in the 604-page Madani mushaf, juz, sajda, global ayah number, surah names, revelation type): https://api.alquran.cloud/v1/meta and the `quran-uthmani` edition.
- **Format**: list of 114 `{n, name, en, type, a: [[text, tafsir, page, juz, sajda(0/1), globalNumber], ...]}`.
- **Verification**: `python3 scripts/verify/verify_quran.py` (optionally `--cache /tmp/qv`). It downloads the three sources above and asserts: 114 surahs; 6236 ayahs; every surah's ayah count = standard Hafs count; Arabic name, English transliteration and Meccan/Medinan of every surah; page, juz, sajda flag and global number of **every** ayah; Uthmani text of every ayah; tafsir of every ayah; 30 juz starts equal the meta and the standard list (2:142, 2:253, 3:93, … 67:1, 78:1); 604 page starts; exactly 15 sajdas at 7:206, 13:15, 16:50, 17:109, 19:58, 22:18, 22:77, 25:60, 27:26, 32:15, 38:24, 41:38, 53:62, 84:21, 96:19.
  Last run 2026-10-23: `45006 checks … PASS: all checks passed` (no data fix needed).

## Quran — online resources (not bundled)

- **Translations** (cached per surah after first load, cache only if the ayah count matches): `en.sahih` (Saheeh International) and `fr.hamidullah` (Muhammad Hamidullah) via `https://api.alquran.cloud/v1/surah/<n>/<edition>`.
- **Recitation audio**, verse by verse. Primary: Islamic Network CDN `https://cdn.islamic.network/quran/audio/<bitrate>/<reciter>/<globalAyah>.mp3`; fallback: EveryAyah `https://everyayah.com/data/<folder>/<SSSAAA>.mp3`. Each reciter's bitrate was chosen because it returns HTTP 200 (ayahs 1, 3000, 6236 checked 2026-10-23; v1 used 128 kbps for all, which returns 403 for three of them):

  | id | reciter | CDN bitrate | EveryAyah folder |
  |---|---|---|---|
  | ar.alafasy | مشاري راشد العفاسي | 128 | Alafasy_128kbps |
  | ar.abdulsamad | عبد الباسط عبد الصمد | 64 | Abdul_Basit_Murattal_192kbps |
  | ar.husary | محمود خليل الحصري | 128 | Husary_128kbps |
  | ar.abdurrahmaansudais | عبد الرحمن السديس | 192 | Abdurrahmaan_As-Sudais_192kbps |
  | ar.mahermuaiqly | ماهر المعيقلي | 128 | MaherAlMuaiqly128kbps |
  | ar.saoodshuraym | سعود الشريم | 64 | Saood_ash-Shuraym_128kbps |

## Prayer times, Qibla & magnetic declination — Prayer suite

- **Engine**: `adhan_dart` 2.0.1 (port of the Adhan library, Meeus *Astronomical Algorithms*), wrapped by `lib/services/prayer_calc.dart` (pure Dart, no Flutter imports). Asr is recomputed in `PrayerCalc._asr` with the Sun's declination taken at the Asr instant (iterated) and the noon shadow at solar noon: adhan_dart evaluates both at 0h UT, which drifted up to 3 min (London, equinoxes). After the fix our Asr is within 0.5 min of an independent NOAA/Meeus ephemeris bisection for every non-Diyanet case.
- **Methods** (angles as published by https://api.aladhan.com/v1/methods): Tunisia 18°/18° (Aladhan id 18), Algeria 18°/17° (19), Morocco 19°/17° (21), Umm al-Qura 18.5° / Isha +90 min (4), Egypt 19.5°/17.5° (5), MWL 18°/17° (3), Karachi 18°/18° (1), ISNA 15°/15° (2), Dubai 18.2°/18.2° (16), Qatar 18° / +90 min (10), Kuwait 18°/17.5° (9), Gulf 19.5° / +90 min (8), Jordan 18°/18° (23), Turkey Diyanet 18°/17° (13), Tehran 17.7°/14° (7), Singapore 20°/18° (11), Indonesia KEMENAG 20°/18° (20), France UOIF 12°/12° (12), Russia 16°/15° (14), Portugal 18° / +77 min (22), Moonsighting Committee (15). adhan_dart adds +1 min to Dhuhr for MWL/ISNA/Egypt/Karachi/Indonesia/Singapore (a safety margin after zawal; Aladhan does not), and Diyanet's own offsets (sunrise −7, Dhuhr +5, Asr +4, Maghrib +7).
- **Auto method by country** (`PrayerCalc.defaultMethodFor`, used while the user has not picked one): TN→Tunisia, DZ→Algeria, MA→Morocco, SA/YE→Umm al-Qura, EG/SD/LY/SY/LB→Egypt, JO/PS→Jordan, PK/IN/BD/AF→Karachi, US/CA/MX→ISNA, AE→Dubai, QA→Qatar, KW→Kuwait, BH/OM→Gulf, TR→Diyanet, IR→Tehran, SG/MY/BN→Singapore, ID→KEMENAG, FR→UOIF, RU→Russia, PT→Portugal, else MWL.
- **Sunnah times**: middle of the night and last third = Maghrib→next Fajr (adhan `SunnahTimes`); Imsak = Fajr − 10 min and Duha start = sunrise + 15 min (common timetable conventions, labelled as such in the UI).
- **Verification**: `python3 scripts/verify/verify_prayer_times.py` fetches Aladhan `https://api.aladhan.com/v1/timings/DD-MM-YYYY?latitude=..&longitude=..&method=N&school=0&latitudeAdjustmentMethod=1` for Tunis, Makkah, Cairo, Istanbul, London, New York, Jakarta and Karachi on 2026-03-20, 2026-06-21 (summer solstice; London Isha falls on the middle-of-night rule) and 2026-10-23, runs our engine (`scripts/verify/engine_dump.dart`) and asserts |diff| ≤ 2 min for all 6 times, plus Qibla vs `https://api.aladhan.com/v1/qibla/LAT/LNG` (±0.5°). Last run 2026-10-23: 24 city-days × 6 times, worst |diff| = 2 min (Asr, London; our value matches the ephemeris, Aladhan's PrayTimes Asr is the one off), 0 failures; Qibla diffs < 0.001°. Output: `scripts/verify/last_run.txt`; fixture: `scripts/verify/aladhan_expected.json`, embedded in `test/prayer_accuracy_test.dart`.
- **Tunisia**: our `tunisia` method equals Aladhan method 18 to the minute on all three dates (Fajr/Isha 18°). It was not compared with an official timetable of the Tunisian Ministry of Religious Affairs (no machine-readable source found); users can align with their mosque via the per-prayer minute adjustments.
- **Qibla**: initial great-circle bearing to the Kaaba (21.4225241, 39.8261818) from adhan_dart `Qibla`; distance by haversine (mean Earth radius 6371.0088 km).
- **Magnetic declination**: World Magnetic Model 2025 (NOAA NCEI / BGS), degree 12, coefficients copied verbatim from `WMM2025.COF` (https://www.ncei.noaa.gov/sites/default/files/2024-12/WMM2025COF.zip), valid 2025.0–2030.0, implemented in `lib/services/geomag.dart`. `dart run scripts/verify/wmm_check.dart` checks all 100 official points of `WMM2025_TestValues.txt`: max declination error 0.005° (rounding of the test file). Applied on Android only — flutter_compass already returns `CLHeading.trueHeading` on iOS.
- **Maps & places**: tiles Esri Canvas World Dark/Light Gray Base (attribution "Tiles © Esri"); city search and reverse geocoding OSM Nominatim (https://nominatim.openstreetmap.org, identifying User-Agent on mobile); mosques OSM Overpass (`amenity=place_of_worship` + `religion=muslim`, 5 km, https://overpass-api.de with https://overpass.kumi.systems as fallback). Data © OpenStreetMap contributors, credited in the UI.

## Worship & Tools suite

Build scripts (reproducible, kept outside the app): `work/data/build_library.py` (azkar + duas), `work/data/qduas.py` (Quranic duas), `work/data/hadith_build.py` + `parse.py` (Nawawi), `work/data/names_build.py` (99 Names) in the project workspace.

### Azkar library (`assets/data/azkar.json`, 29 categories, 232 items) and Hisn al-Muslim duas (`assets/data/duas.json`, 84 categories, 177 items)
- **Primary text, repeat counts and takhrij**: «حصن المسلم» by Saʿīd ibn ʿAlī ibn Wahf al-Qaḥṭānī, full transcription with the book's own footnote references (e.g. «البخاري مع الفتح 11/ 113 ومسلم 4/ 2083»): https://raw.githubusercontent.com/asellam/HisnElMuslim/main/hisn.json (133 chapters, 302 entries, every entry has a reference). All 133 chapters are included (azkar or duas).
- **Second source (verification)**: official Hisn al-Muslim API https://www.hisnmuslim.com/api/ar/husn_ar.json and `/api/ar/<id>.json` (132 chapters, 267 entries). Every entry of the primary source was matched word-by-word (diacritics/hamza normalised) against the second source: 359 checked, 351 ≥ 0.85 similarity. The 8 below 0.85 were reviewed by hand: 5 are evening wordings (the official API stores only the morning wording plus a bracket note «وإذا أمسى قال: أمسينا…»; the evening texts were further matched ≥ 0.90 against a third copy, the previous `azkar.json`), the rest are instruction-wording differences only (يتفل/اتفل، بعدما/بعد ما، «يقرأ الم تنزيل السجدة وتبارك»).
- **Quranic passages** in «آيات الحفظ والرقية» (al-Fatiha 1–7, Ayat al-Kursi 2:255, al-Baqarah 2:285–286, al-Ikhlas, al-Falaq, an-Nas): taken verbatim from the app's verified `quran.json`; the virtue notes for Ayat al-Kursi and the last two ayahs of al-Baqarah are Hisn al-Muslim's own references.
- **Added items with direct hadith sources** (checked against https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/): Laylat al-Qadr dua «اللَّهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ الْعَفْوَ فَاعْفُ عَنِّي» — Ibn Mājah 3850 wording, also Tirmidhī 3513; Friday: salawat with Abū Dāwūd 1047 (أكثروا عليّ من الصلاة فيه), the hour of response Bukhārī 935; Friday also includes Hisn chapters «الصلاة على النبي بعد التشهد» and «ما يعصم الله به من الدجال» (first ten ayahs of al-Kahf).
- Removed from the v1 file: a stray `"stop"` placeholder entry, corrupted Quranic-dua strings (embedded `\n', '` fragments) and **wrong references in «أدعية الأنبياء»** (references were shifted by one row, e.g. Ibrāhīm's dua labelled Hūd 47).

### Quranic duas & prophets' duas (in `duas.json`, groups `quran` 27 / `prophets` 14)
- Text extracted programmatically from the app's `quran.json` by surah/ayah range (exact Uthmani wording, trimmed to the dua words, verse numbers inserted as ﴿n﴾). Each reference was re-derived, e.g. Ādam 7:23, Nūḥ 71:28, Ibrāhīm & Ismāʿīl 2:127–128, Hūd 11:56, Lūṭ 29:30, Yūsuf 12:101, Shuʿayb 7:89, Mūsā 28:16, Ayyūb 21:83, Sulaymān 27:19, Yūnus 21:87, Zakariyyā 3:38, Yaʿqūb 12:86.

### An-Nawawi's Forty Hadith (`assets/data/hadith_nawawi.json`, 42 hadith)
- **Source**: https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-nawawi.json (42 hadith = the 40 + 2 that an-Nawawi himself included; the 8 additions of Ibn Rajab are not part of this work). Narrator, text and takhrij were split programmatically; `<br>`, bidi marks and an editorial bracket insertion in #14 (absent from the other two copies) removed.
- **Verification**: numbering 1..42 contiguous, no empty field. Word-level comparison with two other copies: sunnah.com scrape https://raw.githubusercontent.com/AhmedBaset/hadith-json/main/db/by_book/forties/nawawi40.json (all ≥ 0.84) and an independent copy https://raw.githubusercontent.com/osamayy/40-hadith-nawawi-db/main/40-hadith-nawawi.json (≥ 0.69; the differences are honorifics «صلى الله عليه وسلم» and footnote numbers only). Spot checks of #1, #16 and #32 by hand: identical matn in all three.
- **Titles** are short topic labels taken from each hadith's own wording (editorial, not part of the text).

### 99 Names (`assets/data/names.json`)
- **Fixed**: the v1 list started at «الرحمن» and inserted «الأحد», which is not in the Tirmidhi narration. It now follows the Tirmidhi narration (no. 3507) exactly: «الله» + the 98 names listed after «هو الله الذي لا إله إلا هو» (ends «الصبور»), no duplicates. Source: https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-tirmidhi/3507.json, cross-checked against https://sunnah.com/tirmidhi:3507 (identical list).
- Arabic meanings are concise editorial summaries in line with standard explanations of the Names; transliteration/English kept from v1.

### Hijri calendar
- `HijriService` uses the `hijri` package (Umm al-Qura tables). 11 dates checked against https://api.aladhan.com/v1/gToH/DD-MM-YYYY?calendarMethod=UAQ on 2026-10-22, all identical (including both directions) — recorded in `test/hijri_accuracy_test.dart`.
- Events: 1 Muharram, 9–10 Muharram, 12 Rabiʿ al-Awwal (commemoration, «على المشهور»), 27 Rajab (commemoration, «على المشهور»), 15 Shaʿban, 1 Ramadan, 21 Ramadan (start of the last ten), 1 Shawwal, 1, 8, 9, 10, 11–13 Dhu al-Hijjah. The v1 «ليلة القدر 27» entry was removed (the night is not fixed; the last ten nights are marked instead).

### Fasting / guides / zakat texts
- Hadith quoted on the fasting screen verified via the hadith API: Abū Dāwūd 2357 (iftar dua), Tirmidhī 745 (Monday/Thursday), Muslim (Arafah/Ashura virtue wording).
- Wudu/Salah and Hajj/Umrah guides: concise mainstream (jumhur) description following the hadiths of ʿUthmān (wudu), Abū Ḥumayd/ʿĀʾisha (salah) and Jābir in Muslim (Hajj); dhikr wording identical to the Hisn al-Muslim entries.
- Zakat: nisab 85 g gold / 595 g silver, rate 2.5% (1/40), user-entered price per gram (default currency TND).

## 99 Names recitation (audio)

- `assets/audio/asma_husna.mp3` — «أسماء الله الحسنى», performed by Lotfi Bouchnak (لطفي بوشناق), from https://youtu.be/cM8FGjYc1Io, supplied by the project owner. Original speed and pitch; the app locks playback to 1.0×. Cover art and metadata stripped (stream copy, no re-encode). Copyright remains with the performer/rights holder; confirm a licence before any public store release.
- `assets/data/names_timings.json` — per-name start times. Generated by `scripts/audio/align_names.py` from faster-whisper "medium" word timestamps (`scripts/audio/asma_husna_words_whisper_medium.json`), globally aligned to the Tirmidhi (3507) order in `names.json`. All 99 names matched in order; opening verse ends at ~22.9 s, closing praise starts at ~163.2 s.
