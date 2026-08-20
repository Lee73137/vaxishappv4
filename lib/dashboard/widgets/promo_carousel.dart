import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

import '../../theme/app_colors.dart';
import '../../widgets/glossy_widgets.dart';

/// Marketing banner images — fetched from the same endpoint vaxishappv2.2
/// uses (GET /api/promodisplay), a plain JSON array of image URLs with no
/// per-image title/subtitle metadata.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key, this.autoPlayInterval = const Duration(seconds: 4)});

  final Duration autoPlayInterval;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  static const _baseUrl = 'http://shopapi.vaxilifecorp.com';

  late final PageController _controller;
  Timer? _timer;
  int _page = 0;
  bool _isLoading = true;
  List<String> _images = [];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _fetchPromoImages();
  }

  Future<void> _fetchPromoImages() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/promodisplay'))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final urls = data
            .map((e) => e.toString().trim())
            .where((u) => u.startsWith('http'))
            .toList();
        setState(() {
          _images = urls;
          _isLoading = false;
        });
        if (urls.length > 1) {
          _timer = Timer.periodic(widget.autoPlayInterval, (_) => _advance());
        }
      } else {
        setState(() {
          _images = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _images = [];
        _isLoading = false;
      });
    }
  }

  void _advance() {
    if (!mounted || _images.isEmpty || !_controller.hasClients) return;
    final next = (_page + 1) % _images.length;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  // Plain fade to a full-screen viewer — deliberately not a Hero flight, so
  // the image doesn't visibly grow from carousel size on the way in. Zoom
  // itself is the user's own pinch gesture once there, via InteractiveViewer.
  void _openZoom(BuildContext context, String url) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: _PromoZoomView(imageUrl: url),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_isLoading) {
      return Container(
        height: 316.h,
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: brandRed, strokeWidth: 2.4),
        ),
      );
    }

    if (_images.isEmpty) {
      return Container(
        height: 120.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          'No promotions right now',
          style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 316.h,
          child: PageView.builder(
            controller: _controller,
            itemCount: _images.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) {
              final url = _images[index];
              return GestureDetector(
                onTap: () => _openZoom(context, url),
                child: _PromoCard(imageUrl: url, borderRadius: 0),
              );
            },
          ),
        ),
        if (_images.length > 1) ...[
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_images.length, (index) {
              final isActive = index == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: isActive ? 18.w : 6.w,
                height: 6.w,
                decoration: BoxDecoration(
                  color: isActive ? brandRed : colors.iconInactive,
                  borderRadius: BorderRadius.circular(3.r),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.imageUrl,
    double? borderRadius,
    this.fit = BoxFit.cover,
  }) : _borderRadius = borderRadius;

  final String imageUrl;
  final double? _borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_borderRadius ?? 20.r),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_borderRadius ?? 20.r),
        child: Image.network(
          imageUrl,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: colors.surfaceVariant,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: brandRed, strokeWidth: 2.4),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: colors.surfaceVariant,
              alignment: Alignment.center,
              child: Icon(Icons.broken_image_rounded, size: 50.sp, color: colors.iconInactive),
            );
          },
        ),
      ),
    );
  }
}

/// Full-screen viewer for a tapped banner — opens directly at full-screen
/// size (no Hero flight/growth from the carousel), then lets the user
/// pinch-zoom and pan on their own via InteractiveViewer.
class _PromoZoomView extends StatelessWidget {
  const _PromoZoomView({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    // InteractiveViewer gives its child unbounded constraints
                    // (so it can size itself naturally for panning) — without
                    // this explicit bound, _PromoCard's width/height:
                    // double.infinity has nothing finite to resolve against,
                    // and Image.network falls back to the image's own raw
                    // pixel dimensions instead of fitting the screen.
                    child: SizedBox(
                      width: screenSize.width - 48.w,
                      height: screenSize.height * 0.7,
                      child: _PromoCard(
                        imageUrl: imageUrl,
                        borderRadius: 16,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8.h,
                right: 12.w,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 28.sp,
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
