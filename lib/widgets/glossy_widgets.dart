import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';

const brandRed = Color(0xFFD32F2F);
const brandRedDark = Color(0xFF8E0000);

final _pesoFormat = NumberFormat('#,##0.00', 'en_US');

/// Formats a peso amount with thousands separators, e.g. 1350.0 -> "1,350.00".
String formatPeso(double amount) => _pesoFormat.format(amount);

/// Masks the local part of an email for display, e.g.
/// "leieljohn@yahoo.com" -> "l*******n@yahoo.com". Mirrors the backend's
/// MaskEmail used for the forgot-password preview, so masking looks
/// consistent everywhere in the app.
String maskEmail(String email) {
  final atIndex = email.indexOf('@');
  if (atIndex <= 0) return email;

  final localPart = email.substring(0, atIndex);
  final domainPart = email.substring(atIndex);

  if (localPart.length <= 2) {
    return '${localPart[0]}*$domainPart';
  }

  final masked =
      localPart[0] +
      '*' * (localPart.length - 2) +
      localPart[localPart.length - 1];
  return masked + domainPart;
}

Widget glowBlob(double size, Color color) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}

Widget buildAuthTextField({
  required BuildContext context,
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  bool obscureText = false,
  TextInputType? keyboardType,
  Widget? suffixIcon,
  ValueChanged<String>? onChanged,
  List<TextInputFormatter>? inputFormatters,
}) {
  final colors = context.colors;
  return TextField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    onChanged: onChanged,
    inputFormatters: inputFormatters,
    style: TextStyle(fontSize: 14.sp, color: colors.textPrimary),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14.sp),
      prefixIcon: Icon(icon, color: brandRed, size: 20.sp),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colors.surface.withValues(alpha: 0.7),
      contentPadding: EdgeInsets.symmetric(vertical: 14.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: colors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: brandRed, width: 1.4),
      ),
    ),
  );
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.all(22.w),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: colors.divider),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Diagonal corner ribbon flagging an item with tier/bulk pricing. Must be
/// used as a direct child of a [Stack] (it positions itself). The parent
/// Stack should clip to the card's shape so the ribbon's overhang is cut
/// off cleanly at the corner.
class TierRibbon extends StatelessWidget {
  const TierRibbon({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 128.w : 150.w;
    final fontSize = compact ? 7.5.sp : 10.sp;

    return Positioned(
      top: compact ? 11.h : 16.h,
      // The left endpoint of the rotated strip must clear the card's left
      // edge by a comfortable margin (not just barely past 0), or its flat
      // end-cap stays partly visible instead of being cleanly clipped off.
      left: compact ? -38.w : -40.w,
      child: Transform.rotate(
        angle: -0.7853981633974483, // -45 degrees
        child: Container(
          width: width,
          height: compact ? 22.h : 28.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [brandRed, brandRedDark]),
            boxShadow: [
              BoxShadow(color: context.colors.shadow.withValues(alpha: 0.26), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: compact
              ? Text(
                  'BULK DEALS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    height: 1,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_offer_rounded, color: Colors.white, size: 11.sp),
                    SizedBox(width: 4.w),
                    Text(
                      'BULK DEALS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        height: 1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class GlossyButton extends StatelessWidget {
  const GlossyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [brandRed, brandRedDark],
          ),
          boxShadow: [
            BoxShadow(
              color: brandRed.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14.r),
            onTap: isLoading ? null : onPressed,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
