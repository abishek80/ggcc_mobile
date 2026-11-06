/// Attendance status values accepted/returned by the branch-attendance API.
class BranchStatus {
  static const String none = '';
  static const String present = 'present';
  static const String absent = 'absent';
}

/// OT values accepted/returned by the branch-attendance API (exact casing).
class BranchOt {
  static const String none = '';
  static const String halfDay = 'Half Day';
  static const String fullDay = 'Full Day';
}

int _toInt(dynamic v) => v is int ? v : (int.tryParse(v?.toString() ?? '') ?? 0);

double _toDouble(dynamic v) =>
    v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0.0);

String _toStr(dynamic v) => v?.toString().trim() ?? '';

// ---------------------------------------------------------------------------
// GET api/branch-attendance/day
// ---------------------------------------------------------------------------

class BranchDayEmployee {
  final int employeeId;
  final String employeeName;
  final String designation;
  final String status; // '' | present | absent
  final String otType; // '' | Half Day | Full Day

  BranchDayEmployee({
    required this.employeeId,
    required this.employeeName,
    required this.designation,
    required this.status,
    required this.otType,
  });

  factory BranchDayEmployee.fromJson(Map<String, dynamic> json) {
    // Server sends one combined value: ''|present|absent|half_day_ot|full_day_ot.
    // Split it back into the (status, otType) pair this model exposes.
    final value = _toStr(json['value']).toLowerCase();
    String status = BranchStatus.none;
    String ot = BranchOt.none;
    switch (value) {
      case 'present':
        status = BranchStatus.present;
      case 'absent':
        status = BranchStatus.absent;
      case 'half_day_ot':
        status = BranchStatus.present;
        ot = BranchOt.halfDay;
      case 'full_day_ot':
        status = BranchStatus.present;
        ot = BranchOt.fullDay;
    }
    return BranchDayEmployee(
      employeeId: _toInt(json['employee_id']),
      employeeName: _toStr(json['employee_name']),
      designation: _toStr(json['designation']),
      status: status,
      otType: ot,
    );
  }
}

class BranchDayData {
  final String date;
  final String zone;
  final String branchName;
  final List<BranchDayEmployee> employees;

  BranchDayData({
    required this.date,
    required this.zone,
    required this.branchName,
    required this.employees,
  });

  factory BranchDayData.fromJson(Map<String, dynamic> json) {
    final list = (json['employees'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(BranchDayEmployee.fromJson)
        .toList();
    return BranchDayData(
      date: _toStr(json['date']),
      zone: _toStr(json['zone']),
      branchName: _toStr(json['branch_name']),
      employees: list,
    );
  }
}

// ---------------------------------------------------------------------------
// GET api/branch-attendance/month
// ---------------------------------------------------------------------------

class BranchMonthEmployee {
  final int employeeId;
  final String employeeName;
  final String designation;
  final String zone;
  final String branch;
  final int presentCount;
  final int leaveCount;
  final double otCount;

  /// Day-of-month -> status string ("P", "A", "Half OT", "Full OT",
  /// "P/Half OT" ...). Missing key = nothing marked.
  final Map<int, String> dailyAttendance;

  BranchMonthEmployee({
    required this.employeeId,
    required this.employeeName,
    required this.designation,
    required this.zone,
    required this.branch,
    required this.presentCount,
    required this.leaveCount,
    required this.otCount,
    required this.dailyAttendance,
  });

  factory BranchMonthEmployee.fromJson(Map<String, dynamic> json) {
    final daily = <int, String>{};
    final raw = json['daily_attendance'];
    // An empty PHP array serialises as `[]`, so accept a List as "no data".
    if (raw is Map) {
      raw.forEach((k, v) {
        final day = int.tryParse(k.toString());
        final value = _toStr(v);
        if (day != null && value.isNotEmpty) daily[day] = value;
      });
    }
    return BranchMonthEmployee(
      employeeId: _toInt(json['employee_id']),
      employeeName: _toStr(json['employee_name']),
      designation: _toStr(json['designation']),
      zone: _toStr(json['zone']),
      branch: _toStr(json['branch']),
      presentCount: _toInt(json['present_count']),
      leaveCount: _toInt(json['leave_count']),
      otCount: _toDouble(json['ot_count']),
      dailyAttendance: daily,
    );
  }
}

class BranchMonthData {
  final String year;
  final String month;
  final int daysInMonth;
  final String zone;
  final String branchName;
  final List<BranchMonthEmployee> employees;

  BranchMonthData({
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.zone,
    required this.branchName,
    required this.employees,
  });

  factory BranchMonthData.fromJson(Map<String, dynamic> json) {
    final list = (json['employees'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(BranchMonthEmployee.fromJson)
        .toList();

    // Zone/branch of the *incharge* come from GET /day. Do not derive them from
    // the employee rows: added employees may belong to other branches.
    return BranchMonthData(
      year: _toStr(json['year']),
      month: _toStr(json['month']),
      daysInMonth: _toInt(json['days_in_month']),
      zone: _toStr(json['zone']),
      branchName: _toStr(json['branch_name']),
      employees: list,
    );
  }
}

// ---------------------------------------------------------------------------
// GET api/branch-attendance/search-employee
// ---------------------------------------------------------------------------

class BranchEmployeeSearchResult {
  final int id;
  final String name;
  final String designation;

  BranchEmployeeSearchResult({
    required this.id,
    required this.name,
    required this.designation,
  });

  factory BranchEmployeeSearchResult.fromJson(Map<String, dynamic> json) {
    return BranchEmployeeSearchResult(
      // API returns id as a string ("52"); cast so it can be sent back to `mark`.
      id: _toInt(json['id']),
      name: _toStr(json['value']),
      designation: _toStr(json['designation']),
    );
  }
}

// ---------------------------------------------------------------------------
// POST api/branch-attendance/mark
// ---------------------------------------------------------------------------

class BranchMarkEntry {
  final int employeeId;
  final String attendanceType; // '' | present | absent
  final String otType; // '' | Half Day | Full Day

  BranchMarkEntry({
    required this.employeeId,
    required this.attendanceType,
    required this.otType,
  });

  /// Combines (attendanceType, otType) into the single value the server
  /// expects: ''|present|absent|half_day_ot|full_day_ot.
  Map<String, dynamic> toJson() {
    String value = '';
    if (attendanceType == BranchStatus.present) {
      if (otType == BranchOt.halfDay) {
        value = 'half_day_ot';
      } else if (otType == BranchOt.fullDay) {
        value = 'full_day_ot';
      } else {
        value = BranchStatus.present;
      }
    } else if (attendanceType == BranchStatus.absent) {
      value = BranchStatus.absent;
    }
    return {
      'employee_id': employeeId,
      'value': value,
    };
  }
}
