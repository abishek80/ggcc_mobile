import 'dart:async';
import 'package:flutter/material.dart';
import '../models/loan_model.dart';
import '../models/payslip_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/loan_service.dart';
import '../services/payslip_service.dart';
import '../services/profile_service.dart';
import '../services/notification_api_service.dart';
import '../services/firebase_notification_service.dart';
import 'login_screen.dart';
import 'loan_details_screen.dart';
import 'payslips_screen.dart';
import 'payslip_pdf_viewer_screen.dart';
import 'profile_screen.dart';
import 'attendance_screen.dart';
import 'notifications_screen.dart';
import '../services/attendance_service.dart';
import '../models/attendance_model.dart';
import '../widgets/translated_text.dart';
import '../services/language_manager.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();
  final _payslipService = PayslipService();
  final _loanService = LoanService();
  final _notificationApiService = NotificationApiService();

  UserModel? _user;
  bool _isLoadingSession = true;
  Timer? _timer;

  // Payslip Data State
  List<EmployeePayslipData> _payslipDataList = [];
  bool _isPayslipLoading = false;
  String? _payslipError;
  String? _selectedYear;

  // Loan Data State
  LoanDetailData? _loanData;
  bool _isLoanLoading = false;
  String? _loanError;
  int _selectedLoanTab = 0; // 0 for Received List, 1 for Get Loan List

  // Notification Badge State
  int _unreadNotificationCount = 0;

  // Current Month Attendance State
  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  final _attendanceService = AttendanceService();
  int _currentMonthDays = 0;
  int _currentPresentCount = 0;
  int _currentAbsentCount = 0;
  double _currentOtCount = 0.0;
  bool _isAttendanceLoading = true;
  String? _attendanceError;


  @override
  void initState() {
    super.initState();
    _loadSessionData();
    _loadPayslips();
    _loadLoanDetails();
    _loadCurrentMonthAttendance();
    _loadUnreadNotificationCount();
    _registerFcmToken();

    // Update session timer every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateRemainingTime();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    final isValid = await _authService.isSessionValid();
    if (!isValid) {
      if (mounted) {
        _navigateToLogin();
      }
      return;
    }

    final user = await _authService.getStoredUser();

    if (mounted) {
      setState(() {
        _user = user;
        _isLoadingSession = false;
      });
    }

    // Proactively fetch fresh profile in background to update cache (name, profile image)
    try {
      final profileData = await ProfileService().fetchProfile();
      await _authService.updateStoredUserImageAndName(
        profileData.personalDetails.employeePhoto,
        profileData.employeeName,
      );
      final updatedUser = await _authService.getStoredUser();
      if (mounted) {
        setState(() {
          _user = updatedUser;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCurrentMonthAttendance() async {
    setState(() {
      _isAttendanceLoading = true;
      _attendanceError = null;
    });

    final now = DateTime.now();
    final year = now.year.toString();
    final month = _months[now.month - 1];

    _currentMonthDays = _daysInMonth(now.year, now.month);

    try {
      final results = await Future.wait([
        _attendanceService.fetchPresentList(year, month),
        _attendanceService.fetchLeaveList(year, month),
        _attendanceService.fetchOtList(year, month),
      ]);

      final presents = results[0] as List<PresentItem>;
      final leaves = results[1] as List<LeaveItem>;
      final ots = results[2] as List<OtItem>;

      if (mounted) {
        setState(() {
          _currentPresentCount = presents.length;
          _currentAbsentCount = leaves.length;
          _currentOtCount = ots.fold(0.0, (sum, item) => sum + item.otValue);
          _isAttendanceLoading = false;
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
          _attendanceError = e.toString().replaceAll('Exception: ', '');
          _isAttendanceLoading = false;
        });
      }
    }
  }

  int _daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeapYear = (year % 4 == 0) && (year % 100 != 0 || year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  Future<void> _loadPayslips() async {
    setState(() {
      _isPayslipLoading = true;
      _payslipError = null;
    });

    try {
      final list = await _payslipService.fetchPayslips();
      if (mounted) {
        setState(() {
          _payslipDataList = list;
          _isPayslipLoading = false;

          if (list.isNotEmpty && list.first.availableYears.isNotEmpty) {
            _selectedYear = list.first.availableYears.first;
          }
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
          _payslipError = e.toString().replaceAll('Exception: ', '');
          _isPayslipLoading = false;
        });
      }
    }
  }

  Future<void> _loadLoanDetails() async {
    setState(() {
      _isLoanLoading = true;
      _loanError = null;
    });

    try {
      final data = await _loanService.fetchLoanDetails();
      if (mounted) {
        setState(() {
          _loanData = data;
          _isLoanLoading = false;
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
          _loanError = e.toString().replaceAll('Exception: ', '');
          _isLoanLoading = false;
        });
      }
    }
  }

  Future<void> _updateRemainingTime() async {
    final remainingMins = await _authService.getRemainingSessionMinutes();
    if (remainingMins <= 0) {
      await _authService.logout();
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final count = await _notificationApiService.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    } catch (_) {}
  }

  String? _extractMonthFromText(String? inputMonth, String? text) {
    if (inputMonth != null && inputMonth.trim().isNotEmpty) {
      return inputMonth.trim();
    }
    if (text == null || text.isEmpty) return null;
    const months = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december'
    ];
    final lower = text.toLowerCase();
    for (final m in months) {
      if (lower.contains(m)) {
        return m;
      }
    }
    return null;
  }

  String? _extractYearFromText(String? inputYear, String? text) {
    if (inputYear != null && inputYear.trim().isNotEmpty) {
      return inputYear.trim();
    }
    if (text == null || text.isEmpty) return null;
    final match = RegExp(r'\b(20\d{2})\b').firstMatch(text);
    return match?.group(1);
  }

  Future<void> _registerFcmToken() async {
    try {
      // Ensure permission is granted and token is obtained
      await FirebaseNotificationService().requestPermission();

      // Configure notification tap action
      FirebaseNotificationService().onNotificationTap = (message) {
        if (!mounted) return;
        final data = message.data;
        final title = message.notification?.title ?? data['title'] ?? data['Title'] ?? '';
        final body = message.notification?.body ?? data['body'] ?? data['Body'] ?? data['message'] ?? data['description'] ?? '';
        final type = data['notification_type'] ?? data['type'] ?? '';

        if (type == 'payslip' || title.toLowerCase().contains('payslip') || body.toLowerCase().contains('payslip')) {
          final month = _extractMonthFromText(data['payslip_month'], body);
          final year = _extractYearFromText(data['payslip_year'], body);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PayslipsScreen(
                initialMonth: month,
                initialYear: year,
              ),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        }
      };

      final fcmToken = FirebaseNotificationService().fcmToken;
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _notificationApiService.registerFcmToken(fcmToken);
        debugPrint('[FCM] Token registered with backend: $fcmToken');
      } else {
        debugPrint('[FCM] Token is null, could not register');
      }
    } catch (e) {
      debugPrint('[FCM] Error registering token: $e');
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFC91115)),
              SizedBox(width: 10),
              Expanded(
                child: TranslatedText(
                  'Confirm Logout',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          content: const TranslatedText(
            'Are you sure you want to log out of your account?',
            style: TextStyle(fontSize: 15, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
              ),
              child: const TranslatedText('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC91115),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const TranslatedText('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _authService.logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageManager.instance.translateSync('Logged out successfully')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _navigateToLogin();
      }
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
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
    final theme = Theme.of(context);

    if (_isLoadingSession) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return ListenableBuilder(
      listenable: LanguageManager.instance,
      builder: (context, _) {
        return Scaffold(
      appBar: AppBar(
        title: const TranslatedText(
          'GGCC Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          // Notification Bell with Badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: LanguageManager.instance.translateSync('Notifications'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ).then((_) => _loadUnreadNotificationCount());
                },
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFC91115),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      _unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: LanguageManager.instance.translateSync('Refresh All'),
            onPressed: () {
              _loadSessionData();
              _loadPayslips();
              _loadLoanDetails();
              _loadCurrentMonthAttendance();
              _loadUnreadNotificationCount();
            },
          ), 
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildAppDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadSessionData();
            await _loadPayslips();
            await _loadLoanDetails();
            await _loadCurrentMonthAttendance();
            await _loadUnreadNotificationCount();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Profile Header Card
                _buildUserProfileCard(theme),
                const SizedBox(height: 16),

                // Current Month Attendance Card
                _buildCurrentMonthAttendanceCard(theme),
                const SizedBox(height: 24),

                // Payslips Overview Header Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC91115).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: Color(0xFFC91115),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Flexible(
                            child: TranslatedText(
                              'My Payslips',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PayslipsScreen()),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const TranslatedText('View All'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFC91115),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Payslips Content Block
                _buildPayslipsContent(theme),
                const SizedBox(height: 28),

                // Personal Loan Detail Overview Header Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF181D50).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Color(0xFF181D50),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Flexible(
                            child: TranslatedText(
                              'Your Personal Loan Detail',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          if (_isLoanLoading) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoanDetailsScreen()),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const TranslatedText('View All'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF181D50),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Personal Loan Detail Section (Matching Image 2)
                _buildLoanDetailSection(theme),
                const SizedBox(height: 24),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout),
                    label: const TranslatedText('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        );
      },
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

  Widget _buildAppDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFC91115), Color(0xFF181D50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: Text(
              _user?.name ?? 'User Profile',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(
              _user?.designation.isNotEmpty == true
                  ? '${_user!.designation} • ${_user?.loginCode ?? "-"}'
                  : '${_user?.loginCode ?? "-"} • ${_user?.mobile ?? "-"}',
            ),
            currentAccountPicture: _buildAvatar(
              imageUrl: _user?.profileImg ?? '',
              name: _user?.name ?? 'U',
              radius: 36,
              backgroundColor: Colors.white,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_rounded, color: Color(0xFFC91115)),
            title: const TranslatedText('Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_rounded, color: Color(0xFFD97706)),
            title: const TranslatedText('Attendance', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AttendanceScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7)),
            title: const TranslatedText('My Payslip', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PayslipsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF16A34A)),
            title: const TranslatedText('Loan Details', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoanDetailsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded, color: Color(0xFF181D50)),
            title: const TranslatedText('My Profile', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const TranslatedText('Logout', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              _handleLogout();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileCard(ThemeData theme) {
    final subtitleText = _user?.designation.isNotEmpty == true
        ? '${_user!.designation}  •  ${_user?.loginCode ?? "-"}  •  ${_user?.mobile ?? "-"}'
        : '${_user?.loginCode ?? "-"}  •  ${_user?.mobile ?? "-"}';

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              _buildAvatar(
                imageUrl: _user?.profileImg ?? '',
                name: _user?.name ?? 'U',
                radius: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user?.name ?? 'User',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Personal Loan Detail Section matching Image 2
  Widget _buildLoanDetailSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loanError != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Failed to load loan details: $_loanError',
                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadLoanDetails,
                ),
              ],
            ),
          )
        else if (_loanData != null) ...[

          // 3 Metric Summary Cards (Loan Amount | Paid Amount | Balance Amount)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
              child: Row(
                children: [
                  _buildLoanMetricColumn(
                    label: 'Loan Amount',
                    amount: _formatCurrency(_loanData!.overallLoanAmount),
                    color: const Color(0xFF1E293B),
                  ),
                  Container(height: 40, width: 1, color: const Color(0xFFCBD5E1)),
                  _buildLoanMetricColumn(
                    label: 'Paid Amount',
                    amount: _formatCurrency(_loanData!.overallPaidAmount),
                    color: const Color(0xFF16A34A),
                  ),
                  Container(height: 40, width: 1, color: const Color(0xFFCBD5E1)),
                  _buildLoanMetricColumn(
                    label: 'Balance Amount',
                    amount: _formatCurrency(_loanData!.overallBalanceAmount),
                    color: const Color(0xFFDC2626),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Loan Lists Segmented Tab Selector
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
          const SizedBox(height: 12),

          // Active Table Content
          if (_selectedLoanTab == 0)
            _buildReceivedLoanListTable(_loanData!.receivedList)
          else
            _buildGetLoanListTable(_loanData!.loanList),
        ],
      ],
    );
  }

  Widget _buildLoanMetricColumn({
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

  Widget _buildPayslipsContent(ThemeData theme) {
    if (_isPayslipLoading && _payslipDataList.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_payslipError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Failed to load payslips: $_payslipError',
                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadPayslips,
              icon: const Icon(Icons.refresh, size: 16),
              label: const TranslatedText('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }

    if (_payslipDataList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const TranslatedText('No payslip records found'),
      );
    }

    final empData = _payslipDataList.first;
    final availableYears = empData.availableYears;

    if (availableYears.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: TranslatedText('No payslip years available.'),
      );
    }

    _selectedYear ??= availableYears.first;

    final payslipsForYear = empData.payslipsByYear[_selectedYear] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Year Selector Chips
        SingleChildScrollView(
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
        ),
        const SizedBox(height: 16),

        // Payslips Cards List
        if (payslipsForYear.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${LanguageManager.instance.translateSync('No payslips available for year')} $_selectedYear'),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: payslipsForYear.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final payslip = payslipsForYear[index];
              return _buildPayslipCard(payslip);
            },
          ),
      ],
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
              // Calendar Month Icon Badge
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

              // Month & Year Details
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

              // Download / View Action Button
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

  String _formatOtCount(double count) {
    if (count == count.roundToDouble()) {
      return count.round().toString();
    }
    return count.toStringAsFixed(1);
  }

  Widget _buildCurrentMonthAttendanceCard(ThemeData theme) {
    final now = DateTime.now();
    final monthName = _months[now.month - 1];
    final yearName = now.year.toString();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AttendanceScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFFD97706),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$monthName $yearName Attendance',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (_isAttendanceLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(color: Color(0xFFC91115)),
                  ),
                )
              else if (_attendanceError != null)
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error: $_attendanceError',
                        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: _loadCurrentMonthAttendance,
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    _buildMetricColumn('Month Days', _currentMonthDays.toString(), const Color(0xFF0284C7)),
                    _buildMetricDivider(),
                    _buildMetricColumn('Present', _currentPresentCount.toString(), const Color(0xFF16A34A)),
                    _buildMetricDivider(),
                    _buildMetricColumn('Leave', _currentAbsentCount.toString(), const Color(0xFFDC2626)),
                    _buildMetricDivider(),
                    _buildMetricColumn('Overtimes', _formatOtCount(_currentOtCount), const Color(0xFF181D50)),
                  ],
                ),
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
