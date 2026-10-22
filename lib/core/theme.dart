import 'package:flutter/material.dart';

/// Noor v2 design tokens. Every screen reads colours through `context.noor`
/// so light and dark modes (and the user's accent choice) stay consistent.
class NoorAccent {
  const NoorAccent(this.id, this.name, this.color, this.soft);
  final String id;
  final String name;
  final Color color;
  final Color soft;

  static const emerald = NoorAccent('emerald', 'زمرّدي', Color(0xFF22C59A), Color(0xFF7EF0CF));
  static const gold = NoorAccent('gold', 'ذهبي', Color(0xFFD9A84E), Color(0xFFF5D894));
  static const violet = NoorAccent('violet', 'بنفسجي', Color(0xFF8B6CF6), Color(0xFFC4B5FD));
  static const sky = NoorAccent('sky', 'سماوي', Color(0xFF3BA7F5), Color(0xFF9AD3FF));
  static const rose = NoorAccent('rose', 'وردي', Color(0xFFE76F8E), Color(0xFFFFB3C6));
  static const all = [emerald, gold, violet, sky, rose];
  static NoorAccent byId(String id) => all.firstWhere((a) => a.id == id, orElse: () => emerald);
}

@immutable
class NoorPalette extends ThemeExtension<NoorPalette> {
  const NoorPalette({
    required this.isDark,
    required this.accent,
    required this.accentSoft,
    required this.gold,
    required this.bgTop,
    required this.bgBottom,
    required this.glass,
    required this.glassStrong,
    required this.glassBorder,
    required this.hairline,
    required this.text,
    required this.textSoft,
    required this.textFaint,
    required this.shadow,
    required this.danger,
    required this.success,
    required this.pattern,
  });

  final bool isDark;
  final Color accent;
  final Color accentSoft;
  final Color gold;
  final Color bgTop;
  final Color bgBottom;
  final Color glass; // translucent surface fill
  final Color glassStrong; // selected pill / sheet fill
  final Color glassBorder;
  final Color hairline;
  final Color text;
  final Color textSoft;
  final Color textFaint;
  final Color shadow;
  final Color danger;
  final Color success;
  final Color pattern; // geometric pattern stroke

  /// Text/icon colour that reads on top of [accent].
  Color get onAccent => isDark ? const Color(0xFF07130F) : Colors.white;

  static NoorPalette dark(NoorAccent a) => NoorPalette(
        isDark: true,
        accent: a.color,
        accentSoft: a.soft,
        gold: const Color(0xFFE2B866),
        bgTop: const Color(0xFF1B2133),
        bgBottom: const Color(0xFF0D1120),
        glass: const Color(0x1AFFFFFF),
        glassStrong: const Color(0x2EFFFFFF),
        glassBorder: const Color(0x33FFFFFF),
        hairline: const Color(0x1FFFFFFF),
        text: const Color(0xFFF4F6FB),
        textSoft: const Color(0xB8E6EAF5),
        textFaint: const Color(0x75E6EAF5),
        shadow: const Color(0x66000000),
        danger: const Color(0xFFFF7B7B),
        success: const Color(0xFF4ADE9B),
        pattern: const Color(0x14FFFFFF),
      );

  static NoorPalette light(NoorAccent a) => NoorPalette(
        isDark: false,
        accent: Color.lerp(a.color, Colors.black, 0.08)!,
        accentSoft: a.color.withValues(alpha: 0.16),
        gold: const Color(0xFFB8862F),
        bgTop: const Color(0xFFEFF2F8),
        bgBottom: const Color(0xFFE3E8F1),
        glass: const Color(0x9EFFFFFF),
        glassStrong: const Color(0xE6FFFFFF),
        glassBorder: const Color(0xCCFFFFFF),
        hairline: const Color(0x14101828),
        text: const Color(0xFF111827),
        textSoft: const Color(0xFF4B5565),
        textFaint: const Color(0xFF8A94A6),
        shadow: const Color(0x1A1E2A4A),
        danger: const Color(0xFFE5484D),
        success: const Color(0xFF12A579),
        pattern: const Color(0x0F1E2A4A),
      );

  @override
  NoorPalette copyWith() => this;

  @override
  NoorPalette lerp(ThemeExtension<NoorPalette>? other, double t) {
    if (other is! NoorPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return NoorPalette(
      isDark: t < 0.5 ? isDark : other.isDark,
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      gold: l(gold, other.gold),
      bgTop: l(bgTop, other.bgTop),
      bgBottom: l(bgBottom, other.bgBottom),
      glass: l(glass, other.glass),
      glassStrong: l(glassStrong, other.glassStrong),
      glassBorder: l(glassBorder, other.glassBorder),
      hairline: l(hairline, other.hairline),
      text: l(text, other.text),
      textSoft: l(textSoft, other.textSoft),
      textFaint: l(textFaint, other.textFaint),
      shadow: l(shadow, other.shadow),
      danger: l(danger, other.danger),
      success: l(success, other.success),
      pattern: l(pattern, other.pattern),
    );
  }
}

extension NoorContext on BuildContext {
  NoorPalette get noor => Theme.of(this).extension<NoorPalette>()!;
}

class NoorFonts {
  static const ui = 'Plex';
  static const arabic = 'Amiri';
  static const quran = 'AmiriQuran';
}

/// Type scale (IBM Plex Sans Arabic).
class NoorText {
  static TextStyle display(BuildContext c) =>
      TextStyle(fontFamily: NoorFonts.ui, fontSize: 44, fontWeight: FontWeight.w600, height: 1.05, color: c.noor.text, letterSpacing: -0.5);
  static TextStyle h1(BuildContext c) => TextStyle(fontFamily: NoorFonts.ui, fontSize: 26, fontWeight: FontWeight.w700, color: c.noor.text, height: 1.25);
  static TextStyle h2(BuildContext c) => TextStyle(fontFamily: NoorFonts.ui, fontSize: 20, fontWeight: FontWeight.w700, color: c.noor.text, height: 1.3);
  static TextStyle h3(BuildContext c) => TextStyle(fontFamily: NoorFonts.ui, fontSize: 16, fontWeight: FontWeight.w600, color: c.noor.text, height: 1.35);
  static TextStyle body(BuildContext c) => TextStyle(fontFamily: NoorFonts.ui, fontSize: 14.5, fontWeight: FontWeight.w400, color: c.noor.textSoft, height: 1.6);
  static TextStyle label(BuildContext c) => TextStyle(fontFamily: NoorFonts.ui, fontSize: 12.5, fontWeight: FontWeight.w500, color: c.noor.textSoft, height: 1.3);
  static TextStyle caption(BuildContext c) => TextStyle(fontFamily: NoorFonts.ui, fontSize: 11.5, fontWeight: FontWeight.w400, color: c.noor.textFaint, height: 1.3);
  static TextStyle number(BuildContext c, {double size = 16, FontWeight w = FontWeight.w600}) => TextStyle(
      fontFamily: NoorFonts.ui, fontSize: size, fontWeight: w, color: c.noor.text, fontFeatures: const [FontFeature.tabularFigures()]);
  static TextStyle quran(BuildContext c, double size) =>
      TextStyle(fontFamily: NoorFonts.quran, fontSize: size, height: 2.05, color: c.noor.text);
  static TextStyle arabic(BuildContext c, double size, {FontWeight w = FontWeight.w400}) =>
      TextStyle(fontFamily: NoorFonts.arabic, fontSize: size, height: 1.9, color: c.noor.text, fontWeight: w);
}

class NoorTheme {
  static ThemeData build(Brightness b, NoorAccent accent) {
    final p = b == Brightness.dark ? NoorPalette.dark(accent) : NoorPalette.light(accent);
    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      fontFamily: NoorFonts.ui,
      scaffoldBackgroundColor: p.bgBottom,
      colorScheme: ColorScheme.fromSeed(seedColor: accent.color, brightness: b).copyWith(
        primary: p.accent,
        onPrimary: p.onAccent,
        surface: p.bgBottom,
        onSurface: p.text,
      ),
      splashFactory: InkSparkle.splashFactory,
      extensions: [p],
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text, fontFamily: NoorFonts.ui),
      iconTheme: IconThemeData(color: p.text, size: 22),
      dividerColor: p.hairline,
      appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: p.text),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : p.textSoft),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.glassStrong),
        trackOutlineColor: WidgetStateProperty.all(p.glassBorder),
      ),
      sliderTheme: SliderThemeData(activeTrackColor: p.accent, thumbColor: p.accent, inactiveTrackColor: p.glassStrong),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? const Color(0xFF242B40) : const Color(0xFF1F2937),
        contentTextStyle: const TextStyle(fontFamily: NoorFonts.ui, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent, elevation: 0),
      textSelectionTheme: TextSelectionThemeData(cursorColor: p.accent),
    );
  }
}
