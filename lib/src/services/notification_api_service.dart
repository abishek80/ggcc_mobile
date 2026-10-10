import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

class NotificationApiService {
  static String get _baseUrl => ApiConfig.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Fetch notifications for the logged-in user
  Future<Map<String, dynamic>> fetchNotifications({int page = 1, int limit = 20}) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/notification/list?page=$page&limit=$limit'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['isError'] == false) {
        return body;
      }
      throw Exception(body['message'] ?? 'Failed to load notifications');
    }
    throw Exception('Server returned status code ${response.statusCode}');
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/notification/unread-count'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['isError'] == false) {
        return body['count'] ?? 0;
      }
    }
    return 0;
  }

  /// Mark a notification as read (or all if id is null)
  Future<bool> markAsRead({String? notificationId}) async {
    final headers = await _getHeaders();
    final bodyData = <String, dynamic>{};
    if (notificationId != null) {
      bodyData['action'] = 'markRead';
      bodyData['notificationId'] = notificationId;
    } else {
      bodyData['action'] = 'markAllRead';
    }

    final response = await http.patch(
      Uri.parse('$_baseUrl/notifications'),
      headers: headers,
      body: jsonEncode(bodyData),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    return false;
  }

  /// Register FCM device token with the backend
  Future<bool> registerFcmToken(String fcmToken) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/fcm/register'),
      headers: headers,
      body: jsonEncode({'fcm_token': fcmToken}),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['isError'] == false;
    }
    return false;
  }
}
