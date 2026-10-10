import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../services/auth_service.dart';
import '../services/payslip_service.dart';
import '../services/language_manager.dart';
import '../widgets/translated_text.dart';
import 'login_screen.dart';

class PayslipPdfViewerScreen extends StatefulWidget {
  final String payslipId;
  final String month;
  final String year;

  const PayslipPdfViewerScreen({
    super.key,
    required this.payslipId,
    required this.month,
    required this.year,
  });

  @override
  State<PayslipPdfViewerScreen> createState() => _PayslipPdfViewerScreenState();
}

class _PayslipPdfViewerScreenState extends State<PayslipPdfViewerScreen> {
  final PayslipService _payslipService = PayslipService();
  final AuthService _authService = AuthService();
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bytes = await _payslipService.downloadPayslipPdf(widget.payslipId);
      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleReLogin() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfBytes == null) return;
    try {
      await Printing.sharePdf(
        bytes: _pdfBytes!,
        filename: 'Payslip_${widget.month}_${widget.year}_#${widget.payslipId}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LanguageManager.instance.translateSync('Failed to share PDF')}: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleMonth = widget.month.isNotEmpty
        ? widget.month[0].toUpperCase() + widget.month.substring(1).toLowerCase()
        : widget.month;

    final isTokenError = _error != null &&
        (_error!.contains('401') ||
            _error!.toLowerCase().contains('expired') ||
            _error!.toLowerCase().contains('login'));

    return ListenableBuilder(
      listenable: LanguageManager.instance,
      builder: (context, _) {
        return Scaffold(
      appBar: AppBar(
        title: Text(
          '${LanguageManager.instance.translateSync(titleMonth)} ${widget.year} ${LanguageManager.instance.translateSync('Payslip')}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        actions: [
          if (_pdfBytes != null)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: LanguageManager.instance.translateSync('Share / Save PDF'),
              onPressed: _sharePdf,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: LanguageManager.instance.translateSync('Reload PDF'),
            onPressed: _loadPdf,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Color(0xFFC91115)),
                  SizedBox(height: 16),
                  TranslatedText(
                    'Loading Payslip Document...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isTokenError ? Icons.lock_clock_outlined : Icons.error_outline_rounded,
                          color: const Color(0xFFDC2626),
                          size: 52,
                        ),
                        const SizedBox(height: 14),
                        TranslatedText(
                          isTokenError ? 'Session Expired' : 'Could not load PDF document',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        if (isTokenError) ...[
                          ElevatedButton.icon(
                            onPressed: _handleReLogin,
                            icon: const Icon(Icons.login_rounded),
                            label: const TranslatedText('Login Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC91115),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ] else ...[
                          ElevatedButton.icon(
                            onPressed: _loadPdf,
                            icon: const Icon(Icons.refresh),
                            label: const TranslatedText('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC91115),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
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
                  allowPrinting: false,
                  allowSharing: false,
                  useActions: false,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  pdfPreviewPageDecoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  pdfFileName: 'Payslip_${widget.month}_${widget.year}_#${widget.payslipId}.pdf',
                ),
    );
      },
    );
  }
}
