import 'package:flutter_test/flutter_test.dart';
import 'package:ggcc_mobile/src/models/branch_attendance_model.dart';
import 'package:ggcc_mobile/src/models/user_model.dart';
import 'package:ggcc_mobile/src/services/branch_attendance_service.dart';

void main() {
  test('UserModel parses is_branch_incharge strictly and round-trips', () {
    UserModel u(dynamic v) => UserModel.fromJson({
          'id': 1,
          if (v != 'absent') 'is_branch_incharge': v,
        });
    expect(u(true).isBranchIncharge, isTrue);
    expect(u(1).isBranchIncharge, isTrue);
    expect(u('1').isBranchIncharge, isTrue);
    expect(u(false).isBranchIncharge, isFalse);
    expect(u(0).isBranchIncharge, isFalse);
    expect(u(null).isBranchIncharge, isFalse);
    expect(u('absent').isBranchIncharge, isFalse); // old cached sessions
    expect(UserModel.fromJson(u(true).toJson()).isBranchIncharge, isTrue);
  });

  test('day payload: combined value maps back to status + OT', () {
    final d = BranchDayData.fromJson({
      'date': '2026-11-03',
      'zone': 'chennai',
      'branch_name': 'Coimbatore',
      'employees': [
        {'employee_id': 3, 'employee_name': 'A', 'designation': 'M', 'value': 'full_day_ot'},
        {'employee_id': 4, 'employee_name': 'B', 'designation': 'M', 'value': 'half_day_ot'},
        {'employee_id': 5, 'employee_name': 'C', 'designation': 'M', 'value': 'present'},
        {'employee_id': 18, 'employee_name': 'D', 'designation': 'T', 'value': 'absent'},
        {'employee_id': 17, 'employee_name': 'E', 'designation': 'D', 'value': ''},
      ],
    });
    final e = d.employees;
    expect([e[0].status, e[0].otType], ['present', 'Full Day']);
    expect([e[1].status, e[1].otType], ['present', 'Half Day']);
    expect([e[2].status, e[2].otType], ['present', '']);
    expect([e[3].status, e[3].otType], ['absent', '']);
    expect([e[4].status, e[4].otType], ['', '']);
  });

  test('month payload: map keys, empty-array daily_attendance', () {
    final m = BranchMonthData.fromJson({
      'year': '2026',
      'month': 'november',
      'days_in_month': 30,
      'employees': [
        {
          'employee_id': 3, 'employee_name': 'A', 'designation': 'M',
          'zone': 'chennai', 'branch': 'Chennai',
          'present_count': 1, 'leave_count': 0, 'ot_count': 0.5,
          'daily_attendance': {'3': 'P/Full OT'},
        },
        {'employee_id': 4, 'employee_name': 'B', 'daily_attendance': []},
      ],
    });
    expect(m.employees[0].dailyAttendance[3], 'P/Full OT');
    expect(m.employees[0].otCount, 0.5);
    expect(m.employees[1].dailyAttendance, isEmpty);
  });

  test('search id string is cast to int', () {
    final r = BranchEmployeeSearchResult.fromJson(
        {'id': '52', 'value': 'Amin Kumar', 'designation': 'Asst Technician'});
    expect(r.id, 52);
    expect(r.name, 'Amin Kumar');
  });

  test('mark entry sends the single combined value', () {
    Map<String, dynamic> j(String t, String ot) =>
        BranchMarkEntry(employeeId: 3, attendanceType: t, otType: ot).toJson();
    expect(j('present', ''), {'employee_id': 3, 'value': 'present'});
    expect(j('present', 'Half Day'), {'employee_id': 3, 'value': 'half_day_ot'});
    expect(j('present', 'Full Day'), {'employee_id': 3, 'value': 'full_day_ot'});
    expect(j('absent', 'Half Day'), {'employee_id': 3, 'value': 'absent'});
    expect(j('', ''), {'employee_id': 3, 'value': ''});
  });

  test('date formatting', () {
    expect(BranchAttendanceService.formatDate(DateTime(2026, 11, 3)), '2026-11-03');
  });
}
