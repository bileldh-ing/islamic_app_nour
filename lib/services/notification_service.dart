import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'hijri_service.dart';
import 'prayer_service.dart';
import 'storage.dart';

/// How a prayer time is announced.
enum AlertMode { off, notify, adhan }

/// Route ids carried as notification payloads (consumed by the shell via [NotificationService.pendingRoute]).
class NotificationRoutes {
  NotificationRoutes._();
  static const prayer = 'prayer'; // Prayer tab
  static const azkarMorning = 'azkar-morning';
  static const azkarEvening = 'azkar-evening';
  static const azkarSleep = 'azkar-sleep';
  static const kahf = 'reader?surah=18'; // Surah reader opened on Surat al-Kahf
  static const salawat = 'tasbih';
  static const tasbih = 'tasbih';
  static const fasting = 'fasting';
  static const dailyAyah = 'ayah-card';
}

class _Pending {
  _Pending(this.priority, this.when, this.title, this.body, this.details, this.payload);
  final int priority;
  final DateTime when;
  final String title;
  final String body;
  final NotificationDetails details;
  final String payload;
}

/// Schedules Athan alerts, pre-prayer reminders and the worship reminders
/// (azkar, Friday, fasting, daily ayah, tasbih) as exact local notifications.
///
/// iOS keeps at most 64 pending notifications, so everything is scheduled as
/// one-shot alerts in a rolling 5-day window, ranked by priority (prayers first,
/// nearest days first) and capped at [_maxPending]. The window is rebuilt every
/// time the app opens or a setting changes.
class NotificationService {
  NotificationService._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const _maxPending = 60;
  static const _windowDays = 5;

  /// Route id of the notification the user tapped (set on tap or cold start). The shell
  /// navigates to it and resets it to null.
  static final ValueNotifier<String?> pendingRoute = ValueNotifier(null);

  static const _remindersGroup = AndroidNotificationChannelGroup('reminders', 'التذكيرات', description: 'الأذكار والجمعة والصيام وآية اليوم');

  static const _adhanChannel = AndroidNotificationChannel(
    'adhan_v1',
    'الأذان',
    description: 'تنبيه دخول وقت الصلاة مع صوت الأذان',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('adhan'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );
  static const _prayerChannel = AndroidNotificationChannel(
    'prayer_v1',
    'أوقات الصلاة (بدون أذان)',
    description: 'تنبيه دخول وقت الصلاة بالصوت الافتراضي',
    importance: Importance.max,
  );
  static const _reminderChannel = AndroidNotificationChannel(
    'reminders_v1',
    'قبل الصلاة',
    description: 'تذكير قبل دخول وقت الصلاة',
    importance: Importance.high,
    groupId: 'reminders',
  );
  static const _azkarChannel = AndroidNotificationChannel(
    'azkar_v1',
    'الأذكار',
    description: 'أذكار الصباح والمساء والنوم',
    importance: Importance.high,
    groupId: 'reminders',
  );
  static const _fridayChannel = AndroidNotificationChannel(
    'friday_v1',
    'الجمعة',
    description: 'سورة الكهف والصلاة على النبي ﷺ',
    importance: Importance.high,
    groupId: 'reminders',
  );
  static const _fastingChannel = AndroidNotificationChannel(
    'fasting_v1',
    'الصيام',
    description: 'صيام الإثنين والخميس والأيام البيض وعرفة وعاشوراء',
    importance: Importance.high,
    groupId: 'reminders',
  );
  static const _dailyChannel = AndroidNotificationChannel(
    'daily_v1',
    'آية اليوم والتسبيح',
    description: 'آية اليوم وتذكير التسبيح',
    importance: Importance.defaultImportance,
    groupId: 'reminders',
  );

  // ---------- per-prayer alert mode ----------

  /// Effective mode for [p]: the per-prayer choice, else derived from the legacy
  /// `prayerAlerts` + global `adhanSound` settings.
  static AlertMode modeOf(PrayerName p, [AppSettings? settings]) {
    final s = settings ?? Store.settings.value;
    final m = s.alertModes[p.name];
    if (m != null) return AlertMode.values.firstWhere((e) => e.name == m, orElse: () => AlertMode.notify);
    if (!(s.prayerAlerts[p.name] ?? false)) return AlertMode.off;
    return s.adhanSound && p.isFard ? AlertMode.adhan : AlertMode.notify;
  }

  /// Persists the mode for one prayer (keeps `prayerAlerts` in sync) and reschedules.
  static Future<void> setMode(PrayerName p, AlertMode mode) async {
    final s = Store.settings.value;
    final modes = Map<String, String>.from(s.alertModes)..[p.name] = mode.name;
    final alerts = Map<String, bool>.from(s.prayerAlerts)..[p.name] = mode != AlertMode.off;
    await Store.saveSettings(s.copyWith(alertModes: modes, prayerAlerts: alerts));
    await rescheduleAll();
  }

  /// Cycles off -> notify -> adhan (sunrise: off <-> notify).
  static Future<AlertMode> cycleMode(PrayerName p) async {
    final next = switch (modeOf(p)) {
      AlertMode.off => AlertMode.notify,
      AlertMode.notify => p.isFard ? AlertMode.adhan : AlertMode.off,
      AlertMode.adhan => AlertMode.off,
    };
    await setMode(p, next);
    return next;
  }

  static bool get supported => !kIsWeb;

  // ---------- setup ----------

  static Future<void> init() async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (r) {
        final p = r.payload;
        if (p != null && p.isNotEmpty) pendingRoute.value = p;
      },
    );
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final p = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) && p != null && p.isNotEmpty) pendingRoute.value = p;
    } catch (_) {}
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannelGroup(_remindersGroup);
      for (final ch in [_adhanChannel, _prayerChannel, _reminderChannel, _azkarChannel, _fridayChannel, _fastingChannel, _dailyChannel]) {
        await android.createNotificationChannel(ch);
      }
    }
    _ready = true;
  }

  static Future<bool> requestPermissions() async {
    await init();
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ok = await a?.requestNotificationsPermission() ?? false;
      await a?.requestExactAlarmsPermission();
      return ok;
    }
    if (Platform.isIOS) {
      final i = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await i?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    return false;
  }

  static NotificationDetails _details(AndroidNotificationChannel ch, {bool critical = false}) => NotificationDetails(
        android: AndroidNotificationDetails(
          ch.id,
          ch.name,
          channelDescription: ch.description,
          importance: ch.importance,
          priority: critical ? Priority.max : Priority.high,
          category: critical ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
          color: const Color(0xFFE6BE72),
          styleInformation: const BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBanner: true,
          interruptionLevel: critical ? InterruptionLevel.timeSensitive : InterruptionLevel.active,
        ),
      );

  static const _bodies = {
    PrayerName.fajr: 'الصلاة خير من النوم — حان الآن وقت صلاة الفجر',
    PrayerName.sunrise: 'أشرقت الشمس — انتهى وقت صلاة الفجر',
    PrayerName.dhuhr: 'حان الآن وقت صلاة الظهر',
    PrayerName.asr: 'حان الآن وقت صلاة العصر',
    PrayerName.maghrib: 'حان الآن وقت صلاة المغرب',
    PrayerName.isha: 'حان الآن وقت صلاة العشاء',
  };

  static String _minutes(int n) => n >= 3 && n <= 10 ? 'دقائق' : 'دقيقة';

  /// Everything that should fire in the next [_windowDays] days, before ranking.
  static List<_Pending> _collect(AppSettings s, DateTime now) {
    final out = <_Pending>[];
    void add(int typePrio, int day, DateTime when, String title, String body, AndroidNotificationChannel ch, String payload,
        {bool critical = false}) {
      if (!when.isAfter(now)) return;
      // Nearest two days first, then the third day, then the rest; within a band by type.
      final band = day <= 1 ? 0 : (day == 2 ? 1 : 2);
      out.add(_Pending(band * 10 + typePrio, when, title, body, _details(ch, critical: critical), payload));
    }

    DateTime at(DateTime d, int h, int m) => DateTime(d.year, d.month, d.day, h, m);

    for (var d = 0; d < _windowDays; d++) {
      final date = DateTime(now.year, now.month, now.day).add(Duration(days: d));
      final day = PrayerService.forDate(date);

      // 0: prayer times
      for (final e in day.entries) {
        final mode = modeOf(e.name, s);
        if (mode == AlertMode.off) continue;
        final useAdhan = mode == AlertMode.adhan && e.name.isFard;
        final title = e.name == PrayerName.sunrise ? 'الشروق' : 'صلاة ${e.name.arOn(date)}';
        add(0, d, e.time, title, _bodies[e.name]!, useAdhan ? _adhanChannel : _prayerChannel, NotificationRoutes.prayer, critical: true);
        // 1: pre-prayer reminder
        if (s.preReminderMinutes > 0 && e.name.isFard) {
          final n = s.preReminderMinutes;
          add(1, d, e.time.subtract(Duration(minutes: n)), 'اقترب وقت ${e.name.arOn(date)}',
              'بقي $n ${_minutes(n)} على أذان ${e.name.arOn(date)}. استعد للصلاة.', _reminderChannel, NotificationRoutes.prayer);
        }
      }

      // 2: Friday & fasting
      if (date.weekday == DateTime.friday) {
        if (s.kahfFriday) {
          add(2, d, at(date, 10, 0), 'جمعة مباركة — سورة الكهف', 'لا تنسَ قراءة سورة الكهف في يوم الجمعة.', _fridayChannel, NotificationRoutes.kahf);
        }
        if (s.salawatFriday) {
          // 12:00, or 45 min before Jumu'ah when Dhuhr comes earlier than 12:30.
          final jumuah = day.timeOf(PrayerName.dhuhr);
          final noon = at(date, 12, 0);
          final when = noon.isBefore(jumuah.subtract(const Duration(minutes: 30))) ? noon : jumuah.subtract(const Duration(minutes: 45));
          add(2, d, when,
              'الصلاة على النبي ﷺ', 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ — أكثِر من الصلاة على النبي ﷺ يوم الجمعة.',
              _fridayChannel, NotificationRoutes.salawat);
        }
      }
      if (date.weekday == DateTime.thursday && s.salawatFriday) {
        add(2, d, day.timeOf(PrayerName.maghrib).add(const Duration(minutes: 20)), 'ليلة الجمعة',
            'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ — أكثِر من الصلاة على النبي ﷺ في ليلة الجمعة.', _fridayChannel,
            NotificationRoutes.salawat);
      }
      final fast = _fastReminder(s, date.add(const Duration(days: 1)));
      if (fast != null) {
        add(2, d, at(date, 21, 0), 'تذكير بالصيام', 'غدًا $fast. لا تنسَ نية الصيام والسحور.', _fastingChannel, NotificationRoutes.fasting);
      }

      // 3: azkar
      if (s.morningAzkar) {
        add(3, d, day.timeOf(PrayerName.fajr).add(Duration(minutes: s.morningAzkarTime)), 'أذكار الصباح',
            'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ — حان وقت أذكار الصباح', _azkarChannel, NotificationRoutes.azkarMorning);
      }
      if (s.eveningAzkar) {
        add(3, d, day.timeOf(PrayerName.asr).add(Duration(minutes: s.eveningAzkarTime)), 'أذكار المساء',
            'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ — حان وقت أذكار المساء', _azkarChannel, NotificationRoutes.azkarEvening);
      }
      if (s.sleepAzkar) {
        add(3, d, at(date, 22, 30), 'أذكار النوم', 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا — لا تنسَ أذكار النوم', _azkarChannel,
            NotificationRoutes.azkarSleep);
      }

      // 4: daily ayah, tasbih
      if (s.dailyAyah) {
        add(4, d, at(date, 8, 0), 'آية اليوم', 'آية جديدة في انتظارك — دقيقة مع كتاب الله تنير يومك.', _dailyChannel, NotificationRoutes.dailyAyah);
      }
      if (s.tasbihReminder) {
        add(5, d, at(date, 20, 0), 'التسبيح', 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ', _dailyChannel, NotificationRoutes.tasbih);
      }
    }
    return out;
  }

  /// Text for the evening-before fasting reminder of [g], or null.
  static String? _fastReminder(AppSettings s, DateTime g) {
    if (HijriService.fastingForbidden(g)) return null;
    final h = HijriService.of(g);
    if (h.month == 9) return null; // Ramadan has its own rhythm
    if (s.fastingReminders) {
      if (h.month == 12 && h.day == 9) return 'يوم عرفة';
      if (h.month == 1 && h.day == 9) return 'تاسوعاء';
      if (h.month == 1 && h.day == 10) return 'يوم عاشوراء';
    }
    if (s.whiteDaysReminder && h.day == 13) return 'أول الأيام البيض (13 و14 و15)';
    if (s.fastingReminders) {
      if (g.weekday == DateTime.monday) return 'الإثنين — يُستحب صيامه';
      if (g.weekday == DateTime.thursday) return 'الخميس — يُستحب صيامه';
    }
    return null;
  }

  /// Rebuild the whole schedule. Safe to call often (app open, settings change).
  static Future<void> rescheduleAll() async {
    if (kIsWeb) return;
    try {
      await init();
      await _plugin.cancelAll();
      final now = DateTime.now();
      final all = _collect(Store.settings.value, now)
        ..sort((a, b) {
          final c = a.priority.compareTo(b.priority);
          return c != 0 ? c : a.when.compareTo(b.when);
        });
      var id = 100;
      for (final n in all.take(_maxPending)) {
        await _plugin.zonedSchedule(
          id: id++,
          scheduledDate: tz.TZDateTime.from(n.when, tz.local),
          notificationDetails: n.details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          title: n.title,
          body: n.body,
          payload: n.payload,
        );
      }
    } catch (_) {
      // Scheduling is best-effort: a missing exact-alarm permission must never crash the app.
    }
  }

  /// Shows an immediate sample alert. Returns false where notifications are unsupported (web).
  static Future<bool> testAdhan({AlertMode mode = AlertMode.adhan}) async {
    if (kIsWeb) return false;
    await init();
    await _plugin.show(
      id: 9999,
      title: 'تجربة الأذان',
      body: 'هكذا سيصلك تنبيه دخول وقت الصلاة',
      notificationDetails: _details(mode == AlertMode.adhan ? _adhanChannel : _prayerChannel, critical: true),
      payload: NotificationRoutes.prayer,
    );
    return true;
  }
}
