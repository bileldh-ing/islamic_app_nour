# Noor v2 — build brief (shared by every contributor)

Project: `/workspace/projects/51be4712-4038-49dc-9778-5e916d87fbe7/noor` (Flutter 3.47.7 / Dart 3.13). The v1 code is kept for reference (logic you can port) at `/workspace/work/noor_v1_ref/lib/` — do NOT import from it; its UI style is obsolete.

## Product rules (non-negotiable)
- UI language: **Arabic, RTL**. All visible numbers use **Western digits 0-9** (e.g. `1247`, `05:07`), never Arabic-Indic (٠١٢). Never use `toArabicDigits`. Never format numbers/dates with an `intl` Arabic locale (it emits Arabic-Indic digits). Use `lib/core/format.dart` (`Fmt.time`, `Fmt.timeFull`, `Fmt.dateLong`, `Fmt.hijri`, `Fmt.number`, `Fmt.countdown`, `Fmt.western` to sanitise any external string).
- **No emoji anywhere.** Icons come only from Phosphor: `import 'package:phosphor_flutter/phosphor_flutter.dart';` then `Icon(PhosphorIconsRegular.mosque)` / `PhosphorIconsFill.x` / `PhosphorIconsBold.x` (these are IconData). Check that a name exists: `grep -n "static const NAME " ~/.pub-cache/hosted/pub.flutter-io.cn/phosphor_flutter-2.1.0/lib/src/phosphor_icons_regular.dart`.
- Zero tolerance for data errors: religious texts must come from authoritative sources and be verified (counts, spot checks against a second source). Never invent a hadith, dua, ayah, or reference. If you add a dataset, record its source URL in `docs/DATA_SOURCES.md` (append a section).
- Light **and** dark mode must both look premium. Never hard-code colours for text/surfaces — read `context.noor` (`NoorPalette`): `accent, accentSoft, gold, text, textSoft, textFaint, glass, glassStrong, glassBorder, hairline, danger, success, isDark, onAccent`.
- Production quality: loading, empty and error states; offline-first where possible; no debug prints; no TODOs left; `dart analyze` clean (no errors, no warnings, no infos).

## Design language (look at the reference: dark slate + frosted glass pills, line icons)
Liquid glass, premium, airy, modern (iOS-26-like). Generous spacing (20px page gutters), rounded 20–28 radii, frosted translucent surfaces, specular rims, soft colour blooms, subtle Islamic 8-point-star pattern at the top. Typography: IBM Plex Sans Arabic (`NoorFonts.ui`) for UI, `NoorFonts.quran` (Amiri Quran) for Quran text, `NoorFonts.arabic` (Amiri) for duas/hadith text. Use `NoorText.h1/h2/h3/body/label/caption/number/quran/arabic(context, ...)`.

## Building blocks — `lib/core/glass.dart` and `lib/core/theme.dart`
- `Glass(child, padding, margin, radius, onTap, strong, tint, border, shadow, width, height)` — frosted surface.
- `NoorPage(title, subtitle, actions: [GlassIconButton...], child, scroll=true, padding, floating)` — inner screen scaffold with background, back button, title. Use it for every pushed screen.
- `NoorBackground(child)` — for tab roots (wrap in `Scaffold(backgroundColor: context.noor.bgBottom, body: NoorBackground(child: SafeArea(bottom:false, child: ...)))`). Tab roots must leave **110px bottom padding** for the floating nav bar.
- `GlassIconButton(icon, onTap, badge, active)`, `GlassChip`, `ChipBar(labels, index, onChanged)`, `SectionHeader(title, onAction)` (with "عرض الكل" pill), `NoorButton(label, onTap, icon, expand, secondary)`, `IconBadge(icon, color)`, `GlassTile(title, subtitle, icon, trailing, onTap)`, `GlassProgress(value)`, `EmptyState`, `AyahNumber(n)`, `Pressable`, `tick()` (haptic), `showGlassSheet(context, title, builder)`, `push(context, Screen())` (fade/slide route).
- Settings live in `Store.settings` (`lib/services/storage.dart`, `AppSettings` + `copyWith`, `Store.saveSettings(...)`). Fields include themeMode, accent, use24h, hapticsOn, dailyGoalPages, tasbihGoal plus the prayer/quran settings. If you need a NEW setting, add it to AppSettings following the existing pattern (constructor default, field, copyWith param, toJson, fromJson) — edit with exact find/replace so you do not clobber others' additions. Simple per-feature persistence: `Store.getJson/setJson/getList/setList/getInt/setInt/getBool/setBool` with a feature-prefixed key.
- Existing services you can use/extend: `prayer_service.dart` (adhan_dart), `location_service.dart`, `hijri_service.dart` (Umm al-Qura via `hijri` pkg), `quran_service.dart` (offline `assets/data/quran.json`: 114 surahs × [uthmani, tafsir muyassar, page, juz, sajda, global#]), `content_service.dart` (azkar.json Hisn al-Muslim, names.json), `notification_service.dart`.
- Demo deep links: each suite owns a routes map (`lib/features/<suite>/*_routes.dart`) of id → builder. Register every pushable screen there; the screenshot pipeline opens `?demo&screen=<id>`.
- Navigation tabs (in `lib/main.dart`, do not edit): 0 Home, 1 Prayer (`PrayerScreen`), 2 Quran (`QuranHomeScreen`), 3 Qibla (`QiblaScreen`), 4 More (`MoreScreen`). Switch tab programmatically with `rootTab.value = i` from `lib/core/nav.dart`.

## Working rules in the shared sandbox
- Several contributors work at the same time in separate folders. Only edit files you own (listed in your task) plus append-only edits to shared files described above. Never run `git` commands (the coordinator commits). Never `flutter create`, never edit `pubspec.yaml` except adding a dependency line under `dependencies:` if truly required (tell the coordinator).
- Analyzer: the sandbox is low on RAM. ALWAYS run it serialized and scoped to your folder:
  `cd <project> && PATH=/workspace/work/sdk/flutter/bin:$PATH DART_VM_OPTIONS="--old_gen_heap_size=1500" flock /tmp/analyze.lock timeout 600 dart analyze lib/features/<yours> lib/services/<yours>.dart`
  (run in background if it may exceed 2 minutes). `flutter test`/`flutter run`/builds do not work in this sandbox — CI does that.
- Network: pub mirror env `PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`. Web fetches via curl work.
