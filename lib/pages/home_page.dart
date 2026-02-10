import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/medicine.dart';
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
                    'Özellikle Xiaomi, Huawei gibi cihazlarda "Pil Tasarrufu" veya "Otomatik Başlatma" ayarları bildirimlerin gelmesini engelleyebilir.\n\nLütfen uygulamanın ayarlarından pil kısıtlamalarını kaldırın ve otomatik başlatmaya izin verin.',
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
                    if (context.mounted) Navigator.pop(context);
                    // Open settings (best effort)
                    // AwesomeNotifications().showNotificationConfigPage(); // or similar
                    openAppSettings();
                  },
                  child: const Text('Ayarlara Git'),
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
        await NotificationService.cancelNotification(medicine.key as int);
      }
      await StorageService.deleteMedicine(medicine);
    }
  }

  void _showMedicineDialog({Medicine? medicineToEdit}) {
    final bool isEditing = medicineToEdit != null;
    final nameController = TextEditingController(
      text: isEditing ? medicineToEdit.name : '',
    );

    String initialAmount = '';
    String initialUnit = 'Tablet';

    if (isEditing) {
      // Assuming format "Amount Unit"
      final parts = medicineToEdit.amount.split(' ');
      if (parts.isNotEmpty) initialAmount = parts[0];
      if (parts.length > 1) initialUnit = parts.sublist(1).join(' ');
    }

    final amountController = TextEditingController(text: initialAmount);
    TimeOfDay selectedTime = isEditing
        ? TimeOfDay(hour: medicineToEdit.hour, minute: medicineToEdit.minute)
        : TimeOfDay.now();

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
      if (units.any((u) => u == selectedUnit)) {
      } else {
        selectedUnit = 'Tablet';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null)
                        setStateModal(() => selectedTime = picked);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 16.h,
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
                          Expanded(
                            child: Text(
                              "Hatırlatma Saati",
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              selectedTime.format(context),
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2196F3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                              medicineToEdit.hour = selectedTime.hour;
                              medicineToEdit.minute = selectedTime.minute;
                              await medicineToEdit.save();

                              await NotificationService.cancelNotification(
                                medicineToEdit.key as int,
                              );
                              await NotificationService.scheduleDailyNotification(
                                id: medicineToEdit.key as int,
                                title: 'İlaç Zamanı: ${medicineToEdit.name}',
                                body:
                                    '$amount miktarında ilacınızı almayı unutmayın.',
                                hour: medicineToEdit.hour,
                                minute: medicineToEdit.minute,
                              );
                            } else {
                              // Add new
                              final medicine = Medicine(
                                name: nameController.text,
                                amount: amount,
                                hour: selectedTime.hour,
                                minute: selectedTime.minute,
                              );
                              await StorageService.addMedicine(medicine);
                              if (medicine.isInBox) {
                                await NotificationService.scheduleDailyNotification(
                                  id: medicine.key as int,
                                  title: 'İlaç Zamanı: ${medicine.name}',
                                  body:
                                      '$amount miktarında ilacınızı almayı unutmayın.',
                                  hour: medicine.hour,
                                  minute: medicine.minute,
                                );
                              }
                            }

                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('Hata: $e')));
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
                _buildSectionHeader("Bugünkü İlaçlar"),
                ...pending.map((m) => _buildMedicineCard(m)),
              ],
              if (takenToday.isNotEmpty) ...[
                SizedBox(height: 24.h),
                _buildSectionHeader("Tamamlananlar"),
                ...takenToday.map((m) => _buildMedicineCard(m, isTaken: true)),
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
    final timeStr =
        "${medicine.hour.toString().padLeft(2, '0')}:${medicine.minute.toString().padLeft(2, '0')}";

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
          margin: EdgeInsets.symmetric(vertical: 8.h),
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
            subtitle: Text(
              "${medicine.amount} - $timeStr",
              style: TextStyle(fontSize: 14.sp),
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
