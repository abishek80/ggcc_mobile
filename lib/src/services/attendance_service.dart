import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/attendance_model.dart';
import 'auth_service.dart';
import 'api_config.dart';

class AttendanceService {
  static String get _baseUrl => '${ApiConfig.baseUrl}/attendance';
  final AuthService _authService = AuthService();

  /// Fetches present list for a given year and month
  Future<List<PresentItem>> fetchPresentList(String year, String month) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('$_baseUrl/present?year=$year&month=${month.toLowerCase()}');

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);

        if (body['isError'] == false && body['data'] != null) {
          final List<dynamic> listData = body['data'];
          return listData.map((item) => PresentItem.fromJson(item)).toList();
        } else {
          throw Exception(body['message'] ?? 'Failed to load present list');
        }
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches leave list for a given year and month
  Future<List<LeaveItem>> fetchLeaveList(String year, String month) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('$_baseUrl/leave?year=$year&month=${month.toLowerCase()}');

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);

        if (body['isError'] == false && body['data'] != null) {
          final List<dynamic> listData = body['data'];
          return listData.map((item) => LeaveItem.fromJson(item)).toList();
        } else {
          throw Exception(body['message'] ?? 'Failed to load leave list');
        }
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches OT list for a given year and month
  Future<List<OtItem>> fetchOtList(String year, String month) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('$_baseUrl/ot?year=$year&month=${month.toLowerCase()}');

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);

        if (body['isError'] == false && body['data'] != null) {
          final List<dynamic> listData = body['data'];
          return listData.map((item) => OtItem.fromJson(item)).toList();
        } else {
          throw Exception(body['message'] ?? 'Failed to load OT list');
        }
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
