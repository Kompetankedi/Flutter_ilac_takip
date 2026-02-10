import 'package:hive/hive.dart';

part 'reminder_time.g.dart';

@HiveType(typeId: 1)
class ReminderTime extends HiveObject {
  @HiveField(0)
  int hour;

  @HiveField(1)
  int minute;

  ReminderTime({required this.hour, required this.minute});
}
