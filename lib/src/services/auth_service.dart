import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/login_response.dart';
import '../models/user_model.dart';
import '../screens/login_screen.dart';
import 'language_manager.dart';
import 'api_config.dart';

class AuthService {
  static String get _baseUrl => '${ApiConfig.baseUrl}/login';
  
  // SharedPreferences keys
  static const String _keyToken = 'auth_token';
  static const String _keyTokenType = 'auth_token_type';
  static const String _keyExpiresAt = 'auth_expires_at';
  static const String _keyLoginTimestamp = 'auth_login_timestamp';
  static const String _keyUserJson = 'auth_user_json';

  // 6 hours session validity in milliseconds (6 * 60 * 60 * 1000)
  static const int _sessionDurationMs = 6 * 60 * 60 * 1000;

  Future<LoginResponseModel> login(String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username': username.trim(),
              'password': password.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final loginResponse = LoginResponseModel.fromJson(data);

        if (!loginResponse.isError && loginResponse.token != null) {
          await saveSession(loginResponse);
        }

        return loginResponse;
      } else {
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          return LoginResponseModel.fromJson(data);
        } catch (_) {
          return LoginResponseModel(
            isError: true,
            message: 'Server error (${response.statusCode}). Please try again.',
          );
        }
      }
    } catch (e) {
      debugPrint('Login API Exception: $e');
      if (e is TimeoutException) {
        return LoginResponseModel(
          isError: true,
          message: 'Connection timed out. Please check your internet connection.',
        );
      }
      return LoginResponseModel(
        isError: true,
        message: 'Network error. Please check your internet connection.',
      );
    }
  }

  /// Saves token, user profile, and current timestamp to SharedPreferences
  Future<void> saveSession(LoginResponseModel loginResponse) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (loginResponse.token != null) {
      await prefs.setString(_keyToken, loginResponse.token!);
    }
    if (loginResponse.tokenType != null) {
      await prefs.setString(_keyTokenType, loginResponse.tokenType!);
    }
    if (loginResponse.expiresAt != null) {
      await prefs.setString(_keyExpiresAt, loginResponse.expiresAt!);
    }
    
    // Store current login timestamp for 6-hour expiration validation
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_keyLoginTimestamp, nowMs);

    if (loginResponse.user != null) {
      final userJson = jsonEncode(loginResponse.user!.toJson());
      await prefs.setString(_keyUserJson, userJson);
    }
  }

  /// Checks if stored token exists and is within 6 hours of login
  /// Checks if stored token exists and is within 6 hours of login
  Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    final loginTimestamp = prefs.getInt(_keyLoginTimestamp);

    if (token == null || token.isEmpty) {
      return false;
    }

    if (loginTimestamp != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final elapsedMs = nowMs - loginTimestamp;

      // Check if 6 hours (21,600,000 ms) have passed
      if (elapsedMs >= _sessionDurationMs || elapsedMs < 0) {
        await logout();
        return false;
      }
    }

    return true;
  }

  /// Returns stored auth token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    if (token != null && token.isNotEmpty) {
      return token;
    }
    return null;
  }

  /// Returns remaining session duration in minutes
  Future<int> getRemainingSessionMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final loginTimestamp = prefs.getInt(_keyLoginTimestamp);
    if (loginTimestamp == null) return 0;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedMs = nowMs - loginTimestamp;
    final remainingMs = _sessionDurationMs - elapsedMs;

    if (remainingMs <= 0) return 0;
    return (remainingMs / (1000 * 60)).round();
  }

  /// Retrieves stored User profile
  Future<UserModel?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJsonStr = prefs.getString(_keyUserJson);
    if (userJsonStr == null || userJsonStr.isEmpty) return null;

    try {
      final Map<String, dynamic> userMap = jsonDecode(userJsonStr);
      return UserModel.fromJson(userMap);
    } catch (_) {
      return null;
    }
  }

  /// Updates only the profile image and name in the stored User profile
  Future<void> updateStoredUserImageAndName(String imageUrl, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final userJsonStr = prefs.getString(_keyUserJson);
    if (userJsonStr != null && userJsonStr.isNotEmpty) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(userJsonStr);
        userMap['profile_img'] = imageUrl;
        userMap['name'] = name;
        await prefs.setString(_keyUserJson, jsonEncode(userMap));
      } catch (_) {}
    }
  }

  /// Clears stored local session token and user profile
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyTokenType);
    await prefs.remove(_keyExpiresAt);
    await prefs.remove(_keyLoginTimestamp);
    await prefs.remove(_keyUserJson);
  }
}

void handleSessionExpired(BuildContext context) {
  AuthService().logout().then((_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LanguageManager.instance.translateSync('Session expired. Please log in again.')),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  });
}
