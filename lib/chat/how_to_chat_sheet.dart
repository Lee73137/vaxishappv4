import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../widgets/glossy_widgets.dart';

/// Versioned so bumping this re-shows the sheet once to everyone, if the
/// chat screen's controls ever change enough to warrant it.
const _seenPrefsKey = 'chat_how_to_seen_v1';

Future<bool> hasSeenHowToChat() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_seenPrefsKey) ?? false;
}

Future<void> markHowToChatSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_seenPrefsKey, true);
}

/// Explains the two things nothing on the chat screen itself hints at
/// (long-press to unsend, the Facebook icon in the header) alongside the
/// two obvious ones, so a first-time user isn't left guessing. Shown once
/// automatically, and reachable again anytime via the header's help icon.
Future<void> showHowToChatSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _HowToChatSheet(),
  );
}

class _HowToChatSheet extends StatelessWidget {
  const _HowToChatSheet();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Container(
        margin: EdgeInsets.all(12.w),
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: brandRed.withValues(alpha: 0.1),
                  ),
                  child: Icon(Icons.chat_bubble_rounded, color: brandRed, size: 20.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'How to use Chat Support',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),
            const _HowToRow(
              icon: Icons.send_rounded,
              title: 'Send a message',
              description: 'Type below and tap send to reach our support team.',
            ),
            const _HowToRow(
              icon: Icons.attach_file_rounded,
              title: 'Attach a photo or file',
              description: 'Tap the paperclip to send a photo or document.',
            ),
            const _HowToRow(
              icon: Icons.touch_app_rounded,
              title: 'Unsend a message',
              description: 'Press and hold a message you sent to delete it.',
            ),
            const _HowToRow(
              icon: Icons.facebook_rounded,
              title: 'Prefer Facebook?',
              description: 'Tap the Facebook icon above to message us there instead.',
              isLast: true,
            ),
            SizedBox(height: 6.h),
            GlossyButton(
              label: 'Got it',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowToRow extends StatelessWidget {
  const _HowToRow({
    required this.icon,
    required this.title,
    required this.description,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 20.h : 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: brandRed, size: 20.sp),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  description,
                  style: TextStyle(fontSize: 12.sp, color: colors.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
