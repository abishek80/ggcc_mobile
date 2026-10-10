import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/payslip_model.dart';
import 'auth_service.dart';
import 'api_config.dart';

class PayslipService {
  static String get _payslipListUrl => '${ApiConfig.baseUrl}/payslip/list';
  static String get _payslipPdfUrl => '${ApiConfig.baseUrl}/payslip/pdf';

  final AuthService _authService = AuthService();

  Future<List<EmployeePayslipData>> fetchPayslips() async {
    try {
      final token = await _authService.getToken();
      
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse(_payslipListUrl),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);

        if (body['isError'] == false && body['data'] != null) {
          final List<EmployeePayslipData> result = [];

          if (body['data'] is Map<String, dynamic>) {
            final Map<String, dynamic> dataMap = body['data'] as Map<String, dynamic>;
            dataMap.forEach((empId, empData) {
              if (empData is Map<String, dynamic>) {
                result.add(EmployeePayslipData.fromJson(empId, empData));
              }
            });
          }

          return result;
        } else {
          throw Exception(body['message'] ?? 'Failed to load payslips');
        }
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Uint8List> downloadPayslipPdf(String payslipId) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('$_payslipPdfUrl?id=$payslipId');

      final headers = <String, String>{
        'Accept': 'application/pdf',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        
        // Verify that the bytes start with the PDF magic header "%PDF" ([0x25, 0x50, 0x44, 0x46])
        if (bytes.length >= 4 &&
            bytes[0] == 0x25 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x44 &&
            bytes[3] == 0x46) {
          return bytes;
        }

        // If it's not a valid PDF, try to decode and extract error message
        String detail = '';
        try {
          final Map<String, dynamic> bodyMap = jsonDecode(utf8.decode(bytes));
          if (bodyMap['message'] != null) {
            detail = bodyMap['message'].toString();
          }
        } catch (_) {
          final textResponse = utf8.decode(bytes);
          if (textResponse.trim().startsWith('<!DOCTYPE html>') || textResponse.contains('<html')) {
            detail = 'Server returned HTML instead of PDF. This usually indicates that Dompdf is missing or failed on the server.';
          } else if (textResponse.isNotEmpty && textResponse.length < 150) {
            detail = textResponse.trim();
          }
        }

        throw Exception(detail.isNotEmpty ? detail : 'The downloaded file is not a valid PDF document.');
      } else {
        String detail = '';
        try {
          final Map<String, dynamic> bodyMap = jsonDecode(response.body);
          if (bodyMap['message'] != null) {
            detail = bodyMap['message'].toString();
          }
        } catch (_) {
          if (response.body.isNotEmpty && response.body.length < 150) {
            detail = response.body.trim();
          }
        }
        final msg = detail.isNotEmpty
            ? 'Failed to fetch PDF (Status: ${response.statusCode}) - $detail'
            : 'Failed to fetch PDF (Status: ${response.statusCode})';
        throw Exception(msg);
      }
    } catch (e) {
      rethrow;
    }
  }
}
