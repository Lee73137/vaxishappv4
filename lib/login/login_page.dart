import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'forgot_password_page.dart';
import '../dashboard/dashboard_shell.dart';
import '../services/auth_service.dart';
import '../services/location/location_service.dart';
import '../services/notification/fcm_notification_service.dart';
import '../shop/providers/cart_provider.dart';
import '../theme/app_colors.dart';
import '../utils/fcm/fcm_token_service.dart';
import '../widgets/glossy_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your username and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.login(username, password);

    if (!mounted) return;

    if (result.success) {
      if (_rememberMe && result.user != null) {
        await AuthService.saveSession(result.user!);
      }

      // Fire-and-forget: register this device's FCM token against the
      // account so the server can push notifications to it. Not critical
      // to the login flow, so it shouldn't delay navigation.
      unawaited(_syncFcmToken(username));

      // Fire-and-forget: a GPS fix can take several seconds, so this
      // shouldn't hold up navigation either.
      unawaited(LocationService().captureAndSaveLocation(username));

      if (!mounted) return;
      // Awaited: this is just a local SQLite read, so it's fast — worth
      // waiting for so the cart badge/contents are ready the moment the
      // dashboard renders, instead of flashing empty first.
      await context.read<CartProvider>().loadForUser(username);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardShell(user: result.user),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = result.message;
    });
  }

  Future<void> _syncFcmToken(String username) async {
    try {
      final token = await FCMNotificationService.getToken();
      if (token != null && token.isNotEmpty) {
        await FcmTokenService().updateToken(username, token);
      }
    } catch (e) {
      debugPrint('❌ Error syncing FCM token after login: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Soft red glow blobs for a glossy, ambient background feel.
          Positioned(
            top: -80.w,
            right: -60.w,
            child: glowBlob(220.w, brandRed.withValues(alpha: 0.35)),
          ),
          Positioned(
            bottom: -100.w,
            left: -80.w,
            child: glowBlob(260.w, brandRedDark.withValues(alpha: 0.25)),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 28.w,
                    vertical: 24.h,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 24.h),
                          Image.asset(
                            'assets/img/vaxishapplogo.png',
                            width: 88.w,
                            height: 88.w,
                          ),
                          SizedBox(height: 20.h),
                          Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'Sign in to continue',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: colors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 32.h),
                          GlassCard(
                            child: Column(
                              children: [
                                if (_errorMessage != null) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 10.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? brandRed.withValues(alpha: 0.22)
                                          : const Color(0xFFFDECEA).withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(
                                        10.r,
                                      ),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFFB71C1C),
                                        fontSize: 12.5.sp,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 14.h),
                                ],
                                buildAuthTextField(
                                  context: context,
                                  controller: _usernameController,
                                  hint: 'Username',
                                  icon: Icons.person_outline_rounded,
                                  keyboardType: TextInputType.text,
                                  // Login uses a username, not an email — @
                                  // is never valid here.
                                  inputFormatters: [
                                    FilteringTextInputFormatter.deny('@'),
                                  ],
                                ),
                                SizedBox(height: 16.h),
                                buildAuthTextField(
                                  context: context,
                                  controller: _passwordController,
                                  hint: 'Password',
                                  icon: Icons.lock_outline,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: colors.textSecondary,
                                      size: 20.sp,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 22.w,
                                          height: 22.w,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            activeColor: brandRed,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            onChanged: (value) => setState(
                                              () =>
                                                  _rememberMe = value ?? false,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          'Remember me',
                                          style: TextStyle(
                                            fontSize: 12.5.sp,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: _isLoading
                                          ? null
                                          : () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const ForgotPasswordPage(),
                                                ),
                                              );
                                            },
                                      child: Text(
                                        'Forgot password?',
                                        style: TextStyle(
                                          fontSize: 12.5.sp,
                                          fontWeight: FontWeight.w600,
                                          color: brandRed,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 24.h),
                                GlossyButton(
                                  label: 'Login',
                                  isLoading: _isLoading,
                                  onPressed: _login,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
