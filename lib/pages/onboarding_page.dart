import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/medicine.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'main_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(); // Now only for numbers
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  String _selectedUnit = 'Tablet';
  final List<String> _units = [
    'Tablet',
    'mg',
    'ml',
    'Ölçek',
    'Damla',
    'Kapsül',
    'Poşet',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      try {
        final amount = "${_amountController.text} $_selectedUnit";
        final medicine = Medicine(
          name: _nameController.text,
          amount: amount,
          hour: _selectedTime.hour,
          minute: _selectedTime.minute,
        );

        await StorageService.addMedicine(medicine);

        if (medicine.isInBox) {
          await NotificationService.scheduleDailyNotification(
            id: medicine.key as int,
            title: 'İlaç Zamanı: ${medicine.name}',
            body: '$amount miktarında ilacınızı almayı unutmayın.',
            hour: medicine.hour,
            minute: medicine.minute,
          );
        }

        await StorageService.setFirstRunCompleted();

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainPage()),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Bir hata oluştu: $e')));
        }
      }
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 40.h),
                Text(
                  'Hoşgeldiniz',
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  'Lütfen takip edilecek ilk ilacınızı girin.',
                  style: TextStyle(fontSize: 16.sp, color: Colors.grey[700]),
                ),
                SizedBox(height: 40.h),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'İlaç Adı',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medication),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Lütfen ilaç adı girin'
                      : null,
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Miktar',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Gerekli' : null,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: const InputDecoration(
                          labelText: 'Birim',
                          border: OutlineInputBorder(),
                        ),
                        items: _units.map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(unit),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedUnit = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                InkWell(
                  onTap: _pickTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Hatırlatma Saati',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.alarm),
                    ),
                    child: Text(
                      _selectedTime.format(context),
                      style: TextStyle(fontSize: 16.sp),
                    ),
                  ),
                ),
                SizedBox(height: 60.h),
                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Text(
                      'Kaydet ve Başla',
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
        ),
      ),
    );
  }
}
