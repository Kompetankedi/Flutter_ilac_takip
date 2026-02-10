import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/storage_service.dart';
import 'onboarding_page.dart';

class LanguageSelectionPage extends StatelessWidget {
  const LanguageSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.language, size: 80.sp, color: const Color(0xFF2196F3)),
              SizedBox(height: 32.h),
              Text(
                'Lütfen Dil Seçin / Please Select Language',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 48.h),
              _buildLanguageButton(
                context,
                title: 'Türkçe',
                code: 'tr',
                flag: '🇹🇷',
              ),
              SizedBox(height: 16.h),
              _buildLanguageButton(
                context,
                title: 'English',
                code: 'en',
                flag: '🇺🇸',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageButton(
    BuildContext context, {
    required String title,
    required String code,
    required String flag,
  }) {
    return SizedBox(
      height: 64.h,
      child: ElevatedButton(
        onPressed: () async {
          await StorageService.setLanguageCode(code);
          if (context.mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const OnboardingPage()),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[50],
          foregroundColor: Colors.blue[800],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
            side: BorderSide(color: Colors.blue[200]!),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: TextStyle(fontSize: 24.sp)),
            SizedBox(width: 12.w),
            Text(
              title,
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
