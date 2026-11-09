import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggcc_mobile/src/screens/branch_attendance_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Client _mockApi(int employeeCount) {
  return MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/branch-attendance/month')) {
      final employees = List.generate(employeeCount, (i) {
        return {
          'employee_id': i + 1,
          'employee_name': 'Employee Number ${i + 1} Longname',
          'designation': 'Asst Technician',
          'zone': 'chennai',
          'branch': 'Cochin',
          'present_count': 2,
          'leave_count': i == 1 ? 1 : 0,
          'ot_count': i == 1 ? 0.25 : 0,
          'daily_attendance': i == 0
              ? {'3': 'P', '4': 'Half OT', '5': 'Full OT', '6': 'A'}
              : <String, String>{},
        };
      });
      return http.Response(
        jsonEncode({
          'isError': false,
          'data': {
            'year': '2026',
            'month': 'november',
            'days_in_month': 30,
            'zone': 'chennai',
            'branch_name': 'Coimbatore',
            'employees': employees,
          },
        }),
        200,
      );
    }
    // /day (header lookup)
    return http.Response(
      jsonEncode({
        'isError': false,
        'data': {
          'date': '2026-11-07',
          'zone': 'chennai',
          'branch_name': 'Coimbatore',
          'employees': [],
        },
      }),
      200,
    );
  });
}

void main() {
  testWidgets('only Sunday rows are highlighted', (tester) async {
    SharedPreferences.setMockInitialValues({'flutter.auth_token': 'x'});
    tester.view.physicalSize = const Size(390 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const employees = 3;
    final now = DateTime.now();
    final sundays = [
      for (var d = 1; d <= 30; d++)
        if (DateTime(now.year, now.month, d).weekday == DateTime.sunday) d
    ].length;

    int countColored(Color color) => tester
        .widgetList<Container>(find.byType(Container))
        .where((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == color)
        .length;

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: BranchAttendanceScreen()));
      await tester.pumpAndSettle();

      // Body cells are built lazily only within the viewport's scroll extent,
      // but the grid builds every row, so counts are exact.
      // Date cell + one cell per employee, per Sunday, all the same colour.
      // The pinned OT totals row happens to use the same colour, so it adds
      // one label cell + one cell per employee.
      const otFooterCells = employees + 1;
      expect(countColored(const Color(0xFFEFF6FF)),
          sundays * (employees + 1) + otFooterCells,
          reason: 'whole Sunday row tinted');
    }, () => _mockApi(employees));
  });

  for (final count in [4, 12]) {
    testWidgets('month grid renders with $count employees, no overflow', (tester) async {
      SharedPreferences.setMockInitialValues({'flutter.auth_token': 'x'});
      tester.view.physicalSize = const Size(390 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: BranchAttendanceScreen()));
        await tester.pumpAndSettle();

        // Header: names across the top, "Date" corner, totals labels at the bottom.
        expect(find.text('Date'), findsOneWidget);
        expect(find.text('Employee Number 1 Longname'), findsOneWidget);
        expect(find.text('Present'), findsOneWidget);
        expect(find.text('Absent'), findsOneWidget);
        expect(find.text('OT'), findsNWidgets(2)); // legend + footer label
        // The Zone / Branch card was removed from this screen.
        expect(find.text('Coimbatore'), findsNothing);
        expect(find.text('Zone'), findsNothing);
        expect(find.text('Branch'), findsNothing);

        // Day cells + OT total shown exactly as sent by the API.
        expect(find.text('Half OT'), findsOneWidget);
        expect(find.text('Full OT'), findsOneWidget);
        expect(find.text('0.25'), findsOneWidget);

        // Scroll the body sideways: the header names must move with it, while
        // the frozen date column stays put.
        final name1 = find.text('Employee Number 1 Longname');
        final nameX0 = tester.getTopLeft(name1).dx;
        final dateX0 = tester.getTopLeft(find.text('Date')).dx;
        await tester.drag(find.text('Half OT'), const Offset(-150, 0));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(name1).dx, lessThan(nameX0 - 50),
            reason: 'header must follow the body horizontally');
        expect(tester.getTopLeft(find.text('Date')).dx, dateX0,
            reason: 'date corner stays frozen');

        // Scroll down: header (names) stays pinned, totals stay visible.
        final nameY0 = tester.getTopLeft(name1).dy;
        final day7 = find.text('7');
        final day7Y0 = tester.getTopLeft(day7).dy;
        final dateCol = tester.getCenter(find.text('Date')) + const Offset(0, 150);
        await tester.dragFrom(dateCol, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(day7).dy, lessThan(day7Y0 - 50),
            reason: 'rows scroll vertically');
        expect(tester.getTopLeft(name1).dy, nameY0,
            reason: 'header stays pinned');
        expect(find.text('Present'), findsOneWidget);
      }, () => _mockApi(count));

      expect(tester.takeException(), isNull);
    });
  }
}
