import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Color, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'hijri_service.dart';
import 'prayer_service.dart';
import 'storage.dart';

/// Schedules Athan alerts, pre-prayer reminders, azkar, Surat al-Kahf
/// and sunnah-fasting reminders as exact local notifications.
class NotificationService {
  NotificationService._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

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
    'التذكيرات',
    description: 'تذكير قبل الصلاة، الأذكار، سورة الكهف، الصيام',
    importance: Importance.high,
  );

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
    await _plugin.initialize(settings: settings);
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_adhanChannel);
    await android?.createNotificationChannel(_prayerChannel);
    await android?.createNotificationChannel(_reminderChannel);
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
          priority: Priority.max,
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

  static Future<void> _at(int id, DateTime when, String title, String body, NotificationDetails d,
      {DateTimeComponents? repeat}) async {
    final t = tz.TZDateTime.from(when, tz.local);
    if (repeat == null && t.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: t,
      notificationDetails: d,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      title: title,
      body: body,
      matchDateTimeComponents: repeat,
    );
  }

  static tz.TZDateTime _nextAt(int hour, int minute, {int? weekday}) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (t.isBefore(now) || (weekday != null && t.weekday != weekday)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  static const _bodies = {
    PrayerName.fajr: 'الصلاة خير من النوم — حان الآن وقت صلاة الفجر',
    PrayerName.sunrise: 'أشرقت الشمس — انتهى وقت صلاة الفجر',
    PrayerName.dhuhr: 'حان الآن وقت صلاة الظهر',
    PrayerName.asr: 'حان الآن وقت صلاة العصر',
    PrayerName.maghrib: 'حان الآن وقت صلاة المغرب',
    PrayerName.isha: 'حان الآن وقت صلاة العشاء',
  };

  /// Rebuild the whole schedule. Safe to call often (app open, settings change).
  static Future<void> rescheduleAll() async {
    if (kIsWeb) return;
    try {
      await init();
      await _plugin.cancelAll();
      final s = Store.settings.value;
      final now = DateTime.now();
      const days = 5; // keeps total under iOS' 64 pending limit

      for (var d = 0; d < days; d++) {
        final day = PrayerService.forDate(now.add(Duration(days: d)));
        for (final e in day.entries) {
          if (!(s.prayerAlerts[e.name.name] ?? false)) continue;
          final base = 1000 + d * 20 + e.name.index * 2;
          final useAdhan = s.adhanSound && e.name.isFard;
          await _at(base, e.time, 'صلاة ${e.name.ar}', _bodies[e.name]!,
              _details(useAdhan ? _adhanChannel : _prayerChannel, critical: true));
          if (s.preReminderMinutes > 0 && e.name.isFard) {
            await _at(base + 1, e.time.subtract(Duration(minutes: s.preReminderMinutes)), 'اقترب وقت ${e.name.ar}',
                'بقي ${s.preReminderMinutes} دقائق على أذان ${e.name.ar}. استعد للصلاة.', _details(_reminderChannel));
          }
        }
      }

      if (s.morningAzkar) {
        await _at(1, _nextAt(7, 0), 'أذكار الصباح', 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ — حان وقت أذكار الصباح',
            _details(_reminderChannel), repeat: DateTimeComponents.time);
      }
      if (s.eveningAzkar) {
        await _at(2, _nextAt(17, 30), 'أذكار المساء', 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ — حان وقت أذكار المساء',
            _details(_reminderChannel), repeat: DateTimeComponents.time);
      }
      if (s.kahfFriday) {
        await _at(3, _nextAt(10, 0, weekday: DateTime.friday), 'جمعة مباركة',
            'لا تنسَ قراءة سورة الكهف والإكثار من الصلاة على النبي ﷺ', _details(_reminderChannel),
            repeat: DateTimeComponents.dayOfWeekAndTime);
      }
      if (s.fastingReminders) {
        for (var d = 1; d <= days; d++) {
          final g = now.add(Duration(days: d));
          final fast = HijriService.sunnahFast(g);
          if (fast == null || fast == 'صيام رمضان') continue;
          final eve = DateTime(g.year, g.month, g.day).subtract(const Duration(hours: 3)); // 21:00 the day before
          await _at(500 + d, eve, 'تذكير بالصيام', 'غدًا $fast. لا تنسَ نية الصيام والسحور.', _details(_reminderChannel));
        }
      }
    } catch (e) {
      debugPrint('Notification scheduling failed: $e');
    }
  }

  static Future<void> testAdhan() async {
    if (kIsWeb) return;
    await init();
    await _plugin.show(
      id: 9999,
      title: 'تجربة الأذان',
      body: 'هكذا سيصلك تنبيه دخول وقت الصلاة',
      notificationDetails: _details(Store.settings.value.adhanSound ? _adhanChannel : _prayerChannel, critical: true),
    );
  }
}
