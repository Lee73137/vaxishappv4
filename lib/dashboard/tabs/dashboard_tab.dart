import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../notifications/widgets/notification_bell_button.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glossy_widgets.dart';
import '../widgets/announcements_section.dart';
import '../widgets/overdue_invoice_alert.dart';
import '../widgets/promo_carousel.dart';
import '../widgets/reward_points_card.dart';
import '../widgets/scheduled_delivery_alert.dart';
import '../widgets/verse_of_the_day_card.dart';
import '../widgets/videos_section.dart';

/// Philippine time is fixed at UTC+8 (no DST), computed explicitly so the
/// greeting is correct regardless of what timezone the device itself is set to.
String _greetingForManilaTime() {
  final manilaHour = DateTime.now().toUtc().add(const Duration(hours: 8)).hour;
  if (manilaHour < 12) return 'Good morning';
  if (manilaHour < 18) return 'Good afternoon';
  return 'Good evening';
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({
    super.key,
    this.user,
    this.onProfileTap,
    this.onInvoicesTap,
  });

  final UserSession? user;
  final VoidCallback? onProfileTap;
  final VoidCallback? onInvoicesTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final displayName = user?.fullname?.trim().isNotEmpty == true
        ? user!.fullname!.trim()
        : (user?.username ?? 'there');
    final clinicName = user?.fullname?.trim().isNotEmpty == true
        ? user!.fullname!.trim()
        : user?.username;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: 16.h, bottom: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_greetingForManilaTime()},',
                          style: TextStyle(
                            fontSize: 13.5.sp,
                            color: colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 21.sp,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  const NotificationBellButton(),
                  SizedBox(width: 10.w),
                  InkWell(
                    onTap: onProfileTap,
                    borderRadius: BorderRadius.circular(23.w),
                    child: Container(
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
                      child: Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 24.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: OverdueInvoiceAlert(
                username: user?.username,
                onTap: onInvoicesTap ?? () {},
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: ScheduledDeliveryAlert(clinicName: clinicName),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: RewardPointsCard(username: user?.username),
            ),
            SizedBox(height: 24.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                'Promos & Events',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            SizedBox(height: 12.h),
            const PromoCarousel(),
            SizedBox(height: 20.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: const VerseOfTheDayCard(),
            ),
            SizedBox(height: 24.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: const AnnouncementsSection(),
            ),
            SizedBox(height: 24.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: const VideosSection(),
            ),
          ],
        ),
      ),
    );
  }
}
