import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _notificationId = 1;
  static const _prefHourKey = 'reminder_hour';
  static const _prefMinuteKey = 'reminder_minute';
  static const _prefEnabledKey = 'reminder_enabled';

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);
  }

  static Future<void> scheduleDaily({
    required int hour,
    required int minute,
  }) async {
    await _plugin.cancel(_notificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _notificationId,
      'Waktunya membaca!',
      'Luangkan waktu sejenak untuk membaca hari ini.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reading_reminder',
          'Pengingat Membaca',
          channelDescription: 'Notifikasi pengingat membaca harian',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefHourKey, hour);
    await prefs.setInt(_prefMinuteKey, minute);
    await prefs.setBool(_prefEnabledKey, true);
  }

  static Future<void> cancel() async {
    await _plugin.cancel(_notificationId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabledKey, false);
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool(_prefEnabledKey) ?? false,
      'hour': prefs.getInt(_prefHourKey) ?? 20,
      'minute': prefs.getInt(_prefMinuteKey) ?? 0,
    };
  }

  static Future<bool> requestPermission() async {
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    return await androidImplementation?.requestNotificationsPermission() ??
        true;
  }
}
