import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../login/login_page.dart';
import '../../notifications/data/notification_database.dart';
import '../../services/auth_service.dart';
import '../../shop/providers/cart_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../../utils/fcm/fcm_token_service.dart';
import '../../widgets/glossy_widgets.dart';
import '../widgets/reward_points_card.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, this.user});

  final UserSession? user;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Log out',
              style: TextStyle(color: brandRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final username = user?.username;

    await AuthService.logout();
    // Local notification history isn't scoped per-user — on a shared device,
    // leaving it would let the next person who logs in see this user's
    // message previews (including chat replies). Clearing it here is
    // simpler and safer than retrofitting per-user scoping.
    await NotificationDatabase().clearAll();
    if (username != null && username.isNotEmpty) {
      // Best-effort, not awaited on the UI — deactivates this device's FCM
      // token server-side so pushes (chat replies, alerts, etc.) stop
      // arriving for this account once logged out. A slow/failed network
      // call here shouldn't hold up logout itself.
      FcmTokenService().removeToken(username);
    }

    if (!context.mounted) return;
    context.read<CartProvider>().resetUser();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _pickThemeMode(BuildContext context, ThemeController controller) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _OptionSheet<ThemeMode>(
        title: 'Theme',
        options: ThemeMode.values,
        labelOf: (mode) => mode.label,
        iconOf: (mode) => switch (mode) {
          ThemeMode.light => Icons.light_mode_outlined,
          ThemeMode.dark => Icons.dark_mode_outlined,
          ThemeMode.system => Icons.smartphone_outlined,
        },
        current: controller.themeMode,
      ),
    );
    if (selected != null) {
      await controller.setThemeMode(selected);
    }
  }

  Future<void> _pickFontSize(BuildContext context, ThemeController controller) async {
    final selected = await showModalBottomSheet<AppFontSize>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _OptionSheet<AppFontSize>(
        title: 'Font Size',
        options: AppFontSize.values,
        labelOf: (size) => size.label,
        iconOf: (_) => Icons.text_fields_rounded,
        current: controller.fontSize,
      ),
    );
    if (selected != null) {
      await controller.setFontSize(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final themeController = context.watch<ThemeController>();
    final displayName = user?.fullname?.trim().isNotEmpty == true
        ? user!.fullname!.trim()
        : (user?.username ?? 'User');

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [brandRed, brandRedDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: brandRed.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(Icons.person, color: Colors.white, size: 32.sp),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 19.sp,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '@${user?.username ?? ''}',
                        style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            RewardPointsCard(username: user?.username),
            SizedBox(height: 28.h),
            Text(
              'Account',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.surface.withValues(alpha: 0.6),
                    brandRed.withValues(alpha: 0.32),
                  ],
                ),
                borderRadius: BorderRadius.circular(18.r),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: (user?.email.isNotEmpty ?? false)
                        ? maskEmail(user!.email)
                        : '-',
                  ),
                  Divider(height: 22.h, color: colors.divider),
                  _InfoRow(
                    icon: Icons.badge_outlined,
                    label: 'Username',
                    value: user?.username ?? '-',
                  ),
                  if ((user?.repcode ?? '').isNotEmpty) ...[
                    Divider(height: 22.h, color: colors.divider),
                    _InfoRow(
                      icon: Icons.qr_code_2_rounded,
                      label: 'Rep Code',
                      value: user!.repcode!,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 28.h),
            // Device/app preferences — deliberately separate from the
            // account-info card above, since these affect how the app looks
            // on this device rather than data tied to the vaxishapp account.
            Text(
              'App Settings',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18.r),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _SettingRow(
                    icon: Icons.palette_outlined,
                    label: 'Theme',
                    value: themeController.themeMode.label,
                    onTap: () => _pickThemeMode(context, themeController),
                  ),
                  Divider(height: 1.h, color: colors.divider),
                  _SettingRow(
                    icon: Icons.text_fields_rounded,
                    label: 'Font Size',
                    value: themeController.fontSize.label,
                    onTap: () => _pickFontSize(context, themeController),
                  ),
                ],
              ),
            ),
            SizedBox(height: 28.h),
            GlossyButton(label: 'Log Out', onPressed: () => _confirmLogout(context)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, color: brandRed, size: 18.sp),
        SizedBox(width: 10.w),
        Text(label, style: TextStyle(fontSize: 13.sp, color: colors.textSecondary)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, color: brandRed, size: 18.sp),
            SizedBox(width: 10.w),
            Text(label, style: TextStyle(fontSize: 13.sp, color: colors.textPrimary)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
            ),
            SizedBox(width: 4.w),
            Icon(Icons.chevron_right_rounded, color: colors.iconInactive, size: 18.sp),
          ],
        ),
      ),
    );
  }
}

class _OptionSheet<T> extends StatelessWidget {
  const _OptionSheet({
    required this.title,
    required this.options,
    required this.labelOf,
    required this.iconOf,
    required this.current,
  });

  final String title;
  final List<T> options;
  final String Function(T) labelOf;
  final IconData Function(T) iconOf;
  final T current;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Container(
        margin: EdgeInsets.all(12.w),
        padding: EdgeInsets.symmetric(vertical: 6.h),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 4.h),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
            for (final option in options)
              ListTile(
                leading: Icon(iconOf(option), color: brandRed),
                title: Text(
                  labelOf(option),
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
                trailing: option == current
                    ? Icon(Icons.check_rounded, color: brandRed, size: 20.sp)
                    : null,
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
  }
}
