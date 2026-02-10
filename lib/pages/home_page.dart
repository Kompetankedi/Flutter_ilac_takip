import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/medicine.dart';
import '../models/reminder_time.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

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
        title: const Text('Bildirim İzni Gerekli'),
        content: const Text(
          'İlaçlarınızı zamanında hatırlatabilmemiz için bildirim izni vermeniz gerekmektedir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Ayarları Aç'),
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
              title: const Text('Pil Tasarrufu Uyarısı'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Telefonunuzu yeniden başlattığınızda bildirimleri almaya devam etmek için şu iki ayar çok önemlidir:\n\n'
                    '1. **Otomatik Başlatma (Auto-start):** Uygulama bilgilerinden bu izni açın.\n'
                    '2. **Pil Kısıtlaması Yok (No restrictions):** Pil tasarrufu ayarlarından "Kısıtlama Yok" seçeneğini seçin.\n\n'
                    'Aksi takdirde telefonunuz kapandığında veya pil tasarrufu modunda bildirimler gelmeyebilir.',
                  ),
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
                      const Expanded(child: Text("Bir daha gösterme")),
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
                  child: const Text('Tamam'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (dontShowAgain) {
                      await StorageService.setBatteryWarningShown(true);
                    }
                    // Don't pop yet, let them go to settings
                    await NotificationService.openAutoStartSettings();
                  },
                  child: const Text('Otomatik Başlatmaya Git'),
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
                  child: const Text('Pil Ayarlarına Git'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _isTakenToday(Medicine medicine) {
    final now = DateTime.now();
    return medicine.log.any(
      (date) =>
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day,
    );
  }

  void _toggleTaken(Medicine medicine, bool? value) async {
    if (value == true) {
      medicine.log.add(DateTime.now());
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
            date.day == now.day,
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
          title: const Text('Silme Onayı'),
          content: Text(
            '${medicine.name} isimli ilacı silmek istediğinize emin misiniz?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sil'),
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
    final bool isEditing = medicineToEdit != null;
    final nameController = TextEditingController(
      text: isEditing ? medicineToEdit.name : '',
    );

    final List<ReminderTime> initialReminders = isEditing
        ? (medicineToEdit.reminders ??
              [
                ReminderTime(
                  hour: medicineToEdit.hour,
                  minute: medicineToEdit.minute,
                ),
              ])
        : [ReminderTime(hour: 9, minute: 0)];

    final List<int> initialWeekdays = isEditing
        ? (medicineToEdit.weekdays ?? [])
        : [];

    String initialAmount = '';
    String initialUnit = 'Tablet';

    if (isEditing) {
      final parts = medicineToEdit.amount.split(' ');
      if (parts.isNotEmpty) initialAmount = parts[0];
      if (parts.length > 1) initialUnit = parts.sublist(1).join(' ');
    }

    final amountController = TextEditingController(text: initialAmount);

    final List<String> dayNames = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        List<ReminderTime> reminders = List.from(initialReminders);
        List<int> selectedWeekdays = List.from(initialWeekdays);
        String selectedUnit = initialUnit;
        final List<String> units = [
          'Tablet',
          'mg',
          'ml',
          'Ölçek',
          'Damla',
          'Kapsül',
          'Poşet',
        ];

        if (!units.contains(selectedUnit)) {
          selectedUnit = 'Tablet';
        }

        return StatefulBuilder(
          builder: (context, setStateModal) {
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
                    isEditing ? "İlacı Düzenle" : "Yeni İlaç Ekle",
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
                      labelText: "İlaç Adı",
                      hintText: "Örn: Aspirin",
                      prefixIcon: Icon(
                        Icons.medication,
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
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Miktar",
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
                                if (value != null)
                                  setStateModal(() => selectedUnit = value);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(height: 24.h),
                  Text(
                    "Hatırlatma Günleri",
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[700],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Column(
                    children: [
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
                              setStateModal(() {
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
                              color: isSelected
                                  ? Colors.blue[700]
                                  : Colors.black87,
                              fontSize: 12.sp,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Hatırlatma Saatleri",
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[700],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setStateModal(() {
                            reminders.add(ReminderTime(hour: 9, minute: 0));
                          });
                        },
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text("Ekle"),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  ...reminders.asMap().entries.map((entry) {
                    final index = entry.key;
                    final time = entry.value;
                    final timeOfDay = TimeOfDay(
                      hour: time.hour,
                      minute: time.minute,
                    );
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: timeOfDay,
                          );
                          if (picked != null) {
                            setStateModal(() {
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
                              Icon(
                                Icons.access_time_filled,
                                color: Colors.blue[400],
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                "${index + 1}. Hatırlatma",
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
                                    setStateModal(() {
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
                      onPressed: () async {
                        if (nameController.text.isNotEmpty &&
                            amountController.text.isNotEmpty) {
                          try {
                            final amount =
                                "${amountController.text} $selectedUnit";
                            if (isEditing) {
                              // Update existing
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
                                title: 'İlaç Zamanı: ${medicineToEdit.name}',
                                body:
                                    '$amount miktarında ilacınızı almayı unutmayın.',
                                weekdays: medicineToEdit.weekdays,
                                reminders: medicineToEdit.reminders ?? [],
                              );
                            } else {
                              // Add new
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
                                  title: 'İlaç Zamanı: ${medicine.name}',
                                  body:
                                      '$amount miktarında ilacınızı almayı unutmayın.',
                                  weekdays: medicine.weekdays,
                                  reminders: medicine.reminders ?? [],
                                );
                              }
                            }

                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Hata: $e')),
                              );
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
                      child: Text(
                        isEditing ? "Güncelle" : "Kaydet",
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İlaç Takip'), centerTitle: true),
      body: ValueListenableBuilder<Box<Medicine>>(
        valueListenable: StorageService.getBox().listenable(),
        builder: (context, box, _) {
          final allMedicines = box.values.toList().cast<Medicine>();

          if (allMedicines.isEmpty) {
            return Center(
              child: Text(
                'Kayıtlı ilaç yok.',
                style: TextStyle(fontSize: 18.sp),
              ),
            );
          }

          final pending = allMedicines.where((m) => !_isTakenToday(m)).toList();
          final takenToday = allMedicines
              .where((m) => _isTakenToday(m))
              .toList();

          return ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              if (pending.isNotEmpty) ...[
                _buildSectionContainer(
                  title: "Bugünkü İlaçlar",
                  medicines: pending,
                  isTaken: false,
                ),
              ],
              if (takenToday.isNotEmpty) ...[
                SizedBox(height: 24.h),
                _buildSectionContainer(
                  title: "Tamamlananlar",
                  medicines: takenToday,
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
    required List<Medicine> medicines,
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
          ...medicines.map((m) => _buildMedicineCard(m, isTaken: isTaken)),
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

  Widget _buildMedicineCard(Medicine medicine, {bool isTaken = false}) {
    return Dismissible(
      key: Key(medicine.key.toString()),
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
                    // Show a quick undo snackbar or dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("İşaret kaldırıldı."),
                        duration: const Duration(seconds: 2),
                        action: SnackBarAction(
                          label: "Tamam",
                          onPressed: () {},
                        ),
                      ),
                    );
                    _toggleTaken(medicine, false);
                  }
                : null,
            leading: Transform.scale(
              scale: 1.2,
              child: Checkbox(
                value: isTaken,
                onChanged: isTaken
                    ? null
                    : (val) => _toggleTaken(medicine, val),
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
                Wrap(
                  spacing: 4.w,
                  children: [
                    ...(medicine.reminders ??
                            [
                              ReminderTime(
                                hour: medicine.hour,
                                minute: medicine.minute,
                              ),
                            ])
                        .map(
                          (t) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}",
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () =>
                      _showMedicineDialog(medicineToEdit: medicine),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteMedicine(medicine),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
