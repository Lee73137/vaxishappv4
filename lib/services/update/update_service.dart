import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Gates app launch on a required update.
///
/// Android: Google Play's own "immediate update" flow is a full-screen
/// native UI that blocks the app until the user updates, so this handles
/// everything itself and returns null — there's nothing left for the caller
/// to show.
///
/// iOS has no OS-level equivalent, so this checks the App Store's public
/// lookup endpoint and returns the store URL when the installed build is
/// older than what's currently published, leaving the caller to show its
/// own blocking screen.
class UpdateService {
  static const String _iosBundleId = 'com.vaxilifecorp.vaxishappPlus';

  static Future<String?> checkAndHandle() async {
    if (Platform.isAndroid) {
      await _handleAndroid();
      return null;
    }
    if (Platform.isIOS) {
      return _checkIOS();
    }
    return null;
  }

  static Future<void> _handleAndroid() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable &&
          info.immediateUpdateAllowed) {
        // Blocks with Play's own full-screen UI until the update installs;
        // only returns once that's done (or throws, caught below).
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      // No Play Store on this device, no network, check failed, etc. — never
      // block app launch over a failed *check*, only a *confirmed* update.
      debugPrint('⚠️ Android update check failed: $e');
    }
  }

  static Future<String?> _checkIOS() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final uri = Uri.parse(
        'https://itunes.apple.com/lookup?bundleId=$_iosBundleId',
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final result = results.first as Map<String, dynamic>;
      final storeVersion = result['version']?.toString();
      final storeUrl = result['trackViewUrl']?.toString();
      if (storeVersion == null || storeUrl == null) return null;

      return _isNewer(storeVersion, packageInfo.version) ? storeUrl : null;
    } catch (e) {
      debugPrint('⚠️ iOS update check failed: $e');
      return null;
    }
  }

  /// Compares dotted version strings ("1.2.10" vs "1.2.9") segment-by-segment
  /// as integers — a plain string compare would get "1.2.10" < "1.2.9" wrong.
  static bool _isNewer(String remote, String local) {
    final r = remote.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final l = local.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final len = r.length > l.length ? r.length : l.length;
    for (var i = 0; i < len; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv != lv) return rv > lv;
    }
    return false;
  }
}
