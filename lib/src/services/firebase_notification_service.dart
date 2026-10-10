import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');

  // For data-only messages, show a local notification manually
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title'] ??
        message.data['Title'] ??
        'GGCC';
    final body = message.data['body'] ??
        message.data['Body'] ??
        message.data['message'] ??
        message.data['description'] ??
        '';

    if (title.isNotEmpty || body.isNotEmpty) {
      final localNotifications = FlutterLocalNotificationsPlugin();
      const androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      await localNotifications.initialize(
        const InitializationSettings(android: androidSettings),
      );

      await localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'ggcc_notifications',
            'GGCC Notifications',
            channelDescription: 'Notifications from GGCC app',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/launcher_icon',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }
}

class FirebaseNotificationService {
  static final FirebaseNotificationService _instance =
      FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Notification tap callback
  Function(RemoteMessage message)? onNotificationTap;

  /// Initialize Firebase messaging and local notifications
  Future<void> initialize() async {
    // Initialize local notifications for foreground display
    await _initLocalNotifications();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      debugPrint('[FCM] Token refreshed: $newToken');
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app was terminated
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Request notification permission — call this AFTER the UI is rendered
  Future<void> requestPermission() async {
    // Request permission via Firebase Messaging (Android 13+ / iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

    // Also explicitly request via flutter_local_notifications for Android
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      debugPrint('[FCM] Android notification permission granted: $granted');
    }

    // Get FCM token after permission is granted
    _fcmToken = await _messaging.getToken();
    debugPrint('[FCM] Token: $_fcmToken');
  }

  Future<void> _initLocalNotifications() async {
    // Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'ggcc_notifications',
      'GGCC Notifications',
      description: 'Notifications from GGCC app',
      importance: Importance.high,
      playSound: true,
    );

    // Create the channel on Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Initialize settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (details) {
        // Handle local notification tap
        debugPrint('[FCM] Local notification tapped: ${details.payload}');
        if (details.payload != null) {
          try {
            final data = jsonDecode(details.payload!);
            final message = RemoteMessage(data: Map<String, String>.from(data));
            _handleNotificationTap(message);
          } catch (_) {}
        }
      },
    );
  }

  /// Show a local notification when app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message received');
    debugPrint('[FCM] notification: ${message.notification?.title}');
    debugPrint('[FCM] data: ${message.data}');

    final notification = message.notification;

    // Get title and body from notification payload OR data payload
    final title = notification?.title ??
        message.data['title'] ??
        message.data['Title'] ??
        'GGCC';
    final body = notification?.body ??
        message.data['body'] ??
        message.data['Body'] ??
        message.data['message'] ??
        message.data['description'] ??
        '';

    // Show notification if we have content
    if (title.isNotEmpty || body.isNotEmpty) {
      _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'ggcc_notifications',
            'GGCC Notifications',
            channelDescription: 'Notifications from GGCC app',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/launcher_icon',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Handle notification tap (background or terminated)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped: ${message.data}');
    onNotificationTap?.call(message);
  }
}
