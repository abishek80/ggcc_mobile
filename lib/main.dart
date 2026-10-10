import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'src/screens/dashboard_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/services/auth_service.dart';
import 'src/services/language_manager.dart';
import 'src/services/version_check_service.dart';
import 'src/screens/update_dialog.dart';
import 'src/services/firebase_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Firebase notification service
  await FirebaseNotificationService().initialize();

  await LanguageManager.instance.initialize();
  runApp(const GgccMobileApp());
}

class GgccMobileApp extends StatelessWidget {
  const GgccMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GGCC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC91115),
          primary: const Color(0xFFC91115),
          secondary: const Color(0xFF181D50),
        ),
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFFFF8F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  bool _isChecking = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVersionAndShowDialog();
    });
  }

  Future<void> _checkVersionAndShowDialog() async {
    final updateInfo = await VersionCheckService.checkAppVersion();
    if (updateInfo != null && mounted) {
      showAppUpdateDialog(context, updateInfo);
    }
  }

  Future<void> _checkAuthSession() async {
    try {
      final isValid = await _authService.isSessionValid();
      if (mounted) {
        setState(() {
          _isLoggedIn = isValid;
          _isChecking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png',
                width: 220,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: Color(0xFFC91115)),
            ],
          ),
        ),
      );
    }

    return _isLoggedIn ? const DashboardScreen() : const LoginScreen();
  }
}
