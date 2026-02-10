import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'pages/onboarding_page.dart';
import 'pages/main_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await StorageService.init();

  // Initialize Notifications
  await NotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Responsive design setup
    return ScreenUtilInit(
      designSize: const Size(375, 812), // iPhone X design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'İlaç Takip',
          theme: ThemeData(
            primaryColor: const Color(0xFF2196F3), // Azure Blue
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2196F3),
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          ),
          home: StorageService.isFirstRun()
              ? const OnboardingPage()
              : const MainPage(),
        );
      },
    );
  }
}
