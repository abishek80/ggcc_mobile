import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/language_manager.dart';
import '../widgets/translated_text.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();

  UserProfileData? _profileData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _profileService.fetchProfile();
      try {
        await AuthService().updateStoredUserImageAndName(
          data.personalDetails.employeePhoto,
          data.employeeName,
        );
      } catch (_) {}
      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        if (!mounted) return;
        handleSessionExpired(context);
        return;
      }
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText(
          'My Profile Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: LanguageManager.instance.translateSync('Reload Profile'),
            onPressed: _loadProfile,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFC91115)))
              : _error != null
                  ? _buildErrorWidget()
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Profile Card
                          _buildProfileHeaderCard(),
                          const SizedBox(height: 16),

                          // Language Selection Card
                          _buildLanguageSelectorCard(),
                          const SizedBox(height: 20),

                          // 1. Employment Information Section
                          _buildSectionCard(
                            title: 'Employment Information',
                            icon: Icons.work_outline_rounded,
                            iconColor: const Color(0xFFC91115),
                            children: [
                              _buildInfoRow('Employee Code', _profileData!.employeeCode),
                              _buildInfoRow('Login Code', _profileData!.loginCode),
                              _buildInfoRow('Permission', _profileData!.permission.toUpperCase()),
                              _buildInfoRow('Company Name', _profileData!.companyName.toUpperCase()),
                              _buildInfoRow('Payslip Location', _profileData!.payslipLocation),
                              _buildInfoRow('Zone', _profileData!.zone.toUpperCase()),
                              _buildInfoRow('Branch', _profileData!.branchName.isNotEmpty ? _profileData!.branchName : 'Branch ${_profileData!.branch}'),
                              _buildInfoRow('Designation', _profileData!.designation),
                              _buildInfoRow('Date of Joining', _profileData!.dojFormatted.isNotEmpty ? _profileData!.dojFormatted : _profileData!.doj),
                              _buildInfoRow('Payslip Status', _profileData!.payslipStatus.toUpperCase()),
                              _buildInfoRow('Basic Pay', '₹${_profileData!.basicPay}'),
                              _buildInfoRow('Allowance Amount', '₹${_profileData!.allowanceAmount}'),
                              _buildInfoRow('Mobile Recharge', '₹${_profileData!.mobileRecharge}'),
                              _buildInfoRow('ESI Status', _profileData!.esiStatus.toUpperCase()),
                              _buildInfoRow('ESI Number', _profileData!.esiNumber),
                              _buildInfoRow('PF Status', _profileData!.pfStatus.toUpperCase()),
                              _buildInfoRow('PF Number', _profileData!.pfNumber),
                              _buildInfoRow('PF Amount', '₹${_profileData!.pfAmount}'),
                              _buildInfoRow('PAN Number', _profileData!.panNumber, fileUrl: _profileData!.pancardImg, fileName: 'PAN Card'),
                              _buildInfoRow('Aadhar Number', _profileData!.aadharNumber, fileUrl: _profileData!.aadharcardImg, fileName: 'Aadhar Card'),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 2. Bank Details Section
                          _buildSectionCard(
                            title: 'Bank Details',
                            icon: Icons.account_balance_rounded,
                            iconColor: const Color(0xFF181D50),
                            children: [
                              _buildInfoRow('Account Number', _profileData!.bankDetails.accountNumber),
                              _buildInfoRow('IFSC Code', _profileData!.bankDetails.ifscCode),
                              _buildInfoRow('Bank Name', _profileData!.bankDetails.bankName),
                              _buildInfoRow('Branch Name', _profileData!.bankDetails.bankBranchName),
                              _buildInfoRow('Status', _profileData!.bankDetails.status.toUpperCase(), isStatus: true),
                              if (_profileData!.bankDetails.bankbookImg.isNotEmpty)
                                _buildInfoRow(
                                  'Bankbook Copy',
                                  'View Document',
                                  fileUrl: _profileData!.bankDetails.bankbookImg,
                                  fileName: 'Bank Passbook',
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 3. Personal Details Section
                          _buildSectionCard(
                            title: 'Personal Details',
                            icon: Icons.person_outline_rounded,
                            iconColor: const Color(0xFF0284C7),
                            children: [
                              _buildInfoRow('Date of Birth', _profileData!.personalDetails.dobFormatted.isNotEmpty ? _profileData!.personalDetails.dobFormatted : _profileData!.personalDetails.dob),
                              _buildInfoRow('Education', _profileData!.personalDetails.education),
                              _buildInfoRow('Full Address', _profileData!.personalDetails.fullAddress),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 4. Contact Details Section
                          _buildSectionCard(
                            title: 'Emergency Contact Details',
                            icon: Icons.contact_phone_outlined,
                            iconColor: const Color(0xFF16A34A),
                            children: [
                              _buildInfoRow('Relative Type', _profileData!.contactDetails.relativeType),
                              _buildInfoRow('Contact Person', _profileData!.contactDetails.contactPersonName),
                              _buildInfoRow('Phone Number', _profileData!.contactDetails.contactPersonPhoneNumber),
                              _buildInfoRow('Contact Address', _profileData!.contactDetails.fullContactAddress),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 5. Licence & Additional Information
                          if (_profileData!.licenceNumber.isNotEmpty || _profileData!.electricalLicence.isNotEmpty)
                            _buildSectionCard(
                              title: 'Licence & Statutory Details',
                              icon: Icons.badge_outlined,
                              iconColor: const Color(0xFFD97706),
                              children: [
                                if (_profileData!.licenceNumber.isNotEmpty)
                                  _buildInfoRow(
                                    'Licence Number',
                                    _profileData!.licenceNumber,
                                    fileUrl: _profileData!.licenceImg,
                                    fileName: 'Driving Licence',
                                  ),
                                if (_profileData!.electricalLicence.isNotEmpty)
                                  _buildInfoRow(
                                    'Electrical Licence',
                                    _profileData!.electricalLicence,
                                    fileUrl: _profileData!.electricalLicenceImg,
                                    fileName: 'Electrical Licence',
                                  ),
                              ],
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelectorCard() {
    return ListenableBuilder(
      listenable: LanguageManager.instance,
      builder: (context, _) {
        final currentLanguage = LanguageManager.instance.currentLanguageCode;
        final isDownloading = LanguageManager.instance.isDownloadingModel;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.translate, color: Color(0xFFC91115)),
                    SizedBox(width: 10),
                    Text(
                      'App Language / भाषा / மொழி',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isDownloading)
                  const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFC91115),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Downloading translation pack. Please wait...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: currentLanguage,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFC91115)),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'en',
                        child: Text('English'),
                      ),
                      DropdownMenuItem(
                        value: 'hi',
                        child: Text('Hindi (हिन्दी)'),
                      ),
                      DropdownMenuItem(
                        value: 'ta',
                        child: Text('Tamil (தமிழ்)'),
                      ),
                    ],
                    onChanged: (val) async {
                      if (val != null) {
                        final success = await LanguageManager.instance.setLanguage(val);
                        if (!success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(LanguageManager.instance.translateSync('Failed to load language pack. Check your connection.')),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeaderCard() {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildAvatar(
                imageUrl: _profileData?.personalDetails.employeePhoto ?? '',
                name: _profileData?.employeeName ?? 'E',
                radius: 38,
              ),
              const SizedBox(height: 14),
              Text(
                _profileData!.employeeName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${LanguageManager.instance.translateSync(_profileData!.designation)} • ${_profileData!.employeeCode}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_profileData!.personalDetails.employeePhoto.isNotEmpty) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => _previewFile(
                    _profileData!.personalDetails.employeePhoto,
                    'Profile Photo',
                  ),
                  icon: const Icon(Icons.photo_outlined, size: 16, color: Color(0xFFC91115)),
                  label: const TranslatedText(
                    'View Profile Photo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC91115),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildBadgeChip(
                    label: _profileData!.companyName.toUpperCase(),
                    bgColor: const Color(0xFFC91115).withValues(alpha: 0.1),
                    textColor: const Color(0xFFC91115),
                  ),
                  _buildBadgeChip(
                    label: _profileData!.branchName.isNotEmpty ? _profileData!.branchName : 'Branch ${_profileData!.branch}',
                    bgColor: const Color(0xFF181D50).withValues(alpha: 0.1),
                    textColor: const Color(0xFF181D50),
                  ),
                  if (_profileData!.mobileNumber.isNotEmpty)
                    _buildBadgeChip(
                      label: _profileData!.mobileNumber,
                      bgColor: const Color(0xFFF1F5F9),
                      textColor: const Color(0xFF334155),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeChip({
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                TranslatedText(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    ),
  );
}

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isStatus = false,
    String? fileUrl,
    String? fileName,
  }) {
    final displayVal = value.trim().isNotEmpty ? value.trim() : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: TranslatedText(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: isStatus
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: displayVal == 'ACTIVE' || displayVal == 'YES'
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TranslatedText(
                        displayVal,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: displayVal == 'ACTIVE' || displayVal == 'YES'
                              ? const Color(0xFF15803D)
                              : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          LanguageManager.instance.translateSync(displayVal),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (fileUrl != null && fileUrl.trim().isNotEmpty) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFFC91115)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: LanguageManager.instance.translateSync('View Document'),
                          onPressed: () => _previewFile(fileUrl, fileName ?? label),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({
    required String imageUrl,
    required String name,
    required double radius,
    Color backgroundColor = const Color(0xFFC91115),
  }) {
    if (imageUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: backgroundColor == Colors.white ? const Color(0xFFC91115) : Colors.white,
          ),
        ),
      );
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: radius,
                height: radius,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: backgroundColor == Colors.white ? const Color(0xFFC91115) : Colors.white,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.bold,
                  color: backgroundColor == Colors.white ? const Color(0xFFC91115) : Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 48),
            const SizedBox(height: 12),
            const TranslatedText(
              'Could not load profile details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              label: const TranslatedText('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC91115),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previewFile(String url, String title) {
    if (url.isEmpty) return;

    final cleanUrl = url.trim();
    final lowerUrl = cleanUrl.toLowerCase();

    if (lowerUrl.endsWith('.pdf')) {
      _showPdfPreviewDialog(cleanUrl, title);
    } else if (lowerUrl.endsWith('.doc') || lowerUrl.endsWith('.docx')) {
      _showWordDocPreviewDialog(cleanUrl, title);
    } else {
      _showImagePreviewDialog(cleanUrl, title);
    }
  }

  void _showImagePreviewDialog(String url, String title) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.share_rounded),
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(
                          uri: Uri.parse(url),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(color: Color(0xFFC91115)),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    url,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPdfPreviewDialog(String url, String title) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _PdfPreviewLoader(url: url, title: title),
          ),
        );
      },
    );
  }

  void _showWordDocPreviewDialog(String url, String title) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined, size: 52, color: Color(0xFF1D4ED8)),
              const SizedBox(height: 16),
              const Text(
                'Inline preview is not supported for Word documents. You can open the file in your browser or share the link.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              SelectableText(
                url,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const TranslatedText('Cancel'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
            ),
            TextButton.icon(
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(LanguageManager.instance.translateSync('Could not open document link'))),
                    );
                  }
                }
              },
              icon: const Icon(Icons.open_in_browser_rounded, size: 18),
              label: const TranslatedText('Open'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFC91115)),
            ),
            TextButton.icon(
              onPressed: () {
                SharePlus.instance.share(
                  ShareParams(
                    text: url,
                    subject: title,
                  ),
                );
              },
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const TranslatedText('Share'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF181D50)),
            ),
          ],
        );
      },
    );
  }
}

class _PdfPreviewLoader extends StatefulWidget {
  final String url;
  final String title;

  const _PdfPreviewLoader({required this.url, required this.title});

  @override
  State<_PdfPreviewLoader> createState() => _PdfPreviewLoaderState();
}

class _PdfPreviewLoaderState extends State<_PdfPreviewLoader> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPdf();
  }

  Future<void> _fetchPdf() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode == 200) {
        setState(() {
          _pdfBytes = response.bodyBytes;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load document (Status: ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            if (_pdfBytes != null)
              IconButton(
                icon: const Icon(Icons.share_rounded),
                onPressed: () => Printing.sharePdf(
                  bytes: _pdfBytes!,
                  filename: '${widget.title.replaceAll(' ', '_')}.pdf',
                ),
              ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFC91115)))
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            SelectableText(
                              widget.url,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  : PdfPreview(
                      build: (format) => _pdfBytes!,
                      initialPageFormat: PdfPageFormat.a4,
                      pageFormats: const {'A4': PdfPageFormat.a4},
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                      allowPrinting: true,
                      allowSharing: false,
                      useActions: false,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    ),
        ),
      ],
    );
  }
}
