import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import '../widgets/glossy_widgets.dart';
import 'data/notification_database.dart';
import 'models/fcm_message_record.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.autoOpenMessageId});

  /// When set (a tapped-notification's FCM messageId), the matching
  /// message's detail dialog opens automatically once the list loads,
  /// instead of making the user find and tap it again themselves.
  final String? autoOpenMessageId;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _db = NotificationDatabase();
  List<FCMMessageRecord> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load(autoOpen: true);
  }

  Future<void> _load({bool autoOpen = false}) async {
    final messages = await _db.getAll();
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _loading = false;
    });

    if (autoOpen && widget.autoOpenMessageId != null) {
      final match = messages
          .where((m) => m.messageId == widget.autoOpenMessageId)
          .toList();
      if (match.isNotEmpty) _open(match.first);
    }
  }

  Future<void> _markAllRead() async {
    await _db.markAllRead();
    await _load();
  }

  Future<void> _delete(FCMMessageRecord record) async {
    if (record.id == null) return;
    setState(() => _messages.removeWhere((m) => m.id == record.id));
    await _db.deleteOne(record.id!);
  }

  Future<void> _open(FCMMessageRecord record) async {
    if (!record.isRead && record.id != null) {
      await _db.markRead(record.id!);
      setState(() {
        final index = _messages.indexWhere((m) => m.id == record.id);
        if (index != -1) {
          _messages[index] = FCMMessageRecord(
            id: record.id,
            messageId: record.messageId,
            title: record.title,
            body: record.body,
            imageUrl: record.imageUrl,
            receivedAt: record.receivedAt,
            isRead: true,
          );
        }
      });
    }
    if (mounted) _showMessageDetail(record);
  }

  void _showMessageDetail(FCMMessageRecord record) {
    final hasImage = record.imageUrl != null && record.imageUrl!.isNotEmpty;
    // A fixed, definite width (not just a max bound) so the image's
    // placeholder/error states always get tight layout constraints —
    // leaving them ambiguous is what caused a RenderFlex overflow when an
    // image failed to load and the Dialog tried to shrink-wrap an
    // unresolved size.
    final boxWidth = MediaQuery.of(context).size.width * 0.85;
    final maxDialogHeight = MediaQuery.of(context).size.height * 0.75;
    final colors = context.colors;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxDialogHeight, maxWidth: boxWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: Material(
              color: colors.surface,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasImage)
                      SizedBox(
                        width: boxWidth,
                        height: 220.h,
                        child: CachedNetworkImage(
                          imageUrl: record.imageUrl!,
                          fit: BoxFit.cover,
                          width: boxWidth,
                          height: 220.h,
                          placeholder: (context, url) => Container(
                            color: colors.overlay,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(color: brandRed),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: colors.overlay,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image_outlined, color: colors.textTertiary, size: 36.sp),
                                SizedBox(height: 8.h),
                                Text(
                                  'Image unavailable',
                                  style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.all(18.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.title,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: brandRedDark,
                            ),
                          ),
                          if (record.body.isNotEmpty) ...[
                            SizedBox(height: 8.h),
                            Text(
                              record.body,
                              style: TextStyle(
                                fontSize: 13.5.sp,
                                color: colors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ],
                          SizedBox(height: 16.h),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Close',
                                style: TextStyle(color: brandRed, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _messages.any((m) => !m.isRead);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              hasUnread: hasUnread,
              hasMessages: _messages.isNotEmpty,
              onMarkAllRead: _markAllRead,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: brandRed))
                  : _messages.isEmpty
                  ? _EmptyState()
                  : RefreshIndicator(
                      color: brandRed,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final record = _messages[index];
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: Dismissible(
                              key: ValueKey(record.id ?? record.hashCode),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => _delete(record),
                              background: _dismissBackground(),
                              child: _NotificationTile(
                                record: record,
                                onTap: () => _open(record),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: EdgeInsets.only(right: 20.w),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.hasUnread,
    required this.hasMessages,
    required this.onMarkAllRead,
  });

  final bool hasUnread;
  final bool hasMessages;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(8.w, 6.h, 16.w, 16.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [brandRed.withValues(alpha: 0.85), brandRedDark.withValues(alpha: 0.9)],
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (hasMessages)
                TextButton(
                  onPressed: hasUnread ? onMarkAllRead : null,
                  child: Text(
                    'Mark all read',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: hasUnread ? 1 : 0.5),
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.record, required this.onTap});

  final FCMMessageRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: record.isRead
                      ? [colors.surface.withValues(alpha: 0.7), colors.surface.withValues(alpha: 0.5)]
                      : [colors.surface.withValues(alpha: 0.92), brandRed.withValues(alpha: 0.16)],
                ),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: colors.divider),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Thumbnail(imageUrl: record.imageUrl, isRead: record.isRead),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                record.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5.sp,
                                  fontWeight: record.isRead ? FontWeight.w600 : FontWeight.w800,
                                  color: record.isRead ? colors.textSecondary : brandRedDark,
                                ),
                              ),
                            ),
                            if (!record.isRead)
                              Container(
                                width: 8.w,
                                height: 8.w,
                                margin: EdgeInsets.only(left: 6.w),
                                decoration: const BoxDecoration(
                                  color: brandRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        if (record.body.isNotEmpty) ...[
                          SizedBox(height: 3.h),
                          Text(
                            record.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: colors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ],
                        SizedBox(height: 6.h),
                        Text(
                          _timeAgo(record.receivedAt),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: colors.textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl, required this.isRead});

  final String? imageUrl;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = 48.w;

    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isRead
              ? LinearGradient(colors: [colors.textTertiary, colors.iconInactive])
              : const LinearGradient(colors: [brandRed, brandRedDark]),
        ),
        child: Icon(Icons.notifications_rounded, color: Colors.white, size: 22.sp),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
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
          child: Icon(Icons.notifications_rounded, color: Colors.white, size: 22.sp),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84.w,
              height: 84.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandRed.withValues(alpha: 0.08),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                color: brandRed.withValues(alpha: 0.6),
                size: 40.sp,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'We\'ll let you know when something new comes in.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

String _timeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) return '${weeks}w ago';
  final months = (diff.inDays / 30).floor();
  return '${months}mo ago';
}
