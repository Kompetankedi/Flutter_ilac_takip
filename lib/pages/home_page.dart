import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/medicine.dart';
import '../models/reminder_time.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/l10n_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionsAndBattery();
    });
  }

  Future<void> _checkPermissionsAndBattery() async {
    // 1. Check Notification Permission
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      final result = await Permission.notification.request();
      if (!result.isGranted && mounted) {
        _showPermissionDeniedDialog();
      }
    }

    // 2. Show Battery Warning (Android only)
    if (Platform.isAndroid && mounted) {
      if (!StorageService.getBatteryWarningShown()) {
        _showBatteryOptimizationDialog();
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.text('notification_permission_title')),
        content: Text(S.text('notification_permission_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.text('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(S.text('open_settings')),
          ),
        ],
      ),
    );
  }

  void _showBatteryOptimizationDialog() {
    bool dontShowAgain = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(S.text('battery_warning_title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.text('battery_warning_body')),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Checkbox(
                        value: dontShowAgain,
                        onChanged: (value) {
                          setState(() {
                            dontShowAgain = value ?? false;
                          });
                        },
                      ),
                      Expanded(child: Text(S.text('dont_show_again'))),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    if (dontShowAgain) {
                      await StorageService.setBatteryWarningShown(true);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(S.text('ok')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (dontShowAgain) {
                      await StorageService.setBatteryWarningShown(true);
                    }
                    // Don't pop yet, let them go to settings
                    await NotificationService.openAutoStartSettings();
                  },
                  child: Text(S.text('go_to_autostart')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (dontShowAgain) {
                      await StorageService.setBatteryWarningShown(true);
                    }
                    if (context.mounted) Navigator.pop(context);
                    // Open settings (best effort)
                    openAppSettings();
                  },
                  child: Text(S.text('go_to_battery_settings')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _isTakenToday(Medicine medicine, ReminderTime reminder) {
    final now = DateTime.now();
    return medicine.log.any(
      (date) =>
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day &&
          date.hour == reminder.hour &&
          date.minute == reminder.minute,
    );
  }

  void _toggleTaken(
    Medicine medicine,
    ReminderTime reminder,
    bool? value,
  ) async {
    if (value == true) {
      final now = DateTime.now();
      medicine.log.add(
        DateTime(now.year, now.month, now.day, reminder.hour, reminder.minute),
      );
      await medicine.save();
      if (medicine.key != null) {
        await NotificationService.cancelNaggingNotifications(
          medicine.key as int,
        );
      }
    } else {
      final now = DateTime.now();
      medicine.log.removeWhere(
        (date) =>
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day &&
            date.hour == reminder.hour &&
            date.minute == reminder.minute,
      );
      await medicine.save();
    }
    setState(() {});
  }

  void _deleteMedicine(Medicine medicine) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(S.text('delete_confirm_title')),
          content: Text('${medicine.name} ${S.text('delete_confirm_body')}'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(S.text('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(S.text('delete')),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (medicine.key != null) {
        await NotificationService.cancelAllNotifications(medicine.key as int);
      }
      await StorageService.deleteMedicine(medicine);
    }
  }

  void _showMedicineDialog({Medicine? medicineToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MedicineFormSheet(medicineToEdit: medicineToEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.text('app_title')), centerTitle: true),
      body: ValueListenableBuilder<Box<Medicine>>(
        valueListenable: StorageService.getBox().listenable(),
        builder: (context, box, _) {
          final allMedicines = box.values.toList().cast<Medicine>();
          final now = DateTime.now();
          final todayWeekday = now.weekday; // 1=Mon, 7=Sun

          final List<MedicineReminder> dailyReminders = [];
          for (final m in allMedicines) {
            final weekdays = m.weekdays ?? [];
            if (weekdays.isEmpty || weekdays.contains(todayWeekday)) {
              final reminders =
                  m.reminders ?? [ReminderTime(hour: m.hour, minute: m.minute)];

              for (final r in reminders) {
                dailyReminders.add(MedicineReminder(medicine: m, reminder: r));
              }
            }
          }

          final pending = dailyReminders
              .where((mr) => !_isTakenToday(mr.medicine, mr.reminder))
              .toList();

          final takenToday = dailyReminders
              .where((mr) => _isTakenToday(mr.medicine, mr.reminder))
              .toList();

          return ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              if (pending.isNotEmpty) ...[
                _buildSectionContainer(
                  title: S.text('remaining_medicines'),
                  reminders: pending,
                  isTaken: false,
                ),
              ],
              if (takenToday.isNotEmpty) ...[
                SizedBox(height: 24.h),
                _buildSectionContainer(
                  title: S.text('completed_medicines'),
                  reminders: takenToday,
                  isTaken: true,
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMedicineDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required List<MedicineReminder> reminders,
    required bool isTaken,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isTaken
            ? Colors.grey[50]
            : Colors.blue[50]?.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isTaken ? Colors.grey[300]! : Colors.blue[200]!,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title),
          ...reminders.map((mr) => _buildMedicineCard(mr, isTaken: isTaken)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey[700],
        ),
      ),
    );
  }

  Widget _buildMedicineCard(MedicineReminder mr, {bool isTaken = false}) {
    final medicine = mr.medicine;
    final r = mr.reminder;
    final timeOfDay = TimeOfDay(hour: r.hour, minute: r.minute);

    return Dismissible(
      key: Key("${medicine.key}_${r.hour}_${r.minute}"),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: 20.w),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.blue,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _deleteMedicine(medicine);
          return true;
        } else {
          _showMedicineDialog(medicineToEdit: medicine);
          return false;
        }
      },
      child: Opacity(
        opacity: isTaken ? 0.7 : 1.0,
        child: Card(
          margin: EdgeInsets.symmetric(vertical: 6.h),
          elevation: isTaken ? 1 : 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: ListTile(
            onLongPress: isTaken
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(S.text('undo_mark')),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    _toggleTaken(medicine, r, false);
                  }
                : null,
            leading: Transform.scale(
              scale: 1.2,
              child: Checkbox(
                value: isTaken,
                onChanged: isTaken
                    ? null
                    : (val) => _toggleTaken(medicine, r, val),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                activeColor: Colors.green,
              ),
            ),
            title: Text(
              medicine.name,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                decoration: isTaken ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medicine.amount, style: TextStyle(fontSize: 14.sp)),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14.sp,
                      color: Colors.blueGrey,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      timeOfDay.format(context),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MedicineReminder {
  final Medicine medicine;
  final ReminderTime reminder;
  MedicineReminder({required this.medicine, required this.reminder});
}

class MedicineFormSheet extends StatefulWidget {
  final Medicine? medicineToEdit;
  const MedicineFormSheet({super.key, this.medicineToEdit});

  @override
  State<MedicineFormSheet> createState() => _MedicineFormSheetState();
}

class _MedicineFormSheetState extends State<MedicineFormSheet> {
  late TextEditingController nameController;
  late TextEditingController amountController;
  late List<ReminderTime> reminders;
  late List<int> selectedWeekdays;
  late String selectedUnit;
  bool _isSaving = false;

  final List<String> units = S.units;

  final List<String> dayNames = S.dayNames;

  @override
  void initState() {
    super.initState();
    final isEditing = widget.medicineToEdit != null;
    nameController = TextEditingController(
      text: isEditing ? widget.medicineToEdit!.name : '',
    );

    reminders = isEditing
        ? List.from(
            widget.medicineToEdit!.reminders ??
                [
                  ReminderTime(
                    hour: widget.medicineToEdit!.hour,
                    minute: widget.medicineToEdit!.minute,
                  ),
                ],
          )
        : [ReminderTime(hour: 9, minute: 0)];

    selectedWeekdays = isEditing
        ? List.from(widget.medicineToEdit!.weekdays ?? [])
        : [];

    String initialAmount = '';
    selectedUnit = S.units.first;

    if (isEditing) {
      final parts = widget.medicineToEdit!.amount.split(' ');
      if (parts.isNotEmpty) initialAmount = parts[0];
      if (parts.length > 1) selectedUnit = parts.sublist(1).join(' ');
    }

    if (!units.contains(selectedUnit)) {
      selectedUnit = S.units.first;
    }

    amountController = TextEditingController(text: initialAmount);
  }

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.medicineToEdit != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
        left: 24.w,
        right: 24.w,
        top: 16.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              isEditing ? S.text('edit_medicine') : S.text('add_new_medicine'),
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2196F3),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: S.text('medicine_name'),
                hintText: S.text('medicine_name_hint'),
                prefixIcon: Icon(Icons.medication, color: Colors.blue[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.blue[50],
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 16.h,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: S.text('amount'),
                      hintText: "1",
                      prefixIcon: Icon(
                        Icons.onetwothree,
                        color: Colors.blue[400],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.blue[50],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 16.h,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedUnit,
                        isExpanded: true,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.blue[400],
                        ),
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        items: units
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedUnit = value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            Text(
              S.text('reminder_days'),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[700],
              ),
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: List.generate(7, (index) {
                final day = index + 1;
                final isSelected = selectedWeekdays.contains(day);
                return FilterChip(
                  label: Text(dayNames[index]),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      if (selectedWeekdays.contains(day)) {
                        selectedWeekdays.remove(day);
                      } else {
                        selectedWeekdays.add(day);
                      }
                    });
                  },
                  selectedColor: Colors.blue[100],
                  checkmarkColor: Colors.blue,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.blue[700] : Colors.black87,
                    fontSize: 12.sp,
                  ),
                );
              }),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.text('reminder_times'),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[700],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      reminders.add(ReminderTime(hour: 9, minute: 0));
                    });
                  },
                  icon: const Icon(Icons.add, size: 20),
                  label: Text(S.text('add')),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
              ],
            ),
            ...reminders.asMap().entries.map((entry) {
              final index = entry.key;
              final time = entry.value;
              final timeOfDay = TimeOfDay(hour: time.hour, minute: time.minute);
              return Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: timeOfDay,
                    );
                    if (picked != null) {
                      setState(() {
                        reminders[index] = ReminderTime(
                          hour: picked.hour,
                          minute: picked.minute,
                        );
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_filled, color: Colors.blue[400]),
                        SizedBox(width: 12.w),
                        Text(
                          "${index + 1}${S.text('reminder_count')}",
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.black54,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            timeOfDay.format(context),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2196F3),
                            ),
                          ),
                        ),
                        if (reminders.length > 1)
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(() {
                                reminders.removeAt(index);
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            SizedBox(height: 32.h),
            SizedBox(
              height: 56.h,
              child: ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (nameController.text.isNotEmpty &&
                            amountController.text.isNotEmpty) {
                          setState(() => _isSaving = true);
                          try {
                            final amount =
                                "${amountController.text} $selectedUnit";
                            if (isEditing) {
                              final medicineToEdit = widget.medicineToEdit!;
                              medicineToEdit.name = nameController.text;
                              medicineToEdit.amount = amount;
                              medicineToEdit.weekdays = selectedWeekdays;
                              medicineToEdit.reminders = reminders;
                              await medicineToEdit.save();

                              await NotificationService.cancelAllMedicineReminders(
                                medicineToEdit.key as int,
                              );
                              await NotificationService.scheduleMedicineReminders(
                                id: medicineToEdit.key as int,
                                title:
                                    '${S.text('medicine_time_notif')}: ${medicineToEdit.name}',
                                body: '$amount ${S.text('notif_body')}',
                                weekdays: medicineToEdit.weekdays,
                                reminders: medicineToEdit.reminders ?? [],
                              );
                            } else {
                              final medicine = Medicine(
                                name: nameController.text,
                                amount: amount,
                                weekdays: selectedWeekdays,
                                reminders: reminders,
                              );
                              await StorageService.addMedicine(medicine);
                              if (medicine.isInBox) {
                                await NotificationService.scheduleMedicineReminders(
                                  id: medicine.key as int,
                                  title:
                                      '${S.text('medicine_time_notif')}: ${medicine.name}',
                                  body: '$amount ${S.text('notif_body')}',
                                  weekdays: medicine.weekdays,
                                  reminders: medicine.reminders ?? [],
                                );
                              }
                            }

                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${S.text('error')}: $e'),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isSaving = false);
                            }
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        height: 24.h,
                        width: 24.w,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isEditing ? S.text('update') : S.text('save'),
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
