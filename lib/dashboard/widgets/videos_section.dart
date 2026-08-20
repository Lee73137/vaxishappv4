import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../../theme/app_colors.dart';
import '../../widgets/glossy_widgets.dart';
import '../models/vaxi_video.dart';
import '../video_player_screen.dart';

/// Same endpoint and data shape vaxishappv2.2 uses for its video gallery.
class VideosSection extends StatefulWidget {
  const VideosSection({super.key});

  @override
  State<VideosSection> createState() => _VideosSectionState();
}

class _VideosSectionState extends State<VideosSection> {
  static const _url = 'http://shopapi.vaxilifecorp.com/api/general/vaxivideos';

  List<VaxiVideo> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final videos = data.map((e) => VaxiVideo.fromJson(e)).take(10).toList();
        if (mounted) {
          setState(() {
            _videos = videos;
            _loading = false;
          });
        }
        return;
      }
    } catch (_) {
      // Videos are a nice-to-have — fail silently rather than showing a
      // broken section, matching the rest of the dashboard's optional cards.
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: 150.h,
        child: const Center(
          child: CircularProgressIndicator(color: brandRed, strokeWidth: 2.4),
        ),
      );
    }

    if (_videos.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vaxilife Videos',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 150.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _videos.length,
            separatorBuilder: (_, _) => SizedBox(width: 12.w),
            itemBuilder: (context, index) => _VideoTile(video: _videos[index]),
          ),
        ),
      ],
    );
  }
}

class _VideoTile extends StatefulWidget {
  const _VideoTile({required this.video});

  final VaxiVideo video;

  @override
  State<_VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<_VideoTile> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.video.videoUrl),
    );
    _controller = controller;
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          controller.pause();
          setState(() => _ready = true);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            url: widget.video.videoUrl,
            title: widget.video.title,
          ),
        ),
      ),
      child: SizedBox(
        width: 160.w,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 160.w,
              height: 100.h,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: colors.overlay,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_ready && _controller != null)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    )
                  else
                    const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: brandRed,
                      ),
                    ),
                  Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              widget.video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
