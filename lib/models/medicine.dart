import 'package:hive/hive.dart';

part 'medicine.g.dart';

@HiveType(typeId: 0)
class Medicine extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String amount; // "1 Tablet", "500 mg" etc.

  @HiveField(2)
  int hour;

  @HiveField(3)
  int minute;

  @HiveField(4)
  bool isActive;

  @HiveField(5)
  List<DateTime> log;

  Medicine({
    required this.name,
    required this.amount,
    required this.hour,
    required this.minute,
    this.isActive = true,
    List<DateTime>? log,
  }) : log = log ?? [];
}
