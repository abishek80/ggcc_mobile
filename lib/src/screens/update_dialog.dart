import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/version_check_service.dart';
import '../services/language_manager.dart';

class UpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback? onDismiss;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    this.onDismiss,
  });

  Future<void> _redirectToStore(BuildContext context) async {
    try {
      String urlString = updateInfo.updateUrl.trim();
      if (urlString.isEmpty) {
        urlString = 'https://play.google.com/store/apps/details?id=in.org.ggcc.mobile';
      }
      final Uri url = Uri.parse(urlString);

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Could not launch update URL: $e');
    }

    // For non-forced updates, dismiss the dialog when redirected to store
    if (!updateInfo.isForce && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _onDismiss(BuildContext context) {
    // Record that the user postponed/dismissed this version (non-forced)
    if (!updateInfo.isForce) {
      VersionCheckService.markVersionDismissed(updateInfo.latestVersion);
    }
    if (onDismiss != null) {
      onDismiss!();
    } else if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFC91115);

    return PopScope(
      // Prevent dismissing using the Android back button only if it's a critical/force update
      canPop: !updateInfo.isForce,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !updateInfo.isForce) {
          VersionCheckService.markVersionDismissed(updateInfo.latestVersion);
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  size: 40,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                LanguageManager.instance.translateSync(
                  updateInfo.isForce ? 'Critical Update Required' : 'New Update Available',
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              // Description
              Text(
                '${LanguageManager.instance.translateSync('A new version')} (${updateInfo.latestVersion}) ${LanguageManager.instance.translateSync('is available. Please update the app to proceed.')}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              // Release Notes (if present)
              if (updateInfo.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LanguageManager.instance.translateSync("What's New:"),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        updateInfo.releaseNotes,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Action Buttons
              Row(
                children: [
                  // Show "Not Now" button for non-forced/flexible update
                  if (!updateInfo.isForce) ...[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _onDismiss(context),
                        child: Text(
                          LanguageManager.instance.translateSync('Not Now'),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // Main Update Button
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => _redirectToStore(context),
                      child: Text(
                        LanguageManager.instance.translateSync('Update Now'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to show update dialog
void showAppUpdateDialog(BuildContext context, AppUpdateInfo updateInfo) {
  VersionCheckManager.instance.showDialogNow(context, updateInfo);
}
