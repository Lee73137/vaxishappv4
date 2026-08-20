import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../widgets/glossy_widgets.dart';

class AnnouncementItem {
  const AnnouncementItem({
    required this.title,
    required this.message,
    required this.date,
  });

  final String title;
  final String message;
  final DateTime? date;

  factory AnnouncementItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final rawDate = json['DateAnnounce']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate);
    }

    return AnnouncementItem(
      title: json['Title']?.toString() ?? 'Announcement',
      message: json['Message']?.toString() ?? '',
      date: parsedDate,
    );
  }
}

class AnnouncementsSection extends StatefulWidget {
  const AnnouncementsSection({super.key});

  @override
  State<AnnouncementsSection> createState() => _AnnouncementsSectionState();
}

class _AnnouncementsSectionState extends State<AnnouncementsSection> {
  static const _baseUrl = 'http://shopapi.vaxilifecorp.com';

  bool _isLoading = true;
  List<AnnouncementItem> _announcements = [];

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/appannouncement'))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _announcements = data
              .map((item) => AnnouncementItem.fromJson(item))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _announcements = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _announcements = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Announcements',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        if (_isLoading)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: SizedBox(
                width: 22.w,
                height: 22.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(brandRed),
                ),
              ),
            ),
          )
        else if (_announcements.isEmpty)
          _EmptyAnnouncementCard(onTap: () => _showEmptyDialog(context))
        else
          ...List.generate(_announcements.length, (index) {
            final announcement = _announcements[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _announcements.length - 1 ? 0 : 10.h,
              ),
              child: _AnnouncementCard(
                announcement: announcement,
                onTap: () => _showDetailsDialog(context, announcement),
              ),
            );
          }),
      ],
    );
  }

  void _showDetailsDialog(BuildContext context, AnnouncementItem announcement) {
    showDialog(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Row(
            children: [
              Icon(Icons.campaign_outlined, color: brandRed, size: 24.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  announcement.title,
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    announcement.message.isEmpty
                        ? 'No message available'
                        : announcement.message,
                    style: TextStyle(fontSize: 15.sp, height: 1.5),
                  ),
                ),
                if (announcement.date != null) ...[
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 15.sp,
                        color: colors.iconInactive,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        DateFormat('MMMM dd, yyyy').format(announcement.date!),
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, size: 18.sp),
              label: const Text('Close'),
              style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
            ),
          ],
        );
      },
    );
  }

  void _showEmptyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Row(
            children: [
              Icon(Icons.notifications_off_outlined, color: colors.iconInactive, size: 24.sp),
              SizedBox(width: 8.w),
              Text(
                'No Announcements',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_none,
                  size: 44.sp,
                  color: colors.iconInactive,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'There are no announcements at the moment.\nCheck back later for updates and news.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.sp, color: colors.textSecondary, height: 1.5),
              ),
            ],
          ),
          actions: [
            Center(
              child: GlossyButton(
                label: 'Got It',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement, required this.onTap});

  final AnnouncementItem announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: colors.divider),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: brandRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.campaign_outlined, color: brandRed, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.5.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      announcement.message.isEmpty
                          ? 'No message available'
                          : announcement.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5.sp, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (announcement.date != null) ...[
                SizedBox(width: 8.w),
                Text(
                  DateFormat('MMM d').format(announcement.date!),
                  style: TextStyle(fontSize: 11.sp, color: colors.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyAnnouncementCard extends StatelessWidget {
  const _EmptyAnnouncementCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: colors.divider),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_none,
                  color: colors.iconInactive,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  'No announcements yet',
                  style: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14.sp, color: colors.iconInactive),
            ],
          ),
        ),
      ),
    );
  }
}
