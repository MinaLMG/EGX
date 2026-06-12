import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import 'auth_service.dart';
import 'log_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late FirebaseMessaging _fcm;
  late FlutterLocalNotificationsPlugin _localNotifications;

  // Web VAPID key from Firebase Console
  final String _webVapidKey =
      'BNkPpMwZYxaOzdRuNcCAlHQRdE4c-X78jx7jjNro5BFNKH0e4lzbQdK82D0_gDovc5-BUMe8M0ky4gVLwZlAi20';
  Future<void> init() async {
    // 1. Initialize Firebase
    //    - Web: passes config explicitly (no google-services.json on web)
    //    - Android: reads from google-services.json automatically
    try {
      await LogService.log('--- SYSTEM AUDIT ---');
      if (!kIsWeb) {
        await LogService.log(
          'OS: ${Platform.operatingSystem}, Ver: ${Platform.operatingSystemVersion}',
        );
      }

      await LogService.log('Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final options = Firebase.app().options;
      await LogService.log(
        'Config: Proj=${options.projectId}, App=${options.appId.substring(0, 10)}...',
      );

      _fcm = FirebaseMessaging.instance;
      await LogService.log('Firebase initialized successfully.');
    } catch (e) {
      await LogService.error('Firebase initialization error', e);
      return;
    }

    // 2. Request permissions
    await LogService.log('Requesting notification permissions...');
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await LogService.log('Permission status: ${settings.authorizationStatus}');

    // 3. Local Notifications — only on Android (not needed on Web)
    if (!kIsWeb) {
      _localNotifications = FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings darwinSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await LogService.log('Initializing Local Notifications...');
      final initResult = await _localNotifications.initialize(initSettings);
      await LogService.log('Local Notifications ready. Result: $initResult');

      // Create the High Importance channel for "Heads-up" (Pop-ups)
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'egx_alerts_channel_v2', // ID must be consistent with _showLocalNotification
        'EGX Portfolio Alerts',
        description: 'Important rebalancing alerts and price updates.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alert_1'),
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }

    // 4. Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await LogService.log(
        'FOREGROUND MSG: ${message.notification?.title ?? "No Title"}',
      );
      if (kIsWeb) {
        await LogService.log('Web handles foreground natively.');
      } else {
        await LogService.log('Attempting to show local notification popup...');
        _showLocalNotification(message);
      }
    });

    // 5. Tap on notification when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await LogService.log('APP OPENED VIA NOTIFICATION: ${message.data}');
    });

    // 6. Register token with backend
    await updateToken();
  }

  Future<void> updateToken() async {
    try {
      await LogService.log('Starting updateToken()...');

      // On iOS, we sometimes need to wait for the APNS token to be ready
      if (!kIsWeb && (Firebase.app().options.projectId.isNotEmpty)) {
        await LogService.log('Detected iOS/Android, checking APNS token...');
        int retryCount = 0;
        String? apnsToken;

        while (retryCount < 3 && apnsToken == null) {
          apnsToken = await _fcm.getAPNSToken();
          if (apnsToken == null) {
            await LogService.log(
              'APNS Token not ready yet, retrying... ($retryCount)',
            );
            await Future.delayed(const Duration(seconds: 2));
            retryCount++;
          }
        }
        await LogService.log(
          'APNS Token result: ${apnsToken != null ? "FOUND" : "NOT FOUND"}',
        );
      }

      await LogService.log('Fetching FCM token...');
      // Web requires a VAPID key; Android/iOS uses internal config
      final token = kIsWeb
          ? await _fcm.getToken(vapidKey: _webVapidKey)
          : await _fcm.getToken();

      if (token != null) {
        await LogService.log('FCM token found: ${token.substring(0, 10)}...');
        await AuthService().updateFcmToken(token);
        await LogService.log('Token update request sent to backend.');
      } else {
        await LogService.error('FCM Token is null');
      }
    } catch (e) {
      await LogService.error('Error in updateToken()', e);
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'egx_alerts_channel_v2',
          'EGX Portfolio Alerts',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('alert_1'),
        );
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'alert_1.caf',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    _localNotifications.show(
      message.notification.hashCode,
      message.notification?.title,
      message.notification?.body,
      details,
    );
  }
}
