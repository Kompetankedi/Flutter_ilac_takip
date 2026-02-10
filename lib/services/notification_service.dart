import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'storage_service.dart';

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

  static Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    // Ensure time zone is local
    String localTimeZone = await AwesomeNotifications()
        .getLocalTimeZoneIdentifier();

    debugPrint(
      'Ex: Scheduling daily notification for ID: $id at $hour:$minute',
    );

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'medication_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Alarm,
        wakeUpScreen: true,
        fullScreenIntent: true,
        autoDismissible: false,
      ),
      schedule: NotificationCalendar(
        hour: hour,
        minute: minute,
        second: 0,
        millisecond: 0,
        timeZone: localTimeZone,
        repeats: true,
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );
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
    await cancelNotification(medicineId);
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
      // Avoid infinite loop: Check if this is ALREADY a nag (derived ID)
      // Main IDs are likely < 10000. Nags are ID*100 + i.
      // If we assume max medicine ID is 9999, then any ID > 1000000 might be a nag?
      // Better: Store "isNag" in payload?
      // payload: {'isNag': 'true'}

      if (receivedNotification.payload?['isNag'] == 'true') {
        return;
      }

      // It is a main notification. Schedule nagging.
      int id = receivedNotification.id!;

      // ENSURE BACKGROUND INITIALIZATION
      // The background isolate starts fresh and might not have initialized Hive.
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
        final medicine = box.get(id);
        if (medicine != null) {
          final now = DateTime.now();
          bool alreadyTaken = medicine.log.any(
            (d) =>
                d.year == now.year && d.month == now.month && d.day == now.day,
          );
          if (alreadyTaken) {
            debugPrint('Medicine $id already taken, skipping nags.');
            return;
          }
        }
      } catch (e) {
        debugPrint('Error checking taken status: $e');
      }

      String title = receivedNotification.title ?? 'İlaç Vakti';
      String body = receivedNotification.body ?? 'İlacınızı almayı unutmayın!';

      await scheduleNaggingNotifications(
        medicineId: id,
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
