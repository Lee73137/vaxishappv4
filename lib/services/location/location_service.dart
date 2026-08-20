import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../device_id_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static const String _baseUrl = 'http://shopapi.vaxilifecorp.com';

  /// Captures the device's current location and saves it to the server.
  /// Safe to call fire-and-forget from login/app-open flows: any failure
  /// (permission denied, GPS off, network error) is swallowed so it never
  /// blocks or breaks the login flow.
  Future<bool> captureAndSaveLocation(String username) async {
    if (username.isEmpty) return false;

    try {
      final position = await _getCurrentPosition();
      if (position == null) return false;

      final deviceId = await _getDeviceId();
      if (deviceId.isEmpty) return false;

      final url = Uri.parse('$_baseUrl/api/fcm/updatelocation');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username': username,
              'device_id': deviceId,
              'latitude': position.latitude,
              'longitude': position.longitude,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ Location updated for $username');
          return true;
        }
        debugPrint('❌ Location update API error: ${result['message']}');
        return false;
      }

      debugPrint('❌ Location update failed: HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ Error capturing/saving location: $e');
      return false;
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ Location services are disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Location permission not granted');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error getting current position: $e');
      return null;
    }
  }

  /// Shared with FcmTokenService via DeviceIdService, so both services
  /// always agree on the same device row server-side even when they run
  /// concurrently on a fresh install.
  Future<String> _getDeviceId() => DeviceIdService().getOrCreate();
}
