import 'package:flutter/material.dart';
import '../models/payslip_model.dart';
import '../services/payslip_service.dart';
import 'payslip_pdf_viewer_screen.dart';
import '../widgets/translated_text.dart';
import '../services/auth_service.dart';
import '../services/language_manager.dart';

class PayslipsScreen extends StatefulWidget {
  final String? initialMonth;
  final String? initialYear;

  const PayslipsScreen({
    super.key,
    this.initialMonth,
    this.initialYear,
  });

  @override
  State<PayslipsScreen> createState() => _PayslipsScreenState();
}

class _PayslipsScreenState extends State<PayslipsScreen> {
  final PayslipService _payslipService = PayslipService();

  List<EmployeePayslipData> _payslipDataList = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedYear;

  @override
  void initState() {
    super.initState();
    _loadPayslips();
  }

  Future<void> _loadPayslips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _payslipService.fetchPayslips();
      if (mounted) {
        setState(() {
          _payslipDataList = list;
          _isLoading = false;

          if (list.isNotEmpty && list.first.availableYears.isNotEmpty) {
            final years = list.first.availableYears;
            if (widget.initialYear != null && years.contains(widget.initialYear)) {
              _selectedYear = widget.initialYear;
            } else {
              _selectedYear = years.first;
            }
          }
        });

        if (widget.initialMonth != null && _selectedYear != null && list.isNotEmpty) {
          final empData = list.first;
          final items = empData.payslipsByYear[_selectedYear] ?? [];
          final targetMonthLower = widget.initialMonth!.trim().toLowerCase();
          final matchingPayslip = items.cast<PayslipItem?>().firstWhere(
            (item) => item != null && item.month.toLowerCase() == targetMonthLower,
            orElse: () => null,
          );

          if (matchingPayslip != null && matchingPayslip.id.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _openPdfViewer(matchingPayslip);
              }
            });
          }
        }
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

  void _openPdfViewer(PayslipItem payslip) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PayslipPdfViewerScreen(
          payslipId: payslip.id,
          month: payslip.month,
          year: payslip.year,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageManager.instance,
      builder: (context, _) {
        return Scaffold(
      appBar: AppBar(
        title: const TranslatedText(
          'My Payslips',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: LanguageManager.instance.translateSync('Reload Payslips'),
            onPressed: _loadPayslips,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPayslips,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFC91115)))
              : _error != null
                  ? _buildErrorWidget()
                  : _payslipDataList.isEmpty
                      ? _buildEmptyWidget()
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Employee & Designation Banner
                              _buildEmployeeHeader(),
                              const SizedBox(height: 16),

                              // Year Selector Chips
                              _buildYearSelector(),
                              const SizedBox(height: 16),

                              // Payslip Cards List
                              _buildPayslipList(),
                            ],
                          ),
                        ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildEmployeeHeader() {
    final empData = _payslipDataList.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              empData.employeeName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Text(
              empData.designation,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1D4ED8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    final empData = _payslipDataList.first;
    final availableYears = empData.availableYears;
    _selectedYear ??= availableYears.first;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: availableYears.map((year) {
          final isSelected = year == _selectedYear;
          final count = empData.payslipsByYear[year]?.length ?? 0;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              showCheckmark: false,
              label: Text('$year ($count)'),
              selected: isSelected,
              selectedColor: const Color(0xFFC91115),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF475569),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              backgroundColor: const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFFC91115) : const Color(0xFFE2E8F0),
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedYear = year;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPayslipList() {
    final empData = _payslipDataList.first;
    final payslipsForYear = empData.payslipsByYear[_selectedYear] ?? [];

    if (payslipsForYear.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('${LanguageManager.instance.translateSync('No payslips available for year')} $_selectedYear'),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: payslipsForYear.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final payslip = payslipsForYear[index];
        return _buildPayslipCard(payslip);
      },
    );
  }

  Widget _buildPayslipCard(PayslipItem payslip) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openPdfViewer(payslip),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              // Month Icon Badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFC91115).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFFC91115),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${LanguageManager.instance.translateSync(payslip.formattedMonth)} ${payslip.year}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Payslip ID: #${payslip.id}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              // View Action Button
              IconButton(
                onPressed: () => _openPdfViewer(payslip),
                icon: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFF181D50),
                ),
                tooltip: LanguageManager.instance.translateSync('View PDF Payslip'),
              ),
            ],
          ),
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
              'Could not load payslips',
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
              onPressed: _loadPayslips,
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

  Widget _buildEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.receipt_long_outlined, color: Color(0xFF94A3B8), size: 48),
            SizedBox(height: 12),
            TranslatedText(
              'No payslip records found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
