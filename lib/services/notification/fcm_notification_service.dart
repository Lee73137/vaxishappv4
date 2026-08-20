import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../../notifications/data/notification_database.dart';
import '../../notifications/models/fcm_message_record.dart';
import '../../notifications/notifications_page.dart';
import '../../widgets/fcm_banner_overlay.dart';

/// Notification channel + sound, matching the vaxishappv2.2 setup so both
/// apps' notifications look and sound the same.
const String vaxishSound = 'vaxi';
const String primaryChannelId = 'vaxish_notifications_v2';
// A notification's heads-up behavior is governed by its CHANNEL's importance
// on Android 8+ — it can't be overridden per-notification once the channel
// exists — so the quiet (banner-paired, no heads-up) case needs its own
// lower-importance channel rather than just passing a different Importance
// value to the same channel.
const String quietChannelId = 'vaxish_notifications_quiet';
// Chat messages use the plain system default notification sound instead of
// the branded "vaxi" one — a deliberate, different request from the rest of
// the app's notifications, so they need their own channel pair (Android
// only lets a channel's sound be set once, at creation).
const String chatChannelId = 'vaxish_notifications_chat';
const String chatQuietChannelId = 'vaxish_notifications_chat_quiet';

class FCMNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  /// Set by DashboardShell whenever the Chat tab becomes (or stops being)
  /// the active tab — lets the foreground listener know not to interrupt a
  /// user who's already looking at the chat (it'll show up there via
  /// polling on its own).
  static bool isChatScreenActive = false;

  /// Incremented (not just toggled — a bool wouldn't fire a second tap in a
  /// row if it were already true) whenever a tapped chat notification wants
  /// DashboardShell to switch to the Chat tab. DashboardShell listens for
  /// changes and reacts; it's a no-op if no shell is currently mounted to
  /// hear it (e.g. tapped while logged out).
  static final ValueNotifier<int> openChatRequest = ValueNotifier<int>(0);

  /// Called when the user taps a notification (foreground/background/local).
  /// Left unset by default; wire this up if a screen needs to react to taps.
  static Function(RemoteMessage)? onNotificationTap;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('🔔 FCM permission status: ${settings.authorizationStatus}');

      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        await androidPlugin?.createNotificationChannel(
          AndroidNotificationChannel(
            primaryChannelId,
            'VaxishApp Notifications',
            description: 'Notifications for VaxishApp',
            importance: Importance.high,
            sound: RawResourceAndroidNotificationSound(vaxishSound),
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          ),
        );

        // No heads-up popup — used when the glassy in-app banner is already
        // showing the visual and this is only here for the sound.
        await androidPlugin?.createNotificationChannel(
          AndroidNotificationChannel(
            quietChannelId,
            'VaxishApp Notifications (in-app)',
            description: 'Sound-only channel used while the app is open',
            importance: Importance.defaultImportance,
            sound: RawResourceAndroidNotificationSound(vaxishSound),
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          ),
        );

        // Chat channels — no `sound:` set, so Android plays the system
        // default notification sound instead of the "vaxi" raw resource.
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            chatChannelId,
            'Chat Messages',
            description: 'Replies from Vaxilife Support',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );

        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            chatQuietChannelId,
            'Chat Messages (in-app)',
            description: 'Sound-only channel used while the app is open',
            importance: Importance.defaultImportance,
            playSound: true,
            enableVibration: true,
          ),
        );

        debugPrint('✅ Android notification channels created with sound: $vaxishSound');
      }

      // The OS notification-shade badge and this app's own unread count are
      // two independent things — the badge reflects currently-posted system
      // notifications (which the user can dismiss straight from the shade,
      // bypassing the app entirely), while the in-app count comes from this
      // app's own read/unread tracking. They can only drift apart if nothing
      // keeps them in sync: clearing every local notification once nothing
      // is unread in-app is the other half of that (the `number:` set on
      // each notification below is the other half, for the "new push
      // arrives" direction).
      NotificationDatabase.unreadCountNotifier.addListener(() {
        if (NotificationDatabase.unreadCountNotifier.value == 0) {
          _localNotifications.cancelAll();
        }
      });

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
            defaultPresentSound: true,
          );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );

      String? token = await _fcm.getToken();
      debugPrint('📱 FCM Token: $token');

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📨 Foreground message received');
        // Chat messages have their own home (the Chat tab, fetched straight
        // from the DB) and never carry an image URL in the push itself (only
        // a text preview like "📷 Photo") — persisting them here would show
        // up in the general Notifications list promising a photo it can
        // never actually display.
        if (!_isChatMessage(message)) {
          _persistMessage(message);
        }

        final overlayState = _navigatorKey.currentState?.overlay;

        // Chat gets its own, quieter foreground treatment — no OS
        // notification while the app is open either way, and no visual
        // interruption at all if the user is already looking at the chat
        // (it'll show up there via polling on its own).
        if (_isChatMessage(message) && overlayState != null) {
          if (!isChatScreenActive) {
            scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(content: Text('${_extractTitle(message)}: ${_extractBody(message)}')),
            );
          }
          return;
        }

        // While the app is open, show the custom glassy in-app banner as the
        // visual — falls back to the system notification if there's no
        // overlay to show it in yet (e.g. very early during startup).
        if (overlayState != null) {
          // Still trigger the local notification for its sound/vibration —
          // just without a competing heads-up popup, since the banner is
          // already the visual for this message.
          _showLocalNotification(message, showHeadsUp: false);
          FCMBannerOverlay.show(
            overlayState: overlayState,
            title: _extractTitle(message),
            body: _extractBody(message),
            imageUrl: _extractImageUrl(message),
            onTap: () => _handleMessageTap(message),
          );
        } else {
          _showLocalNotification(message);
        }
      });

      final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('📬 App opened from terminated state with message');
        // SplashScreen shows for a fixed ~3s minimum before it replaces
        // itself with the real home route (see SplashScreen._init). Pushing
        // the notification screen before that finishes just gets clobbered
        // by that replacement, landing back on the plain Dashboard — so wait
        // it out first.
        Future.delayed(const Duration(seconds: 4), () {
          _handleMessageTap(initialMessage);
        });
      }

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 App opened from notification tap');
        _handleMessageTap(message);
      });

      _isInitialized = true;
      debugPrint('✅ FCM Notification Service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing FCM: $e');
    }
  }

  static void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('🔔 Local notification tapped: ${response.payload}');
  }

  static void _handleMessageTap(RemoteMessage message) {
    debugPrint('🔔 User tapped notification: ${_extractTitle(message)}');
    if (message.messageId != null) {
      NotificationDatabase().markReadByMessageId(message.messageId!);
    }

    if (_isChatMessage(message)) {
      // Chat lives inside DashboardShell's IndexedStack, not a separate
      // route — return to the shell (in case something else was pushed on
      // top) and signal it to switch to the Chat tab, rather than opening
      // the generic notification list/dialog.
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      openChatRequest.value++;
    } else {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => NotificationsPage(autoOpenMessageId: message.messageId),
        ),
      );
    }
    onNotificationTap?.call(message);
  }

  /// Every message the app observes (foreground here, or the background
  /// isolate handler below) gets saved locally so it shows up in the
  /// in-app notification list — Firebase itself keeps no history.
  static Future<void> _persistMessage(RemoteMessage message) async {
    await NotificationDatabase().insert(
      FCMMessageRecord(
        messageId: message.messageId,
        title: _extractTitle(message),
        body: _extractBody(message),
        imageUrl: _extractImageUrl(message),
        receivedAt: DateTime.now(),
      ),
    );
  }

  /// Sending a top-level `notification` block makes Android's FCM SDK
  /// auto-display its OWN system notification in addition to the one this
  /// app posts — and that auto-notification silently drops images over 1MB
  /// (Firebase's own hard limit), which looks like a broken/missing image
  /// with no error anywhere. Senders should send data-only messages instead
  /// (title/body/image under `data`) so only this app's handling runs — this
  /// title/body extraction supports both, for backward compatibility with
  /// senders that do still send a `notification` block.
  static String _extractTitle(RemoteMessage message) {
    return message.notification?.title ?? message.data['title'] ?? 'New Notification';
  }

  static String _extractBody(RemoteMessage message) {
    return message.notification?.body ?? message.data['body'] ?? '';
  }

  static bool _isChatMessage(RemoteMessage message) {
    return message.data['type'] == 'chat';
  }

  /// FCM puts an attached image on `notification.android.imageUrl` /
  /// `notification.apple.imageUrl` when sent via the console's "Image"
  /// field, or under `data` when sent manually — check both.
  static String? _extractImageUrl(RemoteMessage message) {
    final url =
        message.notification?.android?.imageUrl ??
        message.notification?.apple?.imageUrl ??
        message.data['image'] ??
        message.data['imageUrl'];
    // The `data` fallback keys are a loose convention, not a guaranteed
    // contract — validate it actually looks like an image URL rather than
    // some unrelated field a sender happened to name "image"/"imageUrl",
    // which would otherwise render as a broken image in the app.
    if (url is! String || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }
    return url;
  }

  static Future<Uint8List?> _downloadImageBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      debugPrint('❌ Failed to download notification image: $e');
    }
    return null;
  }

  static Future<DarwinNotificationAttachment?> _iosImageAttachment(Uint8List bytes) async {
    try {
      final file = File(
        '${Directory.systemTemp.path}/fcm_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes);
      return DarwinNotificationAttachment(file.path);
    } catch (e) {
      debugPrint('❌ Failed to prepare iOS notification image: $e');
      return null;
    }
  }

  static Future<void> _showLocalNotification(
    RemoteMessage message, {
    bool showHeadsUp = true,
  }) async {
    try {
      final payload = message.data['notificationId'] ?? message.messageId;
      final title = _extractTitle(message);
      final body = _extractBody(message);
      final imageUrl = _extractImageUrl(message);
      final imageBytes = imageUrl != null ? await _downloadImageBytes(imageUrl) : null;
      final isChat = _isChatMessage(message);
      // Many launchers (this device's EMUI/MagicUI included) read the app
      // icon badge count from the notification's own `number`, not from
      // guessing at how many are unread — pass the real figure so the
      // launcher badge and the in-app unread count can't disagree.
      final unreadCount = await NotificationDatabase().unreadCount();

      final String channelId = isChat
          ? (showHeadsUp ? chatChannelId : chatQuietChannelId)
          : (showHeadsUp ? primaryChannelId : quietChannelId);
      final String channelName = isChat
          ? (showHeadsUp ? 'Chat Messages' : 'Chat Messages (in-app)')
          : (showHeadsUp ? 'VaxishApp Notifications' : 'VaxishApp Notifications (in-app)');

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: showHeadsUp
                ? 'Notifications for VaxishApp'
                : 'Sound-only channel used while the app is open',
            number: unreadCount,
            importance: showHeadsUp ? Importance.high : Importance.defaultImportance,
            priority: showHeadsUp ? Priority.high : Priority.defaultPriority,
            // Chat uses the system default sound (no `sound:` override) —
            // everything else keeps the branded "vaxi" sound.
            sound: isChat ? null : RawResourceAndroidNotificationSound(vaxishSound),
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
            styleInformation: imageBytes != null
                ? BigPictureStyleInformation(
                    ByteArrayAndroidBitmap(imageBytes),
                    largeIcon: ByteArrayAndroidBitmap(imageBytes),
                    contentTitle: title,
                    summaryText: body,
                  )
                : null,
          );

      final DarwinNotificationAttachment? iosAttachment = imageBytes != null
          ? await _iosImageAttachment(imageBytes)
          : null;

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentSound: true,
        // Chat uses the system default sound (no `sound:` override).
        sound: isChat ? null : '$vaxishSound.caf',
        attachments: iosAttachment != null ? [iosAttachment] : null,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('✅ Local notification shown with sound: ${isChat ? 'default' : vaxishSound}');
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
    }
  }

  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Failed to subscribe to $topic: $e');
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Failed to unsubscribe from $topic: $e');
    }
  }

  static Future<String?> getToken() async {
    try {
      final token = await _fcm.getToken();
      debugPrint('📱 FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('❌ Failed to get FCM token: $e');
      return null;
    }
  }

  static Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
      debugPrint('🗑️ FCM token deleted');
    } catch (e) {
      debugPrint('❌ Failed to delete FCM token: $e');
    }
  }
}

// Top-level background handler (required by FCM) — runs in its own isolate,
// so it re-initializes Firebase and the local-notifications plugin itself.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message received: ${message.messageId}');

  // Unlike the foreground path (onMessage), nothing here was previously
  // wrapped in try/catch - since this runs in its own isolate, an exception
  // anywhere below (Firebase re-init, plugin re-init, channel/sound lookup,
  // image download, .show() itself) killed the whole isolate silently: FCM
  // still reports the message as delivered (that part genuinely succeeded),
  // but no notification ever appears and nothing gets logged anywhere the
  // OS/Firebase can surface. Wrapping the whole thing means a failure here
  // is at least visible in logs instead of looking identical to "nothing was
  // sent at all".
  try {
    await Firebase.initializeApp();

    // Same exclusion as the foreground path — chat messages belong in the
    // Chat tab, not the general Notifications history, and never carry a
    // real image URL in the push payload anyway.
    if (!FCMNotificationService._isChatMessage(message)) {
      await FCMNotificationService._persistMessage(message);
    }

    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      defaultPresentSound: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotifications.initialize(initSettings);

    final String title = FCMNotificationService._extractTitle(message);
    final String body = FCMNotificationService._extractBody(message);
    final String? imageUrl = FCMNotificationService._extractImageUrl(message);
    final Uint8List? imageBytes = imageUrl != null
        ? await FCMNotificationService._downloadImageBytes(imageUrl)
        : null;
    final int unreadCount = await NotificationDatabase().unreadCount();
    final bool isChat = FCMNotificationService._isChatMessage(message);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      isChat ? chatChannelId : primaryChannelId,
      isChat ? 'Chat Messages' : 'VaxishApp Notifications',
      channelDescription: isChat ? 'Replies from Vaxilife Support' : 'Notifications for VaxishApp',
      importance: Importance.high,
      priority: Priority.high,
      number: unreadCount,
      // Chat uses the system default sound (no `sound:` override) —
      // everything else keeps the branded "vaxi" sound.
      sound: isChat ? null : RawResourceAndroidNotificationSound(vaxishSound),
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      styleInformation: imageBytes != null
          ? BigPictureStyleInformation(
              ByteArrayAndroidBitmap(imageBytes),
              largeIcon: ByteArrayAndroidBitmap(imageBytes),
              contentTitle: title,
              summaryText: body,
            )
          : null,
    );

    final DarwinNotificationAttachment? iosAttachment = imageBytes != null
        ? await FCMNotificationService._iosImageAttachment(imageBytes)
        : null;

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentSound: true,
        sound: isChat ? null : '$vaxishSound.caf',
        attachments: iosAttachment != null ? [iosAttachment] : null,
      ),
    );

    await localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: message.messageId,
    );

    debugPrint('✅ Background notification shown with sound: ${isChat ? 'default' : vaxishSound}');
  } catch (e, stackTrace) {
    debugPrint('❌ Background notification failed to show: $e');
    debugPrint('$stackTrace');
  }
}
