import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import 'auth_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late FirebaseMessaging _fcm;
  late FlutterLocalNotificationsPlugin _localNotifications;

  // ──────────────────────────────────────────────────────────────────────────
  // VAPID key for web push. Get it from:
  // Firebase Console → Project Settings → Cloud Messaging → Web Push Certificates
  // Click "Generate key pair" then copy the key string here.
  // ──────────────────────────────────────────────────────────────────────────
  static const String _webVapidKey =
      'BNkPpMwZYxaOzdRuNcCAlHQRdE4c-X78jx7jjNro5BFNKH0e4lzbQdK82D0_gDovc5-BUMe8M0ky4gVLwZlAi20';

  Future<void> init() async {
    // 1. Initialize Firebase with platform-specific options
    //    - Web: passes config explicitly (no google-services.json on web)
    //    - Android: reads from google-services.json automatically
    try {
      if (kIsWeb) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
      } else {
        await Firebase.initializeApp();
      }
      _fcm = FirebaseMessaging.instance;
    } catch (e) {
      print('Firebase initialization error: $e');
      return;
    }

    // 2. Request permissions
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 3. Local Notifications — only on Android (not needed on Web)
    if (!kIsWeb) {
      _localNotifications = FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );
      await _localNotifications.initialize(initSettings);
    }

    // 4. Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kIsWeb) {
        // On Web, the browser handles foreground notifications natively
        print('[FCM Web] Foreground message: ${message.notification?.title}');
      } else {
        _showLocalNotification(message);
      }
    });

    // 5. Tap on notification when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from notification: ${message.data}');
    });

    // 6. Register token with backend
    await updateToken();
  }

  Future<void> updateToken() async {
    try {
      // Web requires a VAPID key; Android uses google-services.json
      final token = kIsWeb
          ? await _fcm.getToken(vapidKey: _webVapidKey)
          : await _fcm.getToken();

      if (token != null) {
        print('FCM Token: $token');
        await AuthService().updateFcmToken(token);
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    // To use a custom sound:
    // 1. Download an mp3 and put it in: android/app/src/main/res/raw/alert_1.mp3
    // 2. Uncomment the 'sound' line below and change 'alert_1' to your filename.

    const AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'egx_alerts_channel', // Change ID if you change sound (Android cache rule)
      'EGX Portfolio Alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alert_1'),
    );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    _localNotifications.show(
      message.notification.hashCode,
      message.notification?.title,
      message.notification?.body,
      details,
    );
  }
}
