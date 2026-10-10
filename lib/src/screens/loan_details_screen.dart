import 'package:flutter/material.dart';
import '../models/loan_model.dart';
import '../services/loan_service.dart';
import '../widgets/translated_text.dart';
import '../services/auth_service.dart';
import '../services/language_manager.dart';

class LoanDetailsScreen extends StatefulWidget {
  const LoanDetailsScreen({super.key});

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen> {
  final LoanService _loanService = LoanService();

  LoanDetailData? _loanData;
  bool _isLoading = true;
  String? _error;
  int _selectedLoanTab = 0; // 0 for Received List, 1 for Get Loan List

  @override
  void initState() {
    super.initState();
    _loadLoanDetails();
  }

  Future<void> _loadLoanDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _loanService.fetchLoanDetails();
      if (mounted) {
        setState(() {
          _loanData = data;
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
    return ListenableBuilder(
      listenable: LanguageManager.instance,
      builder: (context, _) {
        return Scaffold(
      appBar: AppBar(
        title: const TranslatedText(
          'Personal Loan Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: LanguageManager.instance.translateSync('Reload Loan Details'),
            onPressed: _loadLoanDetails,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadLoanDetails,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF181D50)))
              : _error != null
                  ? _buildErrorWidget()
                  : _loanData == null
                      ? _buildEmptyWidget()
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Employee Subheader Banner
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                                        _loanData!.employeeName,
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
                                        LanguageManager.instance.translateSync(_loanData!.designation),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1D4ED8),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 3 Summary Metric Cards (Loan Amount | Paid Amount | Balance Amount)
                              Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 12.0),
                                  child: Row(
                                    children: [
                                      _buildMetricColumn(
                                        label: 'Loan Amount',
                                        amount: _formatCurrency(_loanData!.overallLoanAmount),
                                        color: const Color(0xFF1E293B),
                                      ),
                                      Container(height: 40, width: 1, color: const Color(0xFFCBD5E1)),
                                      _buildMetricColumn(
                                        label: 'Paid Amount',
                                        amount: _formatCurrency(_loanData!.overallPaidAmount),
                                        color: const Color(0xFF16A34A),
                                      ),
                                      Container(height: 40, width: 1, color: const Color(0xFFCBD5E1)),
                                      _buildMetricColumn(
                                        label: 'Balance Amount',
                                        amount: _formatCurrency(_loanData!.overallBalanceAmount),
                                        color: const Color(0xFFDC2626),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Segmented Tab Selector
                              Row(
                                children: [
                                  Expanded(
                                    child: ChoiceChip(
                                      showCheckmark: false,
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                      label: Center(
                                        child: Text('${LanguageManager.instance.translateSync('Received List')} (${_loanData!.receivedList.length})'),
                                      ),
                                      selected: _selectedLoanTab == 0,
                                      selectedColor: const Color(0xFF181D50),
                                      labelStyle: TextStyle(
                                        color: _selectedLoanTab == 0 ? Colors.white : const Color(0xFF475569),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: _selectedLoanTab == 0 ? const Color(0xFF181D50) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      onSelected: (selected) {
                                        if (selected) setState(() => _selectedLoanTab = 0);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ChoiceChip(
                                      showCheckmark: false,
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                      label: Center(
                                        child: Text('${LanguageManager.instance.translateSync('Get Loan List')} (${_loanData!.loanList.length})'),
                                      ),
                                      selected: _selectedLoanTab == 1,
                                      selectedColor: const Color(0xFF181D50),
                                      labelStyle: TextStyle(
                                        color: _selectedLoanTab == 1 ? Colors.white : const Color(0xFF475569),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: _selectedLoanTab == 1 ? const Color(0xFF181D50) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      onSelected: (selected) {
                                        if (selected) setState(() => _selectedLoanTab = 1);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Active Table Content
                              if (_selectedLoanTab == 0)
                                _buildReceivedLoanListTable(_loanData!.receivedList)
                              else
                                _buildGetLoanListTable(_loanData!.loanList),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildMetricColumn({
    required String label,
    required String amount,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          TranslatedText(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGetLoanListTable(List<LoanItem> loans) {
    if (loans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const TranslatedText('No loan items found.'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Table(
          border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 1),
          columnWidths: const {
            0: FixedColumnWidth(48),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.0),
            3: FlexColumnWidth(1.8),
          },
          children: [
            // Header Row
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
              children: const [
                _TableCellHeader('S. No'),
                _TableCellHeader('Date'),
                _TableCellHeader('Amount'),
                _TableCellHeader('Remarks'),
              ],
            ),
            // Data Rows
            ...loans.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final item = entry.value;
              final isEven = idx % 2 == 0;

              return TableRow(
                decoration: BoxDecoration(
                  color: isEven ? const Color(0xFFFAFAFA) : Colors.white,
                ),
                children: [
                  _TableCellBody('$idx', align: TextAlign.center),
                  _TableCellBody(item.date),
                  _TableCellBody(_formatAmount(item.amount), isBold: true),
                  _TableCellBody(item.remarks.isEmpty ? '-' : item.remarks),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedLoanListTable(List<ReceivedLoanItem> receivedList) {
    if (receivedList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const TranslatedText('No received loan payments found.'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Table(
          border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 1),
          columnWidths: const {
            0: FixedColumnWidth(54),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1.2),
          },
          children: [
            // Header Row
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
              children: const [
                _TableCellHeader('S. No'),
                _TableCellHeader('Date'),
                _TableCellHeader('Amount'),
              ],
            ),
            // Data Rows
            ...receivedList.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final item = entry.value;
              final isEven = idx % 2 == 0;

              return TableRow(
                decoration: BoxDecoration(
                  color: isEven ? const Color(0xFFFAFAFA) : Colors.white,
                ),
                children: [
                  _TableCellBody('$idx', align: TextAlign.center),
                  _TableCellBody(item.date),
                  _TableCellBody(_formatAmount(item.amount), isBold: true, color: const Color(0xFF16A34A)),
                ],
              );
            }),
          ],
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
              'Could not load loan details',
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
              onPressed: _loadLoanDetails,
              icon: const Icon(Icons.refresh),
              label: const TranslatedText('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF181D50),
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
            Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF94A3B8), size: 48),
            SizedBox(height: 12),
            TranslatedText(
              'No loan details found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(String rawVal) {
    final double? numVal = double.tryParse(rawVal);
    if (numVal == null) return rawVal;
    return numVal.toStringAsFixed(2);
  }

  String _formatAmount(String rawVal) {
    final double? numVal = double.tryParse(rawVal);
    if (numVal == null) return rawVal;
    return numVal.toStringAsFixed(0);
  }
}

class _TableCellHeader extends StatelessWidget {
  final String text;
  const _TableCellHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: TranslatedText(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}

class _TableCellBody extends StatelessWidget {
  final String text;
  final TextAlign align;
  final bool isBold;
  final Color? color;

  const _TableCellBody(
    this.text, {
    this.align = TextAlign.left,
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? const Color(0xFF0F172A),
        ),
      ),
    );
  }
}
