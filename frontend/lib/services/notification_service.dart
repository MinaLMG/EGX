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
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
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
      await _localNotifications.initialize(initSettings);

      // Create the High Importance channel for "Heads-up" (Pop-ups)
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'egx_alerts_channel_v2', // Must match the ID used in backend & _showLocalNotification
        'EGX Portfolio Alerts',
        description: 'Important rebalancing alerts and price updates.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alert_1'),
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
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
      // On iOS, we sometimes need to wait for the APNS token to be ready
      if (!kIsWeb && (Firebase.app().options.projectId.isNotEmpty)) {
        int retryCount = 0;
        String? apnsToken;
        
        while (retryCount < 3 && apnsToken == null) {
          apnsToken = await _fcm.getAPNSToken();
          if (apnsToken == null) {
            print('[FCM] APNS Token not ready yet, retrying in 2 seconds... ($retryCount)');
            await Future.delayed(const Duration(seconds: 2));
            retryCount++;
          }
        }
        print('[FCM] APNS Token: $apnsToken');
      }

      // Web requires a VAPID key; Android/iOS uses internal config
      final token = kIsWeb
          ? await _fcm.getToken(vapidKey: _webVapidKey)
          : await _fcm.getToken();

      if (token != null) {
        print('[FCM] Final Token: $token');
        await AuthService().updateFcmToken(token);
      } else {
        print('[FCM] Token is still null after retries.');
      }
    } catch (e) {
      print('[FCM] Error getting token: $e');
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    // To use a custom sound:
    // 1. Download an mp3 and put it in: android/app/src/main/res/raw/alert_1.mp3
    // 2. Uncomment the 'sound' line below and change 'alert_1' to your filename.

    const AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'egx_alerts_channel_v2', // Change ID if you change sound (Android cache rule)
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
      sound: 'alert_1.caf', // iOS uses different sound formats like .caf or .m4a
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
