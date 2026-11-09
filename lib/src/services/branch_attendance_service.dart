import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/branch_attendance_model.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'language_manager.dart';

/// Generic, user-presentable failure from the branch-attendance API.
class BranchAttendanceException implements Exception {
  final String message;
  BranchAttendanceException(this.message);

  @override
  String toString() => message;
}

/// HTTP 401 - token missing/expired.
class BranchUnauthorizedException extends BranchAttendanceException {
  BranchUnauthorizedException() : super('Session expired');
}

/// HTTP 403 - "Access denied. You are not an active Branch Incharge."
class BranchForbiddenException extends BranchAttendanceException {
  BranchForbiddenException(super.message);
}

String branchErrorMessage(Object e) {
  if (e is BranchAttendanceException) return e.message;
  return e.toString().replaceAll('Exception: ', '');
}

/// Shared handler for the two auth-related failures. Returns true when [e] was
/// handled (caller should stop). Call only while [context] is still mounted.
///
/// - 401: same behaviour as every other screen (log out -> login).
/// - 403: user is no longer an active incharge -> hide the feature for good
///   (clear the stored flag) and drop back to the dashboard.
bool handleBranchAttendanceAuthError(BuildContext context, Object e) {
  if (e is BranchUnauthorizedException) {
    handleSessionExpired(context);
    return true;
  }
  if (e is BranchForbiddenException) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    AuthService().setStoredBranchIncharge(false).then((_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(LanguageManager.instance.translateSync(e.message)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      navigator.popUntil((route) => route.isFirst);
    });
    return true;
  }
  return false;
}

class BranchAttendanceService {
  static String get _baseUrl => '${ApiConfig.baseUrl}/branch-attendance';
  static const Duration _timeout = Duration(seconds: 30);

  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await _authService.getToken();
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Validates status code + `isError`, returns the decoded body.
  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}
    final serverMessage = body?['message']?.toString();

    if (response.statusCode == 401) throw BranchUnauthorizedException();
    if (response.statusCode == 403) {
      throw BranchForbiddenException(
        serverMessage ?? 'Access denied. You are not an active Branch Incharge.',
      );
    }
    if (response.statusCode != 200 || body == null) {
      throw BranchAttendanceException(
        serverMessage ?? 'Server returned status code ${response.statusCode}',
      );
    }
    if (body['isError'] != false) {
      throw BranchAttendanceException(serverMessage ?? 'Request failed');
    }
    return body;
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on TimeoutException {
      throw BranchAttendanceException(
          'Connection timed out. Please check your internet connection.');
    } on http.ClientException {
      throw BranchAttendanceException(
          'Network error. Please check your internet connection.');
    }
  }

  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// GET /day?date=YYYY-MM-DD
  Future<BranchDayData> fetchDay(DateTime date) => _guard(() async {
        final uri = Uri.parse('$_baseUrl/day')
            .replace(queryParameters: {'date': formatDate(date)});
        final response =
            await http.get(uri, headers: await _headers()).timeout(_timeout);
        final body = _decode(response);
        return BranchDayData.fromJson(body['data'] as Map<String, dynamic>);
      });

  /// GET /month?year=2026&month=november  (full lowercase English month name)
  Future<BranchMonthData> fetchMonth(int year, String monthName) =>
      _guard(() async {
        final uri = Uri.parse('$_baseUrl/month').replace(queryParameters: {
          'year': year.toString(),
          'month': monthName.toLowerCase(),
        });
        final response =
            await http.get(uri, headers: await _headers()).timeout(_timeout);
        if (kDebugMode) debugPrint('[BranchAttendance] month: ${response.body}');
        final body = _decode(response);
        return BranchMonthData.fromJson(body['data'] as Map<String, dynamic>);
      });

  /// GET /search-employee?q=...
  Future<List<BranchEmployeeSearchResult>> searchEmployees(String query) =>
      _guard(() async {
        final uri = Uri.parse('$_baseUrl/search-employee')
            .replace(queryParameters: {'q': query});
        final response =
            await http.get(uri, headers: await _headers()).timeout(_timeout);
        final body = _decode(response);
        final list = body['data'] as List<dynamic>? ?? [];
        return list
            .whereType<Map<String, dynamic>>()
            .map(BranchEmployeeSearchResult.fromJson)
            .where((r) => r.id > 0)
            .toList();
      });

  /// POST /mark - returns the server's success message.
  Future<String> markAttendance(
    DateTime date,
    List<BranchMarkEntry> entries,
  ) =>
      _guard(() async {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/mark'),
              headers: await _headers(json: true),
              body: jsonEncode({
                'date': formatDate(date),
                'entries': entries.map((e) => e.toJson()).toList(),
              }),
            )
            .timeout(_timeout);
        if (kDebugMode) debugPrint('[BranchAttendance] mark: ${response.body}');
        final body = _decode(response);
        return body['message']?.toString() ?? 'Attendance saved.';
      });
}
