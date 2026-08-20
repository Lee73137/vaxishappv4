import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../chat/live_chat_page.dart';
import '../invoices/invoices_tab.dart';
import '../services/auth_service.dart';
import '../services/notification/fcm_notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glossy_widgets.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/shop_tab.dart';

const int _chatTabIndex = 3;

class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

const _navItems = [
  _NavItem(Icons.grid_view_rounded, 'Dashboard'),
  _NavItem(Icons.storefront_outlined, 'Shop'),
  _NavItem(Icons.receipt_long_outlined, 'Invoices'),
  _NavItem(Icons.chat_bubble_outline_rounded, 'Chat'),
  _NavItem(Icons.person_outline, 'Profile'),
];

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, this.user});

  final UserSession? user;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    FCMNotificationService.openChatRequest.addListener(_onOpenChatRequested);
  }

  void _onOpenChatRequested() {
    _setIndex(_chatTabIndex);
  }

  void _setIndex(int index) {
    setState(() => _index = index);
    // Lets the FCM foreground listener know not to interrupt with a banner
    // when the user is already looking at the chat — it'll show up there
    // via polling on its own.
    FCMNotificationService.isChatScreenActive = index == _chatTabIndex;
  }

  @override
  void dispose() {
    FCMNotificationService.openChatRequest.removeListener(_onOpenChatRequested);
    if (FCMNotificationService.isChatScreenActive) {
      FCMNotificationService.isChatScreenActive = false;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardTab(
        user: widget.user,
        onProfileTap: () => _setIndex(4),
        onInvoicesTap: () => _setIndex(2),
      ),
      const ShopTab(),
      InvoicesTab(user: widget.user),
      LiveChatPage(username: widget.user?.username),
      ProfileTab(user: widget.user),
    ];

    return Scaffold(
      backgroundColor: context.colors.scaffoldBackground,
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: _GlossyNavBar(
        currentIndex: _index,
        onTap: _setIndex,
      ),
    );
  }
}

class _GlossyNavBar extends StatelessWidget {
  const _GlossyNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_navItems.length, (index) {
                  final item = _navItems[index];
                  final isActive = index == currentIndex;
                  return _NavButton(
                    icon: item.icon,
                    label: item.label,
                    isActive: isActive,
                    onTap: () => onTap(index),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isActive
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [brandRed, brandRedDark],
                      )
                    : null,
                color: isActive ? null : context.colors.surfaceVariant,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: brandRed.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 22.sp,
                color: isActive ? Colors.white : context.colors.iconInactive,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? brandRed : context.colors.iconInactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
