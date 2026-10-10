import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/version_check_service.dart';
import '../services/language_manager.dart';

class UpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  Future<void> _redirectToStore() async {
    try {
      final Uri url = Uri.parse(updateInfo.updateUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback launch
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Could not launch update URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = const Color(0xFFC91115);
    final secondaryColor = const Color(0xFF181D50);

    return PopScope(
      // Prevent dismissing the dialog using the Android back button if it's a force update
      canPop: !updateInfo.isForce,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Do nothing for force updates
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
              // Beautiful Header Icon Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
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
                  // Show cancel button only if it's a flexible/soft update
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
                        onPressed: () => Navigator.of(context).pop(),
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
                      onPressed: _redirectToStore,
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
  showDialog(
    context: context,
    barrierDismissible: !updateInfo.isForce, // cannot dismiss clicking outside if force update
    builder: (BuildContext context) {
      return UpdateDialog(updateInfo: updateInfo);
    },
  );
}
