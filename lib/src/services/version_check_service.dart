import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import '../screens/update_dialog.dart';

class VersionCheckService {
  static const String _dismissedVersionKey = 'dismissed_update_version';

  static String get _baseUrl => '${ApiConfig.baseUrl}/check_version';

  /// Cleans a version string by stripping 'v'/'V' prefix, build metadata (+...),
  /// pre-release metadata (-...), and any non-numeric or non-dot characters.
  static String cleanVersion(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1).trim();
    }
    if (s.contains('+')) {
      s = s.split('+').first.trim();
    }
    if (s.contains('-')) {
      s = s.split('-').first.trim();
    }
    s = s.replaceAll(RegExp(r'[^0-9.]'), '');
    return s.isEmpty ? '0' : s;
  }

  /// Compares two version strings numerically segment-by-segment.
  /// Returns:
  ///   < 0 if v1 < v2
  ///     0 if v1 == v2
  ///   > 0 if v1 > v2
  static int compareVersions(String v1, String v2) {
    final clean1 = cleanVersion(v1);
    final clean2 = cleanVersion(v2);

    final parts1 = clean1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = clean2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (int i = 0; i < maxLen; i++) {
      final n1 = i < parts1.length ? parts1[i] : 0;
      final n2 = i < parts2.length ? parts2[i] : 0;
      if (n1 != n2) {
        return n1.compareTo(n2);
      }
    }
    return 0;
  }

  /// Fetches the actual installed app version dynamically from the platform.
  static Future<String> getInstalledVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return cleanVersion(packageInfo.version);
    } catch (e) {
      debugPrint('Error getting installed version: $e');
      return '1.0.0';
    }
  }

  /// Checks if the user previously dismissed this version (for non-forced updates).
  static Future<bool> isVersionDismissed(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedVersion = prefs.getString(_dismissedVersionKey);
      if (dismissedVersion == null || dismissedVersion.isEmpty) {
        return false;
      }
      return compareVersions(dismissedVersion, version) >= 0;
    } catch (_) {
      return false;
    }
  }

  /// Marks a specific version as dismissed by the user.
  static Future<void> markVersionDismissed(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedVersionKey, cleanVersion(version));
    } catch (_) {}
  }

  /// Clears any dismissed version flag (called once updated or reset).
  static Future<void> clearDismissedVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dismissedVersionKey);
    } catch (_) {}
  }

  /// Checks app version against the backend API and validates client-side.
  static Future<AppUpdateInfo?> checkAppVersion({bool ignoreDismissed = false}) async {
    try {
      // 1. Get current installed package version dynamically
      final installedVersion = await getInstalledVersion();

      // 2. Detect platform
      String platform = 'android';
      if (!kIsWeb && Platform.isIOS) {
        platform = 'ios';
      }

      // 3. Make API request with properly encoded query parameters
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'platform': platform,
        'current_version': installedVersion,
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['isError'] == false) {
          final String latestVersion = cleanVersion(data['latest_version']?.toString() ?? '');
          final bool isForce = data['is_force'] == 1 || data['is_force'] == true || data['is_force'] == '1';
          final String updateUrl = data['update_url']?.toString() ?? '';
          final String releaseNotes = data['release_notes']?.toString() ?? '';

          // 4. Client-side Version Validation:
          // Display the update popup only when installed version is strictly lower than latest version.
          final isLower = compareVersions(installedVersion, latestVersion) < 0;

          if (!isLower) {
            // Already updated or newer than dashboard version -> clear dismissal and do not show popup
            await clearDismissedVersion();
            return null;
          }

          // 5. For non-forced updates, do not show if the user already dismissed this version
          if (!isForce && !ignoreDismissed) {
            final dismissed = await isVersionDismissed(latestVersion);
            if (dismissed) {
              return null;
            }
          }

          return AppUpdateInfo(
            updateAvailable: true,
            installedVersion: installedVersion,
            latestVersion: latestVersion,
            isForce: isForce,
            updateUrl: updateUrl,
            releaseNotes: releaseNotes,
          );
        }
      }
    } catch (e) {
      debugPrint('Version check failed: $e');
    }
    return null;
  }
}

class AppUpdateInfo {
  final bool updateAvailable;
  final String installedVersion;
  final String latestVersion;
  final bool isForce;
  final String updateUrl;
  final String releaseNotes;

  AppUpdateInfo({
    required this.updateAvailable,
    required this.installedVersion,
    required this.latestVersion,
    required this.isForce,
    required this.updateUrl,
    required this.releaseNotes,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json, {String installedVersion = ''}) {
    return AppUpdateInfo(
      updateAvailable: json['update_available'] ?? false,
      installedVersion: installedVersion,
      latestVersion: VersionCheckService.cleanVersion(json['latest_version']?.toString() ?? ''),
      isForce: json['is_force'] == 1 || json['is_force'] == true || json['is_force'] == '1',
      updateUrl: json['update_url']?.toString() ?? '',
      releaseNotes: json['release_notes']?.toString() ?? '',
    );
  }
}

/// Global manager for update dialog presentation and app lifecycle handling.
class VersionCheckManager {
  VersionCheckManager._();
  static final VersionCheckManager instance = VersionCheckManager._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool isDialogOpen = false;
  String? currentlyPromptedVersion;
  BuildContext? _dialogContext;

  /// Trigger a version check and present the dialog if needed.
  Future<void> checkAndShowUpdate(BuildContext context, {bool isResume = false}) async {
    // On resume, if a dialog is already visible, check if app was updated while backgrounded
    if (isResume && isDialogOpen && currentlyPromptedVersion != null) {
      final installedVersion = await VersionCheckService.getInstalledVersion();
      if (VersionCheckService.compareVersions(installedVersion, currentlyPromptedVersion!) >= 0) {
        // App is now updated! Automatically dismiss/hide the update popup
        hideDialog();
        await VersionCheckService.clearDismissedVersion();
        return;
      }
    }

    if (isDialogOpen) {
      // Dialog already visible
      return;
    }

    final updateInfo = await VersionCheckService.checkAppVersion();
    if (updateInfo != null && updateInfo.updateAvailable) {
      final targetContext = navigatorKey.currentContext ?? context;
      if (!targetContext.mounted) return;
      showDialogNow(targetContext, updateInfo);
    }
  }

  void showDialogNow(BuildContext context, AppUpdateInfo updateInfo) {
    if (isDialogOpen) return;
    isDialogOpen = true;
    currentlyPromptedVersion = updateInfo.latestVersion;

    showDialog(
      context: context,
      barrierDismissible: !updateInfo.isForce,
      builder: (dialogCtx) {
        _dialogContext = dialogCtx;
        return UpdateDialog(
          updateInfo: updateInfo,
          onDismiss: () {
            hideDialog();
          },
        );
      },
    ).then((_) {
      isDialogOpen = false;
      _dialogContext = null;
      currentlyPromptedVersion = null;
    });
  }

  void hideDialog() {
    if (isDialogOpen) {
      if (_dialogContext != null && _dialogContext!.mounted) {
        Navigator.of(_dialogContext!).pop();
      } else if (navigatorKey.currentState != null && navigatorKey.currentState!.canPop()) {
        navigatorKey.currentState!.pop();
      }
      isDialogOpen = false;
      _dialogContext = null;
      currentlyPromptedVersion = null;
    }
  }

  /// Called when app transitions to AppLifecycleState.resumed.
  Future<void> handleAppResumed(BuildContext context) async {
    await checkAndShowUpdate(context, isResume: true);
  }
}
