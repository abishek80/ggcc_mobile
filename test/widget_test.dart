import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggcc_mobile/src/screens/login_screen.dart';
import 'package:ggcc_mobile/src/screens/attendance_screen.dart';

void main() {
  testWidgets('GGCC App login screen renders correctly', (WidgetTester tester) async {
    // Build LoginScreen inside MaterialApp.
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    // Verify that logo image and login fields exist.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Please Login to Your Account.'), findsOneWidget);
    expect(find.text('User ID or Mobile Number'), findsOneWidget);
    expect(find.text('Password'), findsWidgets);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('AttendanceScreen renders initial loading state', (WidgetTester tester) async {
    // Build AttendanceScreen inside MaterialApp.
    await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));

    // Verify that initial loading state is rendered.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
