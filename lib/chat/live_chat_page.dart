import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dashboard/tabs/chat_tab.dart';
import '../theme/app_colors.dart';
import '../widgets/glossy_widgets.dart';
import 'how_to_chat_sheet.dart';
import 'models/chat_message.dart';
import 'services/chat_service.dart';

/// In-app live chat with vaxilife support — a shared inbox (not a specific
/// rep), polled every few seconds rather than real-time, matching what the
/// backend currently supports. The existing Messenger option is still
/// reachable via the header action, not replaced by this.
class LiveChatPage extends StatefulWidget {
  const LiveChatPage({super.key, this.username});

  final String? username;

  @override
  State<LiveChatPage> createState() => _LiveChatPageState();
}

class _LiveChatPageState extends State<LiveChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  File? _pendingFile;
  String? _pendingFileName;
  bool _pendingIsImage = false;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
    _maybeShowHowToChat();
  }

  Future<void> _maybeShowHowToChat() async {
    if (await hasSeenHowToChat()) return;
    if (!mounted) return;
    await showHowToChatSheet(context);
    await markHowToChatSeen();
  }

  void _showHowToChat() => showHowToChatSheet(context);

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final username = widget.username;
    if (username == null || username.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final messages = await ChatService.fetchMessages(username);
    if (!mounted) return;

    final changed = messages.length != _messages.length;
    setState(() {
      _messages = messages;
      _loading = false;
    });
    if (changed) _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAttachment() async {
    FocusScope.of(context).unfocus();
    final source = await showModalBottomSheet<_AttachSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AttachSheet(),
    );
    if (source == null) return;

    try {
      if (source == _AttachSource.document) {
        final result = await FilePicker.platform.pickFiles();
        final picked = result?.files.single;
        if (picked == null || picked.path == null) return;
        setState(() {
          _pendingFile = File(picked.path!);
          _pendingFileName = picked.name;
          _pendingIsImage = false;
        });
      } else {
        final picked = await ImagePicker().pickImage(
          source: source == _AttachSource.camera ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 85,
        );
        if (picked == null) return;
        setState(() {
          _pendingFile = File(picked.path);
          _pendingFileName = picked.name;
          _pendingIsImage = true;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access that. Check app permissions and try again.')),
        );
      }
    }
  }

  void _removePendingAttachment() {
    setState(() {
      _pendingFile = null;
      _pendingFileName = null;
    });
  }

  Future<void> _send() async {
    final username = widget.username;
    final text = _controller.text.trim();
    final pendingFile = _pendingFile;
    if (username == null || username.isEmpty || _sending) return;
    if (text.isEmpty && pendingFile == null) return;

    setState(() => _sending = true);

    ChatAttachmentUpload? uploaded;
    if (pendingFile != null) {
      uploaded = await ChatService.uploadAttachment(pendingFile);
      if (uploaded == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload attachment. Please try again.')),
          );
          setState(() => _sending = false);
        }
        return;
      }
    }

    _controller.clear();
    setState(() {
      _pendingFile = null;
      _pendingFileName = null;
    });

    final success = await ChatService.sendMessage(
      username,
      text,
      attachmentUrl: uploaded?.url,
      attachmentFileName: uploaded?.fileName,
      attachmentContentType: uploaded?.contentType,
      attachmentSize: uploaded?.size,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message. Please try again.')),
      );
    }
    await _load();
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final username = widget.username;
    if (username == null || username.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: brandRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await ChatService.deleteMessage(username, message.id);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete message. Please try again.')),
      );
      return;
    }
    await _load(silent: true);
  }

  void _openMessengerScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: brandRed,
            foregroundColor: Colors.white,
            title: const Text('Message us'),
          ),
          body: const ChatTab(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onMessengerTap: _openMessengerScreen, onHelpTap: _showHowToChat),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: brandRed))
                  : RefreshIndicator(
                      color: brandRed,
                      onRefresh: () => _load(silent: true),
                      child: _messages.isEmpty
                          ? LayoutBuilder(
                              builder: (context, constraints) => ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(height: constraints.maxHeight, child: const _EmptyState()),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) => _MessageBubble(
                                message: _messages[index],
                                onDelete: () => _deleteMessage(_messages[index]),
                              ),
                            ),
                    ),
            ),
            _Composer(
              controller: _controller,
              sending: _sending,
              onSend: _send,
              onAttach: _pickAttachment,
              pendingFileName: _pendingFileName,
              pendingIsImage: _pendingIsImage,
              onRemoveAttachment: _removePendingAttachment,
            ),
          ],
        ),
      ),
    );
  }
}

enum _AttachSource { camera, gallery, document }

class _AttachSheet extends StatelessWidget {
  const _AttachSheet();

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
            _AttachOption(
              icon: Icons.photo_camera_rounded,
              label: 'Camera',
              onTap: () => Navigator.pop(context, _AttachSource.camera),
            ),
            _AttachOption(
              icon: Icons.photo_library_rounded,
              label: 'Gallery',
              onTap: () => Navigator.pop(context, _AttachSource.gallery),
            ),
            _AttachOption(
              icon: Icons.insert_drive_file_rounded,
              label: 'Document',
              onTap: () => Navigator.pop(context, _AttachSource.document),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: brandRed),
      title: Text(label, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onMessengerTap, required this.onHelpTap});

  final VoidCallback onMessengerTap;
  final VoidCallback onHelpTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20.w, 14.h, 12.w, 16.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [brandRed.withValues(alpha: 0.85), brandRedDark.withValues(alpha: 0.9)],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chat Support',
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'We usually reply within the day',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onHelpTap,
                icon: Icon(Icons.help_outline_rounded, color: Colors.white, size: 22.sp),
                tooltip: 'How to use Chat Support',
              ),
              IconButton(
                onPressed: onMessengerTap,
                icon: Icon(Icons.facebook_rounded, color: Colors.white, size: 24.sp),
                tooltip: 'Message us on Facebook instead',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onDelete});

  final ChatMessage message;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isClinic = message.isFromClinic;
    final hasText = message.message.trim().isNotEmpty;
    // Only the clinic can unsend, and only its own not-yet-deleted messages —
    // mirrors the server-side ownership check in ChatController.Delete.
    final canDelete = isClinic && !message.isDeleted;

    return Align(
      alignment: isClinic ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: canDelete ? onDelete : null,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            gradient: isClinic
                ? const LinearGradient(colors: [brandRed, brandRedDark])
                : null,
            color: isClinic ? null : colors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.r),
              topRight: Radius.circular(16.r),
              bottomLeft: Radius.circular(isClinic ? 16.r : 4.r),
              bottomRight: Radius.circular(isClinic ? 4.r : 16.r),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isClinic)
                Padding(
                  padding: EdgeInsets.only(bottom: 3.h),
                  child: Text(
                    (message.staffName?.trim().isNotEmpty ?? false) ? message.staffName! : 'Support',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: brandRed,
                    ),
                  ),
                ),
              if (message.isDeleted)
                Text(
                  message.message,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontStyle: FontStyle.italic,
                    color: isClinic ? Colors.white.withValues(alpha: 0.8) : colors.textSecondary,
                    height: 1.3,
                  ),
                )
              else ...[
                if (message.hasAttachment) ...[
                  _AttachmentContent(message: message, isClinic: isClinic),
                  if (hasText) SizedBox(height: 6.h),
                ],
                if (hasText)
                  Text(
                    message.message,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      color: isClinic ? Colors.white : colors.textPrimary,
                      height: 1.3,
                    ),
                  ),
              ],
              SizedBox(height: 4.h),
              Text(
                DateFormat('MMM d, h:mm a').format(message.createdAt),
                style: TextStyle(
                  fontSize: 9.5.sp,
                  color: isClinic ? Colors.white.withValues(alpha: 0.75) : colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentContent extends StatelessWidget {
  const _AttachmentContent({required this.message, required this.isClinic});

  final ChatMessage message;
  final bool isClinic;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (message.isImageAttachment) {
      return GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _FullScreenImage(url: message.attachmentUrl!)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: Image.network(
            message.attachmentUrl!,
            width: 180.w,
            height: 180.w,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                width: 180.w,
                height: 180.w,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
            errorBuilder: (_, __, ___) => SizedBox(
              width: 180.w,
              height: 180.w,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () async {
        final uri = Uri.tryParse(message.attachmentUrl ?? '');
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isClinic ? Colors.white.withValues(alpha: 0.15) : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_rounded, size: 20.sp, color: isClinic ? Colors.white : brandRed),
            SizedBox(width: 8.w),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.attachmentFileName ?? 'File',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: isClinic ? Colors.white : colors.textPrimary,
                    ),
                  ),
                  if (message.attachmentSize != null)
                    Text(
                      _formatFileSize(message.attachmentSize!),
                      style: TextStyle(fontSize: 9.5.sp, color: isClinic ? Colors.white70 : colors.textSecondary),
                    ),
                ],
              ),
            ),
            SizedBox(width: 6.w),
            Icon(Icons.download_rounded, size: 16.sp, color: isClinic ? Colors.white70 : colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(url),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onAttach,
    required this.pendingFileName,
    required this.pendingIsImage,
    required this.onRemoveAttachment,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final String? pendingFileName;
  final bool pendingIsImage;
  final VoidCallback onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.fromLTRB(8.w, 10.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pendingFileName != null)
            Padding(
              padding: EdgeInsets.fromLTRB(4.w, 0, 0, 8.h),
              child: _PendingAttachmentChip(
                fileName: pendingFileName!,
                isImage: pendingIsImage,
                onRemove: sending ? null : onRemoveAttachment,
              ),
            ),
          Row(
            children: [
              IconButton(
                onPressed: sending ? null : onAttach,
                icon: Icon(Icons.attach_file_rounded, color: brandRed, size: 22.sp),
                tooltip: 'Attach photo or file',
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle: TextStyle(fontSize: 13.sp, color: colors.textTertiary),
                    filled: true,
                    fillColor: colors.surfaceVariant,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              InkWell(
                onTap: sending ? null : onSend,
                borderRadius: BorderRadius.circular(24.r),
                child: Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [brandRed, brandRedDark]),
                  ),
                  child: sending
                      ? Padding(
                          padding: EdgeInsets.all(12.w),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.send_rounded, color: Colors.white, size: 18.sp),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingAttachmentChip extends StatelessWidget {
  const _PendingAttachmentChip({
    required this.fileName,
    required this.isImage,
    required this.onRemove,
  });

  final String fileName;
  final bool isImage;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
            size: 16.sp,
            color: brandRed,
          ),
          SizedBox(width: 6.w),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 160.w),
            child: Text(
              fileName,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(fontSize: 11.5.sp, color: colors.textPrimary),
            ),
          ),
          SizedBox(width: 6.w),
          InkWell(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 16.sp, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
                Icons.chat_bubble_outline_rounded,
                color: brandRed.withValues(alpha: 0.6),
                size: 40.sp,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No messages yet',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
            SizedBox(height: 6.h),
            Text(
              'Say hello — our team usually replies within the day.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
