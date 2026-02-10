import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'storage_service.dart';
import '../models/reminder_time.dart';

class NotificationService {
  static Future<void> init() async {
    await AwesomeNotifications().initialize(
      // set the icon to null if you want to use the default app icon
      // set the icon to null if you want to use the default app icon
      null,
      [
        NotificationChannel(
          channelGroupKey: 'medication_channel_group',
          channelKey: 'medication_channel',
          channelName: 'Medication Reminders',
          channelDescription: 'Reminders to take your medication',
          defaultColor: const Color(0xFF2196F3),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          // 'medication_alarm' must be in android/app/src/main/res/raw
          // If it doesn't exist, it will fall back to default or silence depending on implementation.
          // For now, let's keep it simple or use default if custom fails.
          // awesome_notifications handles resources differently, usually just "filename" without extension.
          soundSource: 'resource://raw/medication_alarm',
        ),
      ],
      // Channel groups are only visual and are optional
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: 'medication_channel_group',
          channelGroupName: 'Medication Group',
        ),
      ],
      debug: true,
    );

    // Request permission immediately on init if you want, or handle it in UI
    await checkPermissions();

    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );
  }

  static Future<void> checkPermissions() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    // Precise Alarms (Exact Alarms) - Android 12+
    // Check if it's already allowed to avoid the settings loop
    List<NotificationPermission> allowed = await AwesomeNotifications()
        .checkPermissionList(
          permissions: [NotificationPermission.PreciseAlarms],
        );

    if (!allowed.contains(NotificationPermission.PreciseAlarms)) {
      // Only show if not already granted.
      await AwesomeNotifications().showAlarmPage();
    }

    // 3. Battery Optimizations
    // Check if we are already ignoring battery optimizations
    bool isIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;
    if (!isIgnoring) {
      // We don't want to redirect unconditionally here because it's invasive.
    }
  }

  static Future<void> openAutoStartSettings() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final manufacturer = androidInfo.manufacturer.toLowerCase();

      if (manufacturer.contains('xiaomi')) {
        const intent = AndroidIntent(
          action: 'action_main',
          package: 'com.miui.securitycenter',
          componentName:
              'com.miui.permcenter.autostart.AutoStartManagementActivity',
        );
        try {
          await intent.launch();
          return;
        } catch (e) {
          debugPrint('Could not launch Xiaomi auto-start settings: $e');
        }
      }

      // Fallback for other manufacturers or if specific intent fails
      await openAppSettings();
    }
  }

  static Future<void> scheduleMedicineReminders({
    required int id, // medicineKey
    required String title,
    required String body,
    required List<int>? weekdays,
    required List<ReminderTime> reminders,
  }) async {
    String localTimeZone = await AwesomeNotifications()
        .getLocalTimeZoneIdentifier();

    // Cancel existing first to be safe (or caller should do it)
    await cancelAllMedicineReminders(id);

    for (int i = 0; i < reminders.length; i++) {
      final time = reminders[i];

      if (weekdays == null || weekdays.isEmpty || weekdays.length == 7) {
        // Daily
        final notificationId = (id * 1000) + i;
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: notificationId,
            channelKey: 'medication_channel',
            title: title,
            body: body,
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Alarm,
            wakeUpScreen: true,
            fullScreenIntent: true,
            autoDismissible: false,
            payload: {'medicineId': id.toString()},
          ),
          schedule: NotificationCalendar(
            hour: time.hour,
            minute: time.minute,
            second: 0,
            millisecond: 0,
            timeZone: localTimeZone,
            repeats: true,
            allowWhileIdle: true,
            preciseAlarm: true,
          ),
        );
      } else {
        // Specific weekdays
        for (final day in weekdays) {
          final notificationId = (id * 1000) + (day * 10) + i;
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: notificationId,
              channelKey: 'medication_channel',
              title: title,
              body: body,
              notificationLayout: NotificationLayout.Default,
              category: NotificationCategory.Alarm,
              wakeUpScreen: true,
              fullScreenIntent: true,
              autoDismissible: false,
              payload: {'medicineId': id.toString()},
            ),
            schedule: NotificationCalendar(
              weekday: day,
              hour: time.hour,
              minute: time.minute,
              second: 0,
              millisecond: 0,
              timeZone: localTimeZone,
              repeats: true,
              allowWhileIdle: true,
              preciseAlarm: true,
            ),
          );
        }
      }
    }
  }

  static Future<void> cancelAllMedicineReminders(int id) async {
    // Cancel daily versions (0-99)
    for (int i = 0; i < 100; i++) {
      await AwesomeNotifications().cancel((id * 1000) + i);
    }
    // Cancel weekday versions (10-79)
    for (int day = 1; day <= 7; day++) {
      for (int i = 0; i < 10; i++) {
        await AwesomeNotifications().cancel((id * 1000) + (day * 10) + i);
      }
    }
    // Also cancel old style ID (if it was just 'id')
    await AwesomeNotifications().cancel(id);
  }

  static Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  static Future<void> cancelAll() async {
    await AwesomeNotifications().cancelAll();
  }

  /// Schedules 15 one-shot notifications starting 1 minute from now.
  /// IDs will be derived from the medicineId: (medicineId * 100) + i
  static Future<void> scheduleNaggingNotifications({
    required int medicineId,
    required String title,
    required String body,
  }) async {
    String localTimeZone = await AwesomeNotifications()
        .getLocalTimeZoneIdentifier();

    for (int i = 1; i <= 15; i++) {
      // Schedule for i minutes from now
      final scheduledDate = DateTime.now().add(Duration(minutes: i));

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: (medicineId * 100) + i, // Derived ID
          channelKey: 'medication_channel',
          title: '$title (Hatırlatma $i)',
          body: body,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Alarm,
          wakeUpScreen: true,
          fullScreenIntent: true,
          autoDismissible: false,
        ),
        schedule: NotificationCalendar(
          hour: scheduledDate.hour,
          minute: scheduledDate.minute,
          second: 0,
          millisecond: 0,
          timeZone: localTimeZone,
          repeats: false, // One-shot
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
      );
    }
  }

  static Future<void> cancelNaggingNotifications(int medicineId) async {
    for (int i = 1; i <= 15; i++) {
      await AwesomeNotifications().cancel((medicineId * 100) + i);
    }
  }

  static Future<void> cancelAllNotifications(int medicineId) async {
    await cancelAllMedicineReminders(medicineId);
    await cancelNaggingNotifications(medicineId);
  }

  /// Use this method to detect when a new notification or a schedule is created
  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    // Check if it's a medication reminder
    if (receivedNotification.channelKey == 'medication_channel' &&
        receivedNotification.id != null) {
      if (receivedNotification.payload?['isNag'] == 'true') {
        return;
      }

      // It is a main notification. Schedule nagging.
      // Get the medicineId from payload or derive it
      int? medicineId;
      if (receivedNotification.payload != null &&
          receivedNotification.payload!['medicineId'] != null) {
        medicineId = int.tryParse(receivedNotification.payload!['medicineId']!);
      }

      if (medicineId == null) {
        // Fallback or derive from complex ID
        // (id * 1000) + ...
        medicineId = receivedNotification.id! ~/ 1000;
        if (medicineId == 0) medicineId = receivedNotification.id!; // Old style
      }

      // ENSURE BACKGROUND INITIALIZATION
      try {
        if (!StorageService.getBox().isOpen) {
          await StorageService.init();
        }
      } catch (e) {
        try {
          await StorageService.init();
        } catch (_) {}
      }

      // Check if medicine was already taken today
      try {
        final box = StorageService.getBox();
        final medicine = box.get(medicineId);
        if (medicine != null) {
          final now = DateTime.now();
          bool alreadyTaken = medicine.log.any(
            (d) =>
                d.year == now.year && d.month == now.month && d.day == now.day,
          );
          if (alreadyTaken) {
            debugPrint('Medicine $medicineId already taken, skipping nags.');
            return;
          }
        }
      } catch (e) {
        debugPrint('Error checking taken status: $e');
      }

      String title = receivedNotification.title ?? 'İlaç Vakti';
      String body = receivedNotification.body ?? 'İlacınızı almayı unutmayın!';

      await scheduleNaggingNotifications(
        medicineId: medicineId,
        title: title,
        body: body,
      );
    }
  }

  /// Use this method to detect when the user taps on a notification or action button
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    // Navigate to specific page if needed, or handle actions like "Take"
  }

  /// Use this method to detect when a new notification or a schedule is created
  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    // Your code goes here
  }

  /// Use this method to detect when the user dismisses a notification
  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    // Your code goes here
  }
}
