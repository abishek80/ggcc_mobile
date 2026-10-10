import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import '../widgets/translated_text.dart';
import '../services/auth_service.dart';
import '../services/language_manager.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  final AttendanceService _attendanceService = AttendanceService();
  late TabController _tabController;

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  final List<String> _years = List.generate(5, (index) => (2024 + index).toString());

  late String _selectedYear;
  late String _selectedMonth;

  List<PresentItem> _presentList = [];
  List<LeaveItem> _leaveList = [];
  List<OtItem> _otList = [];

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final now = DateTime.now();
    _selectedYear = _years.contains(now.year.toString()) ? now.year.toString() : '2026';
    _selectedMonth = _months[now.month - 1];

    _fetchAttendanceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get _currentMonthDaysCount {
    final monthIndex = _months.indexOf(_selectedMonth) + 1;
    final yearVal = int.tryParse(_selectedYear) ?? 2026;
    return _daysInMonth(yearVal, monthIndex);
  }

  int _daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeapYear = (year % 4 == 0) && (year % 100 != 0 || year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  Future<void> _fetchAttendanceData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _attendanceService.fetchPresentList(_selectedYear, _selectedMonth),
        _attendanceService.fetchLeaveList(_selectedYear, _selectedMonth),
        _attendanceService.fetchOtList(_selectedYear, _selectedMonth),
      ]);

      if (mounted) {
        setState(() {
          _presentList = results[0] as List<PresentItem>;
          _leaveList = results[1] as List<LeaveItem>;
          _otList = results[2] as List<OtItem>;
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

  double get _totalOtCount {
    return _otList.fold(0.0, (sum, item) => sum + item.otValue);
  }

  String _formatOtCount(double count) {
    if (count == count.roundToDouble()) {
      return count.round().toString();
    }
    return count.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: LanguageManager.instance,
      builder: (context, _) {
        return Scaffold(
      appBar: AppBar(
        title: const TranslatedText(
          'My Attendance',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: LanguageManager.instance.translateSync('Reload List'),
            onPressed: _fetchAttendanceData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Bar (Year and Month Dropdowns)
            _buildFilterBar(theme),

            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFC91115)),
                ),
              )
            else if (_error != null)
              Expanded(
                child: _buildErrorWidget(),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    // Metric Summary Cards
                    _buildMetricsSection(),
                    
                    // Tab Bar
                    _buildTabBar(theme),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPresentTab(),
                          _buildLeaveTab(),
                          _buildOtTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Year Dropdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TranslatedText(
                  'Select Year',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedYear,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      items: _years.map((year) {
                        return DropdownMenuItem(
                          value: year,
                          child: Text(year),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedYear = val;
                          });
                          _fetchAttendanceData();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Month Dropdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TranslatedText(
                  'Select Month',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMonth,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      items: _months.map((month) {
                        return DropdownMenuItem(
                          value: month,
                          child: Text(LanguageManager.instance.translateSync(month)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedMonth = val;
                          });
                          _fetchAttendanceData();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            children: [
              _buildMetricColumn('Month Days', _currentMonthDaysCount.toString(), const Color(0xFF0284C7)),
              _buildMetricDivider(),
              _buildMetricColumn('Present', _presentList.length.toString(), const Color(0xFF16A34A)),
              _buildMetricDivider(),
              _buildMetricColumn('Leave', _leaveList.length.toString(), const Color(0xFFD97706)),
              _buildMetricDivider(),
              _buildMetricColumn('Overtimes', _formatOtCount(_totalOtCount), const Color(0xFF181D50)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          TranslatedText(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      height: 36,
      width: 1,
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFC91115),
        labelColor: const Color(0xFFC91115),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: [
          Tab(text: '${LanguageManager.instance.translateSync('Presents')} (${_presentList.length})'),
          Tab(text: '${LanguageManager.instance.translateSync('Leaves')} (${_leaveList.length})'),
          Tab(text: '${LanguageManager.instance.translateSync('Overtimes')} (${_formatOtCount(_totalOtCount)})'),
        ],
      ),
    );
  }

  Widget _buildPresentTab() {
    if (_presentList.isEmpty) {
      return _buildEmptyState('No presence records found.');
    }

    return RefreshIndicator(
      onRefresh: _fetchAttendanceData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _presentList.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _presentList[index];
          return Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF16A34A),
                ),
              ),
              title: Text(
                item.presentDateFormat,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF0F172A),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '${item.employeeName} • ${LanguageManager.instance.translateSync(item.designation)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const TranslatedText(
                  'Present',
                  style: TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeaveTab() {
    if (_leaveList.isEmpty) {
      return _buildEmptyState('No leave records found.');
    }

    return RefreshIndicator(
      onRefresh: _fetchAttendanceData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _leaveList.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _leaveList[index];
          final isApproved = item.status.toLowerCase() == 'approved';

          return Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.leaveDateFormat,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF9C3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          LanguageManager.instance.translateSync(item.status.toUpperCase()),
                          style: TextStyle(
                            color: isApproved ? const Color(0xFF16A34A) : const Color(0xFFCA8A04),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${LanguageManager.instance.translateSync('Reason')}: ${item.reason}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        '${item.branch} (${item.zone})',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOtTab() {
    if (_otList.isEmpty) {
      return _buildEmptyState('No overtime records found.');
    }

    return RefreshIndicator(
      onRefresh: _fetchAttendanceData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _otList.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _otList[index];
          final isApproved = item.status.toLowerCase() == 'approved';

          return Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.otDateFormat,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              LanguageManager.instance.translateSync(item.otType),
                              style: const TextStyle(
                                color: Color(0xFF1D4ED8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF9C3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              LanguageManager.instance.translateSync(item.status.toUpperCase()),
                              style: TextStyle(
                                color: isApproved ? const Color(0xFF16A34A) : const Color(0xFFCA8A04),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(
                        child: TranslatedText(
                          'Work Place:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.workPlace,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Expanded(
                        child: TranslatedText(
                          'Time Zone:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.timeZone,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        '${item.branch} (${item.zone})',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            size: 48,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          Text(
            LanguageManager.instance.translateSync(message),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
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
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC2626),
              size: 52,
            ),
            const SizedBox(height: 14),
            const TranslatedText(
              'Could not load attendance data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchAttendanceData,
              icon: const Icon(Icons.refresh),
              label: const TranslatedText('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC91115),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
