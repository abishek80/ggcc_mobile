import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'api_config.dart';

class VersionCheckService {
  static String get _baseUrl => '${ApiConfig.baseUrl}/check_version';

  /// Model to represent update status
  static Future<AppUpdateInfo?> checkAppVersion() async {
    try {
      // 1. Get current package version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 2. Detect platform
      String platform = 'android';
      if (Platform.isIOS) {
        platform = 'ios';
      }

      // 3. Make API request
      final uri = Uri.parse('$_baseUrl?platform=$platform&current_version=$currentVersion');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['isError'] == false && data['update_available'] == true) {
          return AppUpdateInfo.fromJson(data);
        }
      }
    } catch (e) {
      // Return null on network or parse failure to avoid blocking app launch
      print('Version check failed: $e');
    }
    return null;
  }
}

class AppUpdateInfo {
  final bool updateAvailable;
  final String latestVersion;
  final bool isForce;
  final String updateUrl;
  final String releaseNotes;

  AppUpdateInfo({
    required this.updateAvailable,
    required this.latestVersion,
    required this.isForce,
    required this.updateUrl,
    required this.releaseNotes,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      updateAvailable: json['update_available'] ?? false,
      latestVersion: json['latest_version'] ?? '',
      // Map is_force from int (1/0) or bool
      isForce: json['is_force'] == 1 || json['is_force'] == true,
      updateUrl: json['update_url'] ?? '',
      releaseNotes: json['release_notes'] ?? '',
    );
  }
}
