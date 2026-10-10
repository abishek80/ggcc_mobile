class LoanItem {
  final String id;
  final String employeeId;
  final String date;
  final String amount;
  final String remarks;

  LoanItem({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.amount,
    required this.remarks,
  });

  factory LoanItem.fromJson(Map<String, dynamic> json) {
    return LoanItem(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      date: json['advancecash_date']?.toString() ?? '',
      amount: json['advancecash_amount']?.toString() ?? '0',
      remarks: json['remarks']?.toString() ?? '',
    );
  }
}

class ReceivedLoanItem {
  final String id;
  final String employeeId;
  final String date;
  final String amount;

  ReceivedLoanItem({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.amount,
  });

  factory ReceivedLoanItem.fromJson(Map<String, dynamic> json) {
    return ReceivedLoanItem(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      date: json['received_date']?.toString() ?? '',
      amount: json['received_amount']?.toString() ?? '0',
    );
  }
}

class LoanDetailData {
  final String employeeId;
  final String employeeName;
  final String designation;
  final String overallLoanAmount;
  final String overallPaidAmount;
  final String overallBalanceAmount;
  final List<LoanItem> loanList;
  final List<ReceivedLoanItem> receivedList;

  LoanDetailData({
    required this.employeeId,
    required this.employeeName,
    required this.designation,
    required this.overallLoanAmount,
    required this.overallPaidAmount,
    required this.overallBalanceAmount,
    required this.loanList,
    required this.receivedList,
  });

  factory LoanDetailData.fromJson(Map<String, dynamic> json) {
    final List<LoanItem> loans = [];
    if (json['loan_list'] != null && json['loan_list'] is List) {
      for (var item in json['loan_list']) {
        if (item is Map<String, dynamic>) {
          loans.add(LoanItem.fromJson(item));
        }
      }
    }

    final List<ReceivedLoanItem> received = [];
    if (json['received_list'] != null && json['received_list'] is List) {
      for (var item in json['received_list']) {
        if (item is Map<String, dynamic>) {
          received.add(ReceivedLoanItem.fromJson(item));
        }
      }
    }

    return LoanDetailData(
      employeeId: json['employee_id']?.toString() ?? '',
      employeeName: json['employee_name']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      overallLoanAmount: json['overall_loan_amount']?.toString() ?? '0.00',
      overallPaidAmount: json['overall_paid_amount']?.toString() ?? '0.00',
      overallBalanceAmount: json['overall_balance_amount']?.toString() ?? '0.00',
      loanList: loans,
      receivedList: received,
    );
  }
}
