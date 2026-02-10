import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/medicine.dart';
import '../services/storage_service.dart';

class SeriesPage extends StatelessWidget {
  const SeriesPage({super.key});

  int _calculateCurrentStreak(List<Medicine> medicines) {
    if (medicines.isEmpty) return 0;

    int streak = 0;
    DateTime date = DateTime.now();

    while (true) {
      final dayMatches = medicines.every((m) {
        if (!m.isActive) return true;
        return m.log.any(
          (logDate) =>
              logDate.year == date.year &&
              logDate.month == date.month &&
              logDate.day == date.day,
        );
      });

      if (dayMatches) {
        streak++;
        date = date.subtract(const Duration(days: 1));
      } else {
        // If today is not finished yet, don't break the streak if it was matched yesterday
        if (streak == 0 && date.day == DateTime.now().day) {
          date = date.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
    }
    return streak;
  }

  List<double> _getWeeklyData(List<Medicine> medicines) {
    List<double> data = [];
    DateTime now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      DateTime date = now.subtract(Duration(days: i));
      int totalScheduled = 0;
      int totalTaken = 0;

      for (var m in medicines) {
        if (!m.isActive) continue;
        totalScheduled++;
        if (m.log.any(
          (logDate) =>
              logDate.year == date.year &&
              logDate.month == date.month &&
              logDate.day == date.day,
        )) {
          totalTaken++;
        }
      }

      if (totalScheduled == 0) {
        data.add(0);
      } else {
        data.add((totalTaken / totalScheduled) * 100);
      }
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İstatistiklerim'), centerTitle: true),
      body: ValueListenableBuilder<Box<Medicine>>(
        valueListenable: StorageService.getBox().listenable(),
        builder: (context, box, _) {
          final medicines = box.values.toList().cast<Medicine>();
          if (medicines.isEmpty) {
            return Center(
              child: Text(
                'Henüz veri bulunmuyor.',
                style: TextStyle(fontSize: 16.sp, color: Colors.grey),
              ),
            );
          }

          final streak = _calculateCurrentStreak(medicines);
          final weeklyData = _getWeeklyData(medicines);

          return SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStreakCard(streak),
                SizedBox(height: 32.h),
                Text(
                  'Haftalık Uyum (%)',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
                ),
                SizedBox(height: 16.h),
                _buildChart(weeklyData),
                SizedBox(height: 32.h),
                _buildSummaryText(medicines),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStreakCard(int streak) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.local_fire_department, color: Colors.orange, size: 64.sp),
          SizedBox(height: 8.h),
          Text(
            '$streak Gün',
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'Kesintisiz Seri',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<double> data) {
    return Container(
      height: 220.h,
      padding: EdgeInsets.only(right: 16.w, top: 16.h),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const days = [
                    'Pzt',
                    'Sal',
                    'Çar',
                    'Per',
                    'Cum',
                    'Cmt',
                    'Paz',
                  ];
                  // Simple logic to show day labels correctly relative to today
                  DateTime now = DateTime.now();
                  DateTime date = now.subtract(
                    Duration(days: 6 - value.toInt()),
                  );
                  int weekdayIndex = date.weekday - 1;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      days[weekdayIndex],
                      style: TextStyle(fontSize: 10.sp),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                reservedSize: 30.w,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}',
                    style: TextStyle(fontSize: 10.sp),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(data.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i],
                  color: const Color(0xFF2196F3),
                  width: 16.w,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSummaryText(List<Medicine> medicines) {
    int activeCount = medicines.where((m) => m.isActive).length;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Şu anda $activeCount aktif ilacınız bulunuyor. Serinizi korumak için her gün tüm ilaçlarınızı içmeyi unutmayın!',
              style: TextStyle(fontSize: 14.sp, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
