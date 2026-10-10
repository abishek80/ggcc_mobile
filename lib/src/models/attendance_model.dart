class PresentItem {
  final String id;
  final String presentDate;
  final String employeeId;
  final String employeeName;
  final String presentDateFormat;
  final String designation;

  PresentItem({
    required this.id,
    required this.presentDate,
    required this.employeeId,
    required this.employeeName,
    required this.presentDateFormat,
    required this.designation,
  });

  factory PresentItem.fromJson(Map<String, dynamic> json) {
    return PresentItem(
      id: json['id']?.toString() ?? '',
      presentDate: json['present_date']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      employeeName: json['employee_name']?.toString() ?? '',
      presentDateFormat: json['present_dateFormat']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
    );
  }
}

class LeaveItem {
  final String id;
  final String leaveId;
  final String employeeId;
  final String leaveDate;
  final String reason;
  final String status;
  final String branch;
  final String zone;
  final String leaveDateFormat;

  LeaveItem({
    required this.id,
    required this.leaveId,
    required this.employeeId,
    required this.leaveDate,
    required this.reason,
    required this.status,
    required this.branch,
    required this.zone,
    required this.leaveDateFormat,
  });

  factory LeaveItem.fromJson(Map<String, dynamic> json) {
    return LeaveItem(
      id: json['id']?.toString() ?? '',
      leaveId: json['leave_id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      leaveDate: json['leave_date']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      branch: json['branch']?.toString() ?? '',
      zone: json['zone']?.toString() ?? '',
      leaveDateFormat: json['leave_dateFormat']?.toString() ?? '',
    );
  }
}

class OtItem {
  final String id;
  final String branchId;
  final String employeeId;
  final String otDate;
  final String workPlace;
  final String timeZone;
  final String otType;
  final String status;
  final String branch;
  final String zone;
  final String employeeName;
  final String designation;
  final String otDateFormat;

  OtItem({
    required this.id,
    required this.branchId,
    required this.employeeId,
    required this.otDate,
    required this.workPlace,
    required this.timeZone,
    required this.otType,
    required this.status,
    required this.branch,
    required this.zone,
    required this.employeeName,
    required this.designation,
    required this.otDateFormat,
  });

  factory OtItem.fromJson(Map<String, dynamic> json) {
    return OtItem(
      id: json['id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      otDate: json['ot_date']?.toString() ?? '',
      workPlace: json['work_place']?.toString() ?? '',
      timeZone: json['time_zone']?.toString() ?? '',
      otType: json['ot_type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      branch: json['branch']?.toString() ?? '',
      zone: json['zone']?.toString() ?? '',
      employeeName: json['employee_name']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      otDateFormat: json['ot_dateFormat']?.toString() ?? '',
    );
  }

  double get otValue {
    final type = otType.toLowerCase();
    if (type.contains('half')) {
      return 0.5;
    } else if (type.contains('full')) {
      return 1.0;
    }
    return 0.0;
  }
}
