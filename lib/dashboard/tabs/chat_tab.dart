import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../widgets/glossy_widgets.dart';

/// Messenger username/link to chat with — update here if it ever changes.
const String _messengerUsername = 'meieljohnkyle';

class ChatTab extends StatelessWidget {
  const ChatTab({super.key});

  Future<void> _openMessenger(BuildContext context) async {
    final uri = Uri.parse('https://www.messenger.com/t/$_messengerUsername');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Messenger.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [brandRed, brandRedDark]),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 18.h),
                Text(
                  'Need help?',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Chat with us on Messenger for questions about orders, '
                  'products, or your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 22.h),
                GlossyButton(
                  label: 'Chat with us',
                  onPressed: () => _openMessenger(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
