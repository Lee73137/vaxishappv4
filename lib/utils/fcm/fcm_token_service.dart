import 'dart:convert';
import 'dart:io';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/device_id_service.dart';

class FcmTokenService {
  static final FcmTokenService _instance = FcmTokenService._internal();
  factory FcmTokenService() => _instance;
  FcmTokenService._internal();

  static const String _baseUrl = 'http://shopapi.vaxilifecorp.com';
  static const int _tokenRefreshDays = 7;

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Map<String, String>? _cachedDeviceInfo;

  /// Get FCM token
  Future<String> getFcmToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentProjectId = Firebase.app().options.projectId;
      final cachedProjectId = prefs.getString('fcm_token_project_id');

      String? localToken = prefs.getString('fcm_token');
      if (localToken != null &&
          localToken.isNotEmpty &&
          cachedProjectId == currentProjectId) {
        debugPrint('📱 Using cached FCM token');
        return localToken;
      }

      if (cachedProjectId != null && cachedProjectId != currentProjectId) {
        debugPrint(
          '⚠️ Firebase project changed ($cachedProjectId -> $currentProjectId), refreshing FCM token',
        );
        await _resetInstallation();
      }

      final token = await FirebaseMessaging.instance.getToken();

      if (token == null || token.isEmpty) {
        debugPrint('⚠️ FCM token is null or empty');
        return '';
      }

      await prefs.setString('fcm_token', token);
      await prefs.setString('fcm_token_project_id', currentProjectId);
      await prefs.setString(
        'fcm_token_timestamp',
        DateTime.now().toIso8601String(),
      );

      debugPrint('✅ FCM token obtained and cached');
      return token;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return '';
    }
  }

  Future<void> _resetInstallation() async {
    try {
      await FirebaseInstallations.instance.delete();
      debugPrint('🗑️ Firebase Installation deleted, forcing fresh registration');
    } catch (e) {
      debugPrint('❌ Error deleting Firebase Installation: $e');
    }
  }

  Future<String> forceRefreshToken() async {
    try {
      debugPrint('🔄 Force refreshing FCM token...');
      await _resetInstallation();
      await FirebaseMessaging.instance.deleteToken();
      await Future.delayed(const Duration(milliseconds: 500));

      final token = await FirebaseMessaging.instance.getToken();

      if (token == null || token.isEmpty) {
        debugPrint('⚠️ Failed to get new token after force refresh');
        return '';
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      await prefs.setString(
        'fcm_token_project_id',
        Firebase.app().options.projectId,
      );
      await prefs.setString(
        'fcm_token_timestamp',
        DateTime.now().toIso8601String(),
      );

      debugPrint('✅ New FCM token obtained');
      return token;
    } catch (e) {
      debugPrint('❌ Error force refreshing token: $e');
      return '';
    }
  }

  /// Update token with device information
  Future<bool> updateToken(
    String username,
    String token, {
    bool forceUpdate = false,
  }) async {
    if (username.isEmpty || token.isEmpty) {
      debugPrint('⚠️ Username or token is empty');
      return false;
    }

    try {
      if (!forceUpdate && await _isTokenRecentlyUpdated(token)) {
        debugPrint('✅ Token recently updated, skipping');
        return true;
      }

      final deviceInfo = await _getDeviceInfo();
      final deviceId = await _getDeviceId();

      final requestData = {
        'username': username,
        'fcm_token': token,
        'device_id': deviceId,
        'platform': deviceInfo['platform'],
        'model': deviceInfo['model'],
        'manufacturer': deviceInfo['manufacturer'],
        'os_version': deviceInfo['os_version'],
        'app_name': await _getAppName(),
        'app_version': await _getAppVersion(),
      };

      debugPrint('📤 Updating token for user: $username');

      final url = Uri.parse('$_baseUrl/api/fcm/updatetoken');

      final response = await http
          .post(url, headers: _getHeaders(), body: jsonEncode(requestData))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          await _saveTokenLocally(token, deviceId);
          debugPrint('✅ Token updated successfully for $username');
          return true;
        } else {
          debugPrint('❌ API error: ${result['message'] ?? 'Unknown error'}');
          return false;
        }
      } else {
        debugPrint('❌ HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error updating token: $e');
      return false;
    }
  }

  Future<bool> removeToken(String username) async {
    if (username.isEmpty) return false;

    try {
      final deviceId = await _getDeviceId();
      final url = Uri.parse('$_baseUrl/api/fcm/removetoken');

      final response = await http
          .post(
            url,
            headers: _getHeaders(),
            body: jsonEncode({'username': username, 'device_id': deviceId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          await _clearLocalTokenData();
          debugPrint('✅ Token removed for user $username');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error removing token: $e');
      return false;
    }
  }

  Future<void> refreshTokenIfNeeded(String username) async {
    if (username.isEmpty) return;

    try {
      if (await _isTokenExpired()) {
        final token = await forceRefreshToken();
        if (token.isNotEmpty) {
          await updateToken(username, token, forceUpdate: true);
          debugPrint('🔄 Token refreshed for user $username');
        }
      }
    } catch (e) {
      debugPrint('❌ Error refreshing token: $e');
    }
  }

  Future<String?> getDeviceId() => DeviceIdService().peek();

  void clearCache() {
    _cachedDeviceInfo = null;
  }

  // ============ PRIVATE METHODS ============

  Map<String, String> _getHeaders() {
    return {'Content-Type': 'application/json', 'Accept': 'application/json'};
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    if (_cachedDeviceInfo != null) return _cachedDeviceInfo!;

    final deviceInfo = <String, String>{};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceInfo['platform'] = 'Android';
        deviceInfo['model'] = androidInfo.model;
        deviceInfo['manufacturer'] = androidInfo.manufacturer;
        deviceInfo['os_version'] = androidInfo.version.release;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceInfo['platform'] = 'iOS';
        deviceInfo['model'] = iosInfo.model;
        deviceInfo['manufacturer'] = 'Apple';
        deviceInfo['os_version'] = iosInfo.systemVersion;
      } else {
        deviceInfo['platform'] = Platform.operatingSystem;
        deviceInfo['model'] = 'Unknown';
        deviceInfo['manufacturer'] = 'Unknown';
        deviceInfo['os_version'] = 'Unknown';
      }

      _cachedDeviceInfo = deviceInfo;
    } catch (e) {
      debugPrint('❌ Error getting device info: $e');
      deviceInfo['platform'] = Platform.operatingSystem;
      deviceInfo['model'] = 'Unknown';
      deviceInfo['manufacturer'] = 'Unknown';
      deviceInfo['os_version'] = 'Unknown';
    }

    return deviceInfo;
  }

  Future<String> _getDeviceId() => DeviceIdService().getOrCreate();

  Future<void> _saveTokenLocally(String token, String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    await prefs.setString(
      'fcm_token_project_id',
      Firebase.app().options.projectId,
    );
    await prefs.setString('device_id', deviceId);
    await prefs.setString(
      'fcm_token_last_updated',
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> _clearLocalTokenData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fcm_token');
    await prefs.remove('fcm_token_last_updated');
  }

  Future<bool> _isTokenRecentlyUpdated(String currentToken) async {
    final prefs = await SharedPreferences.getInstance();
    final lastToken = prefs.getString('fcm_token');
    final lastUpdate = prefs.getString('fcm_token_last_updated');

    if (lastToken != currentToken) return false;
    if (lastUpdate == null) return false;

    try {
      final lastUpdateTime = DateTime.parse(lastUpdate);
      final hoursSinceUpdate = DateTime.now().difference(lastUpdateTime).inHours;
      return hoursSinceUpdate < 1;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isTokenExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdate = prefs.getString('fcm_token_last_updated');

    if (lastUpdate == null) return true;

    try {
      final lastUpdateTime = DateTime.parse(lastUpdate);
      final daysSinceUpdate = DateTime.now().difference(lastUpdateTime).inDays;
      return daysSinceUpdate >= _tokenRefreshDays;
    } catch (e) {
      return true;
    }
  }

  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return 'unknown';
    }
  }

  /// Reads the platform display name (android:label / CFBundleDisplayName)
  /// rather than hardcoding it, so this keeps distinguishing "vaxishapp+"
  /// from the older "vaxishapp" app without a code change if either is ever
  /// renamed.
  Future<String> _getAppName() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.appName;
    } catch (e) {
      return 'unknown';
    }
  }
}
