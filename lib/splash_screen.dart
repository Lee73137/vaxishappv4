import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'dashboard/dashboard_shell.dart';
import 'login/login_page.dart';
import 'services/auth_service.dart';
import 'services/update/update_service.dart';
import 'shop/providers/cart_provider.dart';
import 'update/update_required_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      AuthService.hasSession(),
      Future.delayed(const Duration(seconds: 3)),
      // Android: blocks internally with Play's own full-screen update UI and
      // resolves null once done. iOS: resolves a store URL when the
      // installed build is behind what's published, null otherwise.
      UpdateService.checkAndHandle(),
    ]);

    if (!mounted) return;

    final updateRequiredUrl = results[2] as String?;
    if (updateRequiredUrl != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => UpdateRequiredScreen(storeUrl: updateRequiredUrl),
        ),
      );
      return;
    }

    final hasSession = results[0] as bool;
    final user = hasSession ? await AuthService.loadSession() : null;

    if (!mounted) return;

    // A stale or corrupt stored session (e.g. after an update changes the
    // session JSON shape) can leave hasSession=true but loadSession()=null —
    // treat that as logged out instead of opening the dashboard with no
    // user, and clear the stale flag so this doesn't repeat every launch.
    final isLoggedIn = hasSession && user != null;
    if (hasSession && user == null) {
      await AuthService.logout();
    }

    if (user != null && user.username.isNotEmpty) {
      await context.read<CartProvider>().loadForUser(user.username);
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            isLoggedIn ? DashboardShell(user: user) : const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pure white to match the native launch_background.xml exactly — using
    // the themed scaffold color here (off-white in light mode) created a
    // visible seam right at the logo the instant Flutter took over from the
    // native splash.
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/img/vaxishapplogo.png',
          width: 150.w,
          height: 150.w,
        ),
      ),
    );
  }
}
