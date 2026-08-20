import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../widgets/glossy_widgets.dart';

/// Fetches and displays the logged-in user's reward points balance. Reuses
/// the same `/api/userinfo` endpoint vaxishappv2.2 uses for its reward
/// points card. There's no redeem/claim endpoint on the backend yet, so
/// "Claim" just tells the user redemption is coming rather than pretending
/// to do something real.
class RewardPointsCard extends StatefulWidget {
  const RewardPointsCard({super.key, required this.username});

  final String? username;

  @override
  State<RewardPointsCard> createState() => _RewardPointsCardState();
}

class _RewardPointsCardState extends State<RewardPointsCard> {
  static const _baseUrl = 'http://shopapi.vaxilifecorp.com';

  int? _points;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    final username = widget.username;
    if (username == null || username.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl/api/userinfo?empname=${Uri.encodeComponent(username)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final normalized = {
          for (final key in data.keys) key.toLowerCase(): data[key],
        };
        final rawPoints = normalized['points'];
        final points = rawPoints is int
            ? rawPoints
            : int.tryParse('$rawPoints') ?? 0;

        if (mounted) {
          setState(() {
            _points = points;
            _loading = false;
          });
        }
        return;
      }
    } catch (_) {
      // Points are a nice-to-have display, not critical — if this fails,
      // just hide the card instead of showing a broken/empty state.
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Rewards redemption is coming soon!'),
        backgroundColor: brandRedDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (_loading) {
      return Container(
        width: double.infinity,
        height: 92.h,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: colors.divider),
        ),
        alignment: Alignment.center,
        child: SizedBox(
          width: 22.w,
          height: 22.w,
          child: const CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(brandRed),
          ),
        ),
      );
    }

    if (_points == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.surface.withValues(alpha: 0.55),
                brandRed.withValues(alpha: 0.42),
              ],
            ),
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: brandRed.withValues(alpha: 0.1),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: brandRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.stars_rounded, color: brandRed, size: 28.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REWARD POINTS',
                      style: TextStyle(
                        color: brandRed.withValues(alpha: 0.75),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          NumberFormat('#,##0', 'en_US').format(_points),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 26.sp,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Padding(
                          padding: EdgeInsets.only(bottom: 3.h),
                          child: Text(
                            'pts',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Redeem for exclusive deals!',
                      style: TextStyle(fontSize: 10.5.sp, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              InkWell(
                onTap: _showComingSoon,
                borderRadius: BorderRadius.circular(30.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [brandRed, brandRedDark],
                    ),
                    borderRadius: BorderRadius.circular(30.r),
                    boxShadow: [
                      BoxShadow(
                        color: brandRed.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Claim',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5.sp,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 14.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
