import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theme/app_colors.dart';
import '../../widgets/glossy_widgets.dart';

class ComingSoonTab extends StatelessWidget {
  const ComingSoonTab({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84.w,
              height: 84.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandRed.withValues(alpha: 0.08),
              ),
              child: Icon(icon, size: 38.sp, color: brandRed),
            ),
            SizedBox(height: 20.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Coming soon',
              style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
