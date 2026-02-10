import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/medicine.dart';
import '../models/reminder_time.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/l10n_service.dart';
import 'main_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  final List<ReminderTime> _reminders = [ReminderTime(hour: 9, minute: 0)];
  List<int> _selectedWeekdays = []; // Empty means all days

  final List<String> _dayNames = S.dayNames;

  String _selectedUnit = S.units.first;
  final List<String> _units = S.units;

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
          weekdays: _selectedWeekdays,
          reminders: _reminders,
        );

        await StorageService.addMedicine(medicine);

        if (medicine.isInBox) {
          await NotificationService.scheduleMedicineReminders(
            id: medicine.key as int,
            title: '${S.text('medicine_time_notif')}: ${medicine.name}',
            body: '$amount ${S.text('notif_body')}',
            weekdays: medicine.weekdays,
            reminders: medicine.reminders ?? [],
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
          ).showSnackBar(SnackBar(content: Text('${S.text('error')}: $e')));
        }
      }
    }
  }

  Future<void> _skip() async {
    await StorageService.setFirstRunCompleted();
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainPage()));
    }
  }

  Future<void> _pickTime(int index) async {
    final initialTime = TimeOfDay(
      hour: _reminders[index].hour,
      minute: _reminders[index].minute,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        _reminders[index] = ReminderTime(
          hour: picked.hour,
          minute: picked.minute,
        );
      });
    }
  }

  void _addReminder() {
    setState(() {
      _reminders.add(ReminderTime(hour: 9, minute: 0));
    });
  }

  void _removeReminder(int index) {
    if (_reminders.length > 1) {
      setState(() {
        _reminders.removeAt(index);
      });
    }
  }

  void _toggleWeekday(int day) {
    setState(() {
      if (_selectedWeekdays.contains(day)) {
        _selectedWeekdays.remove(day);
      } else {
        _selectedWeekdays.add(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _skip,
            icon: const Icon(Icons.close, color: Colors.blueGrey),
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  S.text('welcome'),
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2196F3),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  S.text('welcome_subtitle'),
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.blueGrey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),
                TextFormField(
                  controller: _nameController,
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
                  validator: (value) => value == null || value.isEmpty
                      ? S.text('enter_medicine_name')
                      : null,
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _amountController,
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
                        validator: (value) => value == null || value.isEmpty
                            ? S.text('required_field')
                            : null,
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
                          child: DropdownButtonFormField<String>(
                            value: _selectedUnit,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.blue[400],
                            ),
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
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
                _buildWeekdaySelector(),
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
                      onPressed: _addReminder,
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(S.text('add')),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                  ],
                ),
                ..._reminders.asMap().entries.map(
                  (entry) => _buildTimePicker(entry.key, entry.value),
                ),
                SizedBox(height: 48.h),
                SizedBox(
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    child: Text(
                      S.text('save_and_start'),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                TextButton(
                  onPressed: _skip,
                  child: Text(
                    S.text('skip_onboarding'),
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.blueGrey[600],
                      decoration: TextDecoration.underline,
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

  Widget _buildWeekdaySelector() {
    return Column(
      children: [
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: List.generate(7, (index) {
            final day = index + 1;
            final isSelected = _selectedWeekdays.contains(day);
            return FilterChip(
              label: Text(_dayNames[index]),
              selected: isSelected,
              onSelected: (val) => _toggleWeekday(day),
              selectedColor: Colors.blue[100],
              checkmarkColor: Colors.blue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue[700] : Colors.black87,
                fontSize: 12.sp,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTimePicker(int index, ReminderTime time) {
    final timeOfDay = TimeOfDay(hour: time.hour, minute: time.minute);
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: InkWell(
        onTap: () => _pickTime(index),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
                style: TextStyle(fontSize: 16.sp, color: Colors.black54),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
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
              if (_reminders.length > 1)
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red,
                  ),
                  onPressed: () => _removeReminder(index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
