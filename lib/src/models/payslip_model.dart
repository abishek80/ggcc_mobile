class PayslipItem {
  final String id;
  final String month;
  final String year;

  PayslipItem({
    required this.id,
    required this.month,
    required this.year,
  });

  factory PayslipItem.fromJson(Map<String, dynamic> json) {
    return PayslipItem(
      id: json['id']?.toString() ?? '',
      month: json['month']?.toString() ?? '',
      year: json['year']?.toString() ?? '',
    );
  }

  String get formattedMonth {
    if (month.isEmpty) return '';
    return month[0].toUpperCase() + month.substring(1).toLowerCase();
  }
}

class EmployeePayslipData {
  final String employeeId;
  final String employeeName;
  final String designation;
  final Map<String, List<PayslipItem>> payslipsByYear;

  EmployeePayslipData({
    required this.employeeId,
    required this.employeeName,
    required this.designation,
    required this.payslipsByYear,
  });

  factory EmployeePayslipData.fromJson(String empId, Map<String, dynamic> json) {
    final Map<String, List<PayslipItem>> yearMap = {};

    if (json['payslip'] != null && json['payslip'] is Map<String, dynamic>) {
      final Map<String, dynamic> payslipYears = json['payslip'] as Map<String, dynamic>;

      payslipYears.forEach((year, monthsData) {
        if (monthsData is Map<String, dynamic>) {
          final List<PayslipItem> items = [];
          monthsData.forEach((month, itemData) {
            if (itemData is Map<String, dynamic>) {
              items.add(PayslipItem.fromJson(itemData));
            }
          });

          // Sort months order (January to December or reverse)
          const monthOrder = [
            'january', 'february', 'march', 'april', 'may', 'june',
            'july', 'august', 'september', 'october', 'november', 'december'
          ];

          items.sort((a, b) {
            final indexA = monthOrder.indexOf(a.month.toLowerCase());
            final indexB = monthOrder.indexOf(b.month.toLowerCase());
            if (indexA != -1 && indexB != -1) {
              return indexB.compareTo(indexA); // Recent month first
            }
            return a.month.compareTo(b.month);
          });

          yearMap[year] = items;
        }
      });
    }

    return EmployeePayslipData(
      employeeId: empId,
      employeeName: json['employee_name']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      payslipsByYear: yearMap,
    );
  }

  List<String> get availableYears {
    final sortedYears = payslipsByYear.keys.toList();
    sortedYears.sort((a, b) => b.compareTo(a)); // Descending: 2026, 2025, 2024
    return sortedYears;
  }
}
