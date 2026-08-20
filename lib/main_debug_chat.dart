// TEMPORARY debug harness to visually verify the keyboard/attachment-sheet
// fix in chat/live_chat_page.dart without going through login. Not part of
// the app — delete after verification.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'chat/live_chat_page.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _DebugApp());
}

class _DebugApp extends StatelessWidget {
  const _DebugApp();

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'debug',
          theme: buildAppTheme(AppColors.light, Brightness.light),
          home: const LiveChatPage(),
        );
      },
    );
  }
}
