import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  final String id;
  final String username;
  final String email;
  final String? repcode;
  final String? fullname;

  UserSession({
    required this.id,
    required this.username,
    required this.email,
    this.repcode,
    this.fullname,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: json['Id']?.toString() ?? '',
      username: json['UserName']?.toString() ?? '',
      email: json['Email']?.toString() ?? '',
      repcode: json['repcode']?.toString(),
      fullname: json['fullname']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'Id': id,
    'UserName': username,
    'Email': email,
    'repcode': repcode,
    'fullname': fullname,
  };
}

class AuthResult {
  final bool success;
  final String message;
  final UserSession? user;

  AuthResult({required this.success, required this.message, this.user});
}

class AuthService {
  static const String _baseUrl = 'http://shopapi.vaxilifecorp.com';
  static const String _prefsLoggedIn = 'auth_logged_in';
  static const String _prefsUserJson = 'auth_user_json';

  static const _timeout = Duration(seconds: 15);
  static const _networkErrorMessage =
      'Unable to reach the server. Please check your connection and try again.';

  static Future<AuthResult> login(String username, String password) async {
    final uri = Uri.parse(
      '$_baseUrl/api/vaxiauthenticate/authenticate/'
      '${Uri.encodeComponent(username)}/${Uri.encodeComponent(password)}',
    );

    try {
      final response = await http.get(uri).timeout(_timeout);
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>?;
        return AuthResult(
          success: true,
          message: body['message']?.toString() ?? 'Login successful!',
          user: data != null ? UserSession.fromJson(data) : null,
        );
      }

      return AuthResult(
        success: false,
        message: body['message']?.toString() ?? 'Invalid username or password',
      );
    } catch (_) {
      return AuthResult(success: false, message: _networkErrorMessage);
    }
  }

  /// Returns a masked email (e.g. j***n@example.com) for the given username,
  /// or null if there's no match / it can't be reached — callers should treat
  /// null as "don't show anything" rather than an error.
  static Future<String?> lookupMaskedEmail(String username) async {
    final uri = Uri.parse(
      '$_baseUrl/api/vaxiauthenticate/lookupemail/${Uri.encodeComponent(username)}',
    );

    try {
      final response = await http.get(uri).timeout(_timeout);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        return body['maskedEmail']?.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<AuthResult> forgotPassword(String username) async {
    final uri = Uri.parse('$_baseUrl/api/vaxiauthenticate/forgotpassword');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'Username': username}),
          )
          .timeout(_timeout);
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      return AuthResult(
        success: body['success'] == true,
        message:
            body['message']?.toString() ??
            'If that username exists and has an email on file, a password reset link has been sent to it.',
      );
    } catch (_) {
      return AuthResult(success: false, message: _networkErrorMessage);
    }
  }

  static Future<void> saveSession(UserSession user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsLoggedIn, true);
    await prefs.setString(_prefsUserJson, jsonEncode(user.toJson()));
  }

  static Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsLoggedIn) ?? false;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLoggedIn);
    await prefs.remove(_prefsUserJson);
  }

  /// Returns the persisted user from a previous [saveSession] call, or null
  /// if there isn't one (e.g. Remember Me wasn't checked at login).
  static Future<UserSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsUserJson);
    if (raw == null) return null;

    try {
      return UserSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
