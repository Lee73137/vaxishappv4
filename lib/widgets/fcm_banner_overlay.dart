import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import 'glossy_widgets.dart';

/// In-app glassy banner shown for FCM messages received while the app is
/// in the foreground — the OS status-bar notification can't be styled, so
/// this is where the "glassy" look actually gets applied. Background/
/// terminated messages still fall back to the native system notification.
class FCMBannerOverlay {
  static OverlayEntry? _current;

  /// Takes the [OverlayState] directly (e.g. `navigatorKey.currentState!.overlay!`)
  /// rather than a [BuildContext] — this is called from the FCM service, which
  /// has no widget context of its own to look an ancestor Overlay up from.
  static void show({
    required OverlayState overlayState,
    required String title,
    required String body,
    String? imageUrl,
    VoidCallback? onTap,
  }) {
    _current?.remove();
    _current = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FCMBanner(
        title: title,
        body: body,
        imageUrl: imageUrl,
        onDismiss: () {
          if (_current == entry) {
            _current = null;
            entry.remove();
          }
        },
        onTap: onTap == null
            ? null
            : () {
                onTap();
                if (_current == entry) {
                  _current = null;
                  entry.remove();
                }
              },
      ),
    );
    _current = entry;
    overlayState.insert(entry);
  }
}

class _FCMBanner extends StatefulWidget {
  const _FCMBanner({
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.onDismiss,
    this.onTap,
  });

  final String title;
  final String body;
  final String? imageUrl;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  @override
  State<_FCMBanner> createState() => _FCMBannerState();
}

class _FCMBannerState extends State<_FCMBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _autoDismiss;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    _autoDismiss = Timer(const Duration(seconds: 6), _dismiss);
  }

  Future<void> _dismiss() async {
    _autoDismiss?.cancel();
    if (!mounted) {
      widget.onDismiss();
      return;
    }
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final colors = context.colors;

    return Positioned(
      top: topPadding + 8.h,
      left: 14.w,
      right: 14.w,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            // Only the drag-to-dismiss gesture lives on this outer detector —
            // tap is handled by the inner content InkWell instead. Putting a
            // tap handler here too would put it in the same gesture arena as
            // the close button's InkWell (which sits inside this detector's
            // hit area), so both could fire off a single tap on the button.
            onVerticalDragUpdate: (details) {
              if (details.delta.dy < 0) {
                setState(() => _dragOffset += details.delta.dy);
              }
            },
            onVerticalDragEnd: (_) {
              if (_dragOffset < -20) {
                _dismiss();
              } else {
                setState(() => _dragOffset = 0);
              }
            },
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.surface.withValues(alpha: 0.92),
                            brandRed.withValues(alpha: 0.22),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: colors.divider),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14.r),
                              onTap: () {
                                _autoDismiss?.cancel();
                                if (widget.onTap != null) {
                                  widget.onTap!();
                                } else {
                                  _dismiss();
                                }
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Thumbnail(imageUrl: widget.imageUrl),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5.sp,
                                            fontWeight: FontWeight.w800,
                                            color: brandRedDark,
                                          ),
                                        ),
                                        if (widget.body.isNotEmpty) ...[
                                          SizedBox(height: 2.h),
                                          Text(
                                            widget.body,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              color: colors.textPrimary,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          InkWell(
                            borderRadius: BorderRadius.circular(14.r),
                            onTap: () {
                              _autoDismiss?.cancel();
                              _dismiss();
                            },
                            child: Padding(
                              padding: EdgeInsets.all(4.w),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16.sp,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = 52.w;

    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [brandRed, brandRedDark]),
        ),
        child: Icon(Icons.notifications_rounded, color: Colors.white, size: 24.sp),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14.r),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(width: size, height: size, color: colors.overlay),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [brandRed, brandRedDark]),
          ),
          child: Icon(Icons.notifications_rounded, color: Colors.white, size: 24.sp),
        ),
      ),
    );
  }
}
