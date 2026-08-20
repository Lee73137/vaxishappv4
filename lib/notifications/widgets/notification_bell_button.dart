import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theme/app_colors.dart';
import '../../widgets/glossy_widgets.dart';
import '../data/notification_database.dart';
import '../notifications_page.dart';

/// Dashboard entry point into the notification inbox — a circular bell
/// button matching the profile icon's style, with a small unread-count
/// badge. Bound directly to [NotificationDatabase.unreadCountNotifier], so
/// the badge updates immediately when a push is persisted (foreground or
/// background) instead of only refreshing on app-resume or after returning
/// from the notifications list.
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  @override
  void initState() {
    super.initState();
    // Seeds the notifier with the real count on first build — it otherwise
    // defaults to 0 until something calls insert/markRead/etc.
    NotificationDatabase().refreshUnreadBadge();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: _openNotifications,
      borderRadius: BorderRadius.circular(23.w),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [brandRed, brandRedDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: brandRed.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.notifications_rounded, color: Colors.white, size: 22.sp),
          ),
          ValueListenableBuilder<int>(
            valueListenable: NotificationDatabase.unreadCountNotifier,
            builder: (context, unreadCount, _) {
              if (unreadCount <= 0) return const SizedBox.shrink();
              return Positioned(
                top: -2.h,
                right: -2.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                  constraints: BoxConstraints(minWidth: 18.w),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: brandRed, width: 1.4),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w800,
                      color: brandRed,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
