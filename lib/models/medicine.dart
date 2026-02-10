import 'package:hive/hive.dart';
import 'reminder_time.dart';

part 'medicine.g.dart';

@HiveType(typeId: 0)
class Medicine extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String amount; // "1 Tablet", "500 mg" etc.

  @HiveField(2)
  int hour; // Deprecated: use reminders

  @HiveField(3)
  int minute; // Deprecated: use reminders

  @HiveField(4)
  bool isActive;

  @HiveField(5)
  List<DateTime> log;

  @HiveField(6)
  List<int>? weekdays; // 1=Mon, 7=Sun. null/empty = all days

  @HiveField(7)
  List<ReminderTime>? reminders;

  Medicine({
    required this.name,
    required this.amount,
    this.hour = 9,
    this.minute = 0,
    this.isActive = true,
    List<DateTime>? log,
    this.weekdays,
    this.reminders,
  }) : log = log ?? [];
}
