import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glossy_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _linkSent = false;
  String? _maskedEmail;
  Timer? _debounce;
  int _lookupSeq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    if (_maskedEmail != null) {
      setState(() => _maskedEmail = null);
    }

    final username = value.trim();
    if (username.isEmpty) return;

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final seq = ++_lookupSeq;
      final maskedEmail = await AuthService.lookupMaskedEmail(username);
      if (!mounted || seq != _lookupSeq) return;
      setState(() => _maskedEmail = maskedEmail);
    });
  }

  Future<void> _sendResetLink() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Please enter your username.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.forgotPassword(username);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success) {
        _linkSent = true;
      } else {
        _errorMessage = result.message;
      }
    });
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
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 4.h,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: colors.textPrimary,
                          size: 22.sp,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 28.w),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/img/vaxishapplogo.png',
                                  width: 72.w,
                                  height: 72.w,
                                ),
                                SizedBox(height: 20.h),
                                Text(
                                  _linkSent
                                      ? 'Check Your Email'
                                      : 'Forgot Password',
                                  style: TextStyle(
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  _linkSent
                                      ? 'If that username exists and has an email on file, a password reset link has been sent to it.'
                                      : 'Enter your username and we\'ll send a reset link to the email on file.',
                                  style: TextStyle(
                                    fontSize: 13.5.sp,
                                    color: colors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 28.h),
                                if (!_linkSent)
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
                                              borderRadius:
                                                  BorderRadius.circular(10.r),
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
                                          icon: Icons.person_outline,
                                          onChanged: _onUsernameChanged,
                                        ),
                                        AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          child: _maskedEmail == null
                                              ? const SizedBox.shrink()
                                              : Padding(
                                                  key: ValueKey(_maskedEmail),
                                                  padding: EdgeInsets.only(
                                                    top: 10.h,
                                                    left: 4.w,
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .mark_email_read_outlined,
                                                        size: 15.sp,
                                                        color: colors.textSecondary,
                                                      ),
                                                      SizedBox(width: 6.w),
                                                      Flexible(
                                                        child: Text(
                                                          'Reset link will be sent to $_maskedEmail',
                                                          style: TextStyle(
                                                            fontSize: 12.sp,
                                                            color: colors.textSecondary,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                        ),
                                        SizedBox(height: 20.h),
                                        GlossyButton(
                                          label: 'Send Reset Link',
                                          isLoading: _isLoading,
                                          onPressed: _sendResetLink,
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  GlossyButton(
                                    label: 'Back to Login',
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
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
          ),
        ],
      ),
    );
  }
}
