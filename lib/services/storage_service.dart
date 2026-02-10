import 'package:hive_flutter/hive_flutter.dart';
import '../models/medicine.dart';
import '../models/reminder_time.dart';

class StorageService {
  static const String boxName = 'medicines_box';
  static const String settingsBoxName = 'settings_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(MedicineAdapter());
    Hive.registerAdapter(ReminderTimeAdapter());
    await Hive.openBox<Medicine>(boxName);
    await Hive.openBox(settingsBoxName);
  }

  static Box<Medicine> getBox() {
    return Hive.box<Medicine>(boxName);
  }

  static Future<void> addMedicine(Medicine medicine) async {
    final box = getBox();
    await box.add(medicine);
  }

  static Future<void> updateMedicine(Medicine medicine) async {
    await medicine.save();
  }

  static Future<void> deleteMedicine(Medicine medicine) async {
    await medicine.delete();
  }

  static List<Medicine> getAllMedicines() {
    final box = getBox();
    return box.values.toList();
  }

  // Settings / Onboarding
  static bool isFirstRun() {
    final box = Hive.box(settingsBoxName);
    return box.get('first_run', defaultValue: true);
  }

  static Future<void> setFirstRunCompleted() async {
    final box = Hive.box(settingsBoxName);
    await box.put('first_run', false);
  }

  static bool getBatteryWarningShown() {
    final box = Hive.box(settingsBoxName);
    return box.get('battery_warning_shown', defaultValue: false);
  }

  static Future<void> setBatteryWarningShown(bool value) async {
    final box = Hive.box(settingsBoxName);
    await box.put('battery_warning_shown', value);
  }
}
