import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// নোট/টাস্ক রিমাইন্ডার নোটিফিকেশন ম্যানেজ করে।
/// Isar-এর `id` (int) কে সরাসরি notification id হিসেবে ব্যবহার করা হয়,
/// কিন্তু Note ও Task উভয়ের id একই রেঞ্জে থাকতে পারে বলে সংঘর্ষ এড়াতে
/// note হলে id, task হলে id + 1000000 অফসেট ব্যবহার করা হয়েছে।
///
/// flutter_local_notifications ^22.x থেকে সব মেথড (initialize, zonedSchedule,
/// cancel) পুরোপুরি named-parameter ভিত্তিক — এই ফাইল সেই নতুন API অনুসরণ করে।
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const int taskIdOffset = 1000000;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // ডিভাইসের লোকাল টাইমজোন সঠিকভাবে সেট করা কঠিন হতে পারে বিভিন্ন
    // প্ল্যাটফর্মে; সরলতার জন্য tz.local ব্যবহার করা হচ্ছে যা ডিফল্টরূপে UTC
    // থেকে শুরু করে, প্রোডাকশনে flutter_native_timezone জাতীয় প্যাকেজ
    // দিয়ে সঠিক টাইমজোন সেট করার পরামর্শ থাকবে।

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();

      const channel = AndroidNotificationChannel(
        'reminders_channel',
        'রিমাইন্ডার',
        description: 'নোট ও টাস্কের রিমাইন্ডার নোটিফিকেশন',
        importance: Importance.high,
      );
      await androidImpl?.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders_channel',
          'রিমাইন্ডার',
          channelDescription: 'নোট ও টাস্কের রিমাইন্ডার নোটিফিকেশন',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  Future<void> scheduleNoteReminder({
    required int noteId,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_initialized) await init();
    if (scheduledTime.isBefore(DateTime.now())) return;

    try {
      await _plugin.zonedSchedule(
        id: noteId,
        title: title.isEmpty ? 'নোট রিমাইন্ডার' : title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Note reminder schedule failed: $e');
    }
  }

  Future<void> scheduleTaskReminder({
    required int taskId,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_initialized) await init();
    if (scheduledTime.isBefore(DateTime.now())) return;

    try {
      await _plugin.zonedSchedule(
        id: taskId + taskIdOffset,
        title: title.isEmpty ? 'টাস্ক রিমাইন্ডার' : title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Task reminder schedule failed: $e');
    }
  }

  Future<void> cancelNoteReminder(int noteId) => _plugin.cancel(id: noteId);

  Future<void> cancelTaskReminder(int taskId) =>
      _plugin.cancel(id: taskId + taskIdOffset);

  Future<void> cancelAll() => _plugin.cancelAll();
}
