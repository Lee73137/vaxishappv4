import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'services/notification/fcm_notification_service.dart';
import 'shop/providers/cart_provider.dart';
import 'shop/providers/item_provider.dart';
import 'splash_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme_data.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');
    // Requests notification permission, sets up the sound-enabled channel,
    // and registers the foreground/background/tap handlers.
    await FCMNotificationService.initialize();
  } catch (e) {
    debugPrint('❌ Error initializing Firebase/notifications: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // ScreenUtilInit scales sizes/fonts (via .w/.h/.sp) relative to this
    // design size, so layouts match across differently sized devices
    // instead of only looking right on the device they were built on.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ItemProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            builder: (context, child) {
              return MaterialApp(
                navigatorKey: FCMNotificationService.navigatorKey,
                scaffoldMessengerKey: FCMNotificationService.scaffoldMessengerKey,
                title: 'vaxishapp+',
                themeMode: themeController.themeMode,
                theme: buildAppTheme(AppColors.light, Brightness.light),
                darkTheme: buildAppTheme(AppColors.dark, Brightness.dark),
                // Profile > App Settings' font-size preference, applied on
                // top of ScreenUtil's own .sp scaling (which already reads
                // this ambient text scaler since minTextAdapt is on above).
                builder: (context, child) {
                  final mediaQuery = MediaQuery.of(context);
                  return MediaQuery(
                    data: mediaQuery.copyWith(
                      textScaler: TextScaler.linear(themeController.fontSize.scaleFactor),
                    ),
                    child: child!,
                  );
                },
                home: const SplashScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
