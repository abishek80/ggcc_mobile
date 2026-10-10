class AppNotificationItem {
  final String id;
  final String title;
  final String description;
  final String notificationType; // 'payslip' or 'custom'
  final String? targetEmployeeId;
  final String? payslipMonth;
  final String? payslipYear;
  final bool isRead;
  final String createdAt;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.notificationType,
    this.targetEmployeeId,
    this.payslipMonth,
    this.payslipYear,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      notificationType: json['notification_type']?.toString() ?? 'custom',
      targetEmployeeId: json['target_employee_id']?.toString(),
      payslipMonth: json['payslip_month']?.toString(),
      payslipYear: json['payslip_year']?.toString(),
      isRead: json['is_read'] == 1 || json['is_read'] == '1' || json['is_read'] == true,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  /// Returns a formatted time-ago string
  String get timeAgo {
    try {
      final date = DateTime.parse(createdAt);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 365) {
        return '${(diff.inDays / 365).floor()}y ago';
      } else if (diff.inDays > 30) {
        return '${(diff.inDays / 30).floor()}mo ago';
      } else if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (_) {
      return createdAt;
    }
  }

  bool get isPayslip => notificationType == 'payslip';
}
