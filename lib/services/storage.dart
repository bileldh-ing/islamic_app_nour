import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin persistent store + app-wide settings notifier.
class Store {
  Store._();
  static late SharedPreferences prefs;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    settings.value = AppSettings.fromJson(_readJson('settings') ?? {});
  }

  static final ValueNotifier<AppSettings> settings = ValueNotifier(AppSettings());

  static Future<void> saveSettings(AppSettings s) async {
    settings.value = s;
    await prefs.setString('settings', jsonEncode(s.toJson()));
  }

  static Map<String, dynamic>? _readJson(String key) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? getJson(String key) => _readJson(key);
  static Future<void> setJson(String key, Object value) => prefs.setString(key, jsonEncode(value));

  static List<String> getList(String key) => prefs.getStringList(key) ?? [];
  static Future<void> setList(String key, List<String> v) => prefs.setStringList(key, v);

  static int getInt(String key, [int def = 0]) => prefs.getInt(key) ?? def;
  static Future<void> setInt(String key, int v) => prefs.setInt(key, v);

  static bool getBool(String key, [bool def = false]) => prefs.getBool(key) ?? def;
  static Future<void> setBool(String key, bool v) => prefs.setBool(key, v);

  static String? getString(String key) => prefs.getString(key);
  static Future<void> setString(String key, String v) => prefs.setString(key, v);

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class AppSettings {
  AppSettings({
    this.method = 'muslimWorldLeague',
    this.madhab = 'shafi',
    this.highLatitude = 'middleOfTheNight',
    this.hijriAdjust = 0,
    this.prayerAlerts = const {'fajr': true, 'dhuhr': true, 'asr': true, 'maghrib': true, 'isha': true, 'sunrise': false},
    this.adhanSound = true,
    this.preReminderMinutes = 10,
    this.morningAzkar = true,
    this.eveningAzkar = true,
    this.kahfFriday = true,
    this.fastingReminders = true,
    this.quranFontSize = 28,
    this.showTafsir = true,
    this.translation = 'none',
    this.reciter = 'ar.alafasy',
    this.adjustments = const {},
    this.tasbihGoal = 100,
    this.dailyGoalPages = 4,
    this.hapticsOn = true,
    this.use24h = true,
    this.accent = 'emerald',
    this.themeMode = 'system',
  });

  final String method;
  final String madhab;
  final String highLatitude;
  final int hijriAdjust;
  final Map<String, bool> prayerAlerts;
  final bool adhanSound;
  final int preReminderMinutes; // 0 = off
  final bool morningAzkar;
  final bool eveningAzkar;
  final bool kahfFriday;
  final bool fastingReminders;
  final double quranFontSize;
  final bool showTafsir;
  final String translation; // none | en.sahih | fr.hamidullah
  final String reciter;
  final Map<String, int> adjustments; // minutes per prayer
  final int tasbihGoal;
  final int dailyGoalPages;
  final bool hapticsOn;
  final bool use24h;
  final String accent;
  final String themeMode;

  AppSettings copyWith({
    String? method,
    String? madhab,
    String? highLatitude,
    int? hijriAdjust,
    Map<String, bool>? prayerAlerts,
    bool? adhanSound,
    int? preReminderMinutes,
    bool? morningAzkar,
    bool? eveningAzkar,
    bool? kahfFriday,
    bool? fastingReminders,
    double? quranFontSize,
    bool? showTafsir,
    String? translation,
    String? reciter,
    Map<String, int>? adjustments,
    int? tasbihGoal,
    int? dailyGoalPages,
    bool? hapticsOn,
    bool? use24h,
    String? accent,
    String? themeMode,
  }) =>
      AppSettings(
        method: method ?? this.method,
        madhab: madhab ?? this.madhab,
        highLatitude: highLatitude ?? this.highLatitude,
        hijriAdjust: hijriAdjust ?? this.hijriAdjust,
        prayerAlerts: prayerAlerts ?? this.prayerAlerts,
        adhanSound: adhanSound ?? this.adhanSound,
        preReminderMinutes: preReminderMinutes ?? this.preReminderMinutes,
        morningAzkar: morningAzkar ?? this.morningAzkar,
        eveningAzkar: eveningAzkar ?? this.eveningAzkar,
        kahfFriday: kahfFriday ?? this.kahfFriday,
        fastingReminders: fastingReminders ?? this.fastingReminders,
        quranFontSize: quranFontSize ?? this.quranFontSize,
        showTafsir: showTafsir ?? this.showTafsir,
        translation: translation ?? this.translation,
        reciter: reciter ?? this.reciter,
        adjustments: adjustments ?? this.adjustments,
        tasbihGoal: tasbihGoal ?? this.tasbihGoal,
        dailyGoalPages: dailyGoalPages ?? this.dailyGoalPages,
        hapticsOn: hapticsOn ?? this.hapticsOn,
        use24h: use24h ?? this.use24h,
        accent: accent ?? this.accent,
        themeMode: themeMode ?? this.themeMode,
      );

  Map<String, dynamic> toJson() => {
        'method': method,
        'madhab': madhab,
        'highLatitude': highLatitude,
        'hijriAdjust': hijriAdjust,
        'prayerAlerts': prayerAlerts,
        'adhanSound': adhanSound,
        'preReminderMinutes': preReminderMinutes,
        'morningAzkar': morningAzkar,
        'eveningAzkar': eveningAzkar,
        'kahfFriday': kahfFriday,
        'fastingReminders': fastingReminders,
        'quranFontSize': quranFontSize,
        'showTafsir': showTafsir,
        'translation': translation,
        'reciter': reciter,
        'adjustments': adjustments,
        'tasbihGoal': tasbihGoal,
        'dailyGoalPages': dailyGoalPages,
        'hapticsOn': hapticsOn,
        'use24h': use24h,
        'accent': accent,
        'themeMode': themeMode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final d = AppSettings();
    return AppSettings(
      method: j['method'] ?? d.method,
      madhab: j['madhab'] ?? d.madhab,
      highLatitude: j['highLatitude'] ?? d.highLatitude,
      hijriAdjust: (j['hijriAdjust'] ?? d.hijriAdjust) as int,
      prayerAlerts: j['prayerAlerts'] == null
          ? d.prayerAlerts
          : Map<String, bool>.from(j['prayerAlerts'] as Map),
      adhanSound: j['adhanSound'] ?? d.adhanSound,
      preReminderMinutes: (j['preReminderMinutes'] ?? d.preReminderMinutes) as int,
      morningAzkar: j['morningAzkar'] ?? d.morningAzkar,
      eveningAzkar: j['eveningAzkar'] ?? d.eveningAzkar,
      kahfFriday: j['kahfFriday'] ?? d.kahfFriday,
      fastingReminders: j['fastingReminders'] ?? d.fastingReminders,
      quranFontSize: ((j['quranFontSize'] ?? d.quranFontSize) as num).toDouble(),
      showTafsir: j['showTafsir'] ?? d.showTafsir,
      translation: j['translation'] ?? d.translation,
      reciter: j['reciter'] ?? d.reciter,
      adjustments: j['adjustments'] == null ? d.adjustments : Map<String, int>.from(j['adjustments'] as Map),
      tasbihGoal: (j['tasbihGoal'] ?? d.tasbihGoal) as int,
      dailyGoalPages: (j['dailyGoalPages'] ?? d.dailyGoalPages) as int,
      hapticsOn: (j['hapticsOn'] ?? d.hapticsOn) as bool,
      use24h: (j['use24h'] ?? d.use24h) as bool,
      accent: (j['accent'] ?? d.accent) as String,
      themeMode: (j['themeMode'] ?? d.themeMode) as String,
    );
  }
}
