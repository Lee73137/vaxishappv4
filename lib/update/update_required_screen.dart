import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../widgets/glossy_widgets.dart';

/// Full-screen, non-dismissible gate shown (iOS only — Android's equivalent
/// is Play's own native immediate-update UI, handled entirely inside
/// UpdateService) when the installed build is older than what's currently
/// published on the App Store.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.storeUrl});

  final String storeUrl;

  Future<void> _openStore() async {
    final uri = Uri.parse(storeUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.colors.scaffoldBackground,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/img/vaxishapplogo.png',
                  width: 96.w,
                  height: 96.w,
                ),
                SizedBox(height: 32.h),
                Text(
                  'Update Required',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'A new version of vaxishapp+ is available. Please update to keep using the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: context.colors.textSecondary,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 32.h),
                GlossyButton(label: 'Update Now', onPressed: _openStore),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
