import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/loan_model.dart';
import 'auth_service.dart';
import 'api_config.dart';

class LoanService {
  static String get _loanDetailUrl => '${ApiConfig.baseUrl}/loan/detail';
  final AuthService _authService = AuthService();

  Future<LoanDetailData> fetchLoanDetails() async {
    try {
      final token = await _authService.getToken();

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse(_loanDetailUrl),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);

        if (body['isError'] == false && body['data'] != null) {
          return LoanDetailData.fromJson(body['data'] as Map<String, dynamic>);
        } else {
          throw Exception(body['message'] ?? 'Failed to load loan details');
        }
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
