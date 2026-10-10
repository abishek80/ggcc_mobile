import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_api_service.dart';
import '../services/auth_service.dart';
import '../widgets/translated_text.dart';
import '../services/language_manager.dart';
import 'payslips_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationApiService _notificationService = NotificationApiService();
  List<AppNotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  String? _extractMonth(String? inputMonth, String? text) {
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

  String? _extractYear(String? inputYear, String? text) {
    if (inputYear != null && inputYear.trim().isNotEmpty) {
      return inputYear.trim();
    }
    if (text == null || text.isEmpty) return null;
    final match = RegExp(r'\b(20\d{2})\b').firstMatch(text);
    return match?.group(1);
  }

  void _handleNotificationTap(AppNotificationItem notification) {
    _markSingleAsRead(notification);

    if (notification.isPayslip ||
        notification.notificationType == 'payslip' ||
        notification.title.toLowerCase().contains('payslip') ||
        notification.description.toLowerCase().contains('payslip')) {
      final month = _extractMonth(notification.payslipMonth, notification.description);
      final year = _extractYear(notification.payslipYear, notification.description);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PayslipsScreen(
            initialMonth: month,
            initialYear: year,
          ),
        ),
      );
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _notificationService.fetchNotifications();
      final List<dynamic> dataList = result['data'] ?? [];
      if (mounted) {
        setState(() {
          _notifications = dataList
              .map((item) => AppNotificationItem.fromJson(
                  item is Map<String, dynamic> ? item : {}))
              .toList();
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

  Future<void> _markAllAsRead() async {
    final success = await _notificationService.markAsRead();
    if (success && mounted) {
      setState(() {
        _notifications = _notifications.map((n) {
          return AppNotificationItem(
            id: n.id,
            title: n.title,
            description: n.description,
            notificationType: n.notificationType,
            targetEmployeeId: n.targetEmployeeId,
            payslipMonth: n.payslipMonth,
            payslipYear: n.payslipYear,
            isRead: true,
            createdAt: n.createdAt,
          );
        }).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageManager.instance
              .translateSync('All notifications marked as read')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markSingleAsRead(AppNotificationItem notification) async {
    if (notification.isRead) return;
    final success =
        await _notificationService.markAsRead(notificationId: notification.id);
    if (success && mounted) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = AppNotificationItem(
            id: notification.id,
            title: notification.title,
            description: notification.description,
            notificationType: notification.notificationType,
            targetEmployeeId: notification.targetEmployeeId,
            payslipMonth: notification.payslipMonth,
            payslipYear: notification.payslipYear,
            isRead: true,
            createdAt: notification.createdAt,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageManager.instance,
      builder: (context, _) {
        final unreadCount = _notifications.where((n) => !n.isRead).length;

        return Scaffold(
          appBar: AppBar(
            title: const TranslatedText(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            elevation: 0,
            actions: [
              if (unreadCount > 0)
                TextButton.icon(
                  onPressed: _markAllAsRead,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const TranslatedText('Mark All Read'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFC91115),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip:
                    LanguageManager.instance.translateSync('Reload Notifications'),
                onPressed: _loadNotifications,
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFC91115)))
                  : _error != null
                      ? _buildErrorWidget()
                      : _notifications.isEmpty
                          ? _buildEmptyWidget()
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16.0),
                              itemCount: _notifications.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _buildNotificationCard(
                                    _notifications[index]);
                              },
                            ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(AppNotificationItem notification) {
    final isPayslip = notification.isPayslip;
    final iconBgColor = isPayslip
        ? const Color(0xFFC91115).withValues(alpha: 0.1)
        : const Color(0xFF181D50).withValues(alpha: 0.1);
    final iconColor =
        isPayslip ? const Color(0xFFC91115) : const Color(0xFF181D50);
    final icon = isPayslip
        ? Icons.receipt_long_rounded
        : Icons.notifications_active_rounded;

    return Card(
      elevation: notification.isRead ? 0 : 2,
      shadowColor: notification.isRead ? Colors.transparent : Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: notification.isRead
              ? const Color(0xFFE2E8F0)
              : const Color(0xFFC91115).withValues(alpha: 0.3),
          width: notification.isRead ? 1 : 1.5,
        ),
      ),
      color: notification.isRead ? Colors.white : const Color(0xFFFFF5F5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleNotificationTap(notification),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFC91115),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          notification.timeAgo,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
              'Could not load notifications',
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
              onPressed: _loadNotifications,
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
            Icon(Icons.notifications_off_outlined,
                color: Color(0xFF94A3B8), size: 56),
            SizedBox(height: 16),
            TranslatedText(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
            ),
            SizedBox(height: 6),
            TranslatedText(
              'You will see notifications here when they arrive',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}
