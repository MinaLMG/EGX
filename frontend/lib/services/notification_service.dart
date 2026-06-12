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

  FirebaseMessaging? _fcm;
  FlutterLocalNotificationsPlugin? _localNotifications;
  bool _isInit = false;

  // Web VAPID key from Firebase Console
  final String _webVapidKey = 'BNkPpMwZYxaOzdRuNcCAlHQRdE4c-X78jx7jjNro5BFNKH0e4lzbQdK82D0_gDovc5-BUMe8M0ky4gVLwZlAi20';

  Future<void> init() async {
    if (_isInit) return;
    
    try {
      await LogService.log('--- SYSTEM AUDIT ---');
      if (!kIsWeb) {
        await LogService.log('OS: ${Platform.operatingSystem}, Ver: ${Platform.operatingSystemVersion}');
      }

      await LogService.log('Initializing Firebase...');
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        await LogService.log('Firebase already initialized, skipping...');
      }
      
      final options = Firebase.app().options;
      await LogService.log('Config: Proj=${options.projectId}, App=${options.appId.substring(0, 10)}...');
      
      _fcm = FirebaseMessaging.instance;
      await LogService.log('Firebase initialized successfully.');
    } catch (e) {
      await LogService.error('Firebase initialization error', e);
      return;
    }

    // 2. Request permissions
    await LogService.log('Requesting notification permissions...');
    final settings = await _fcm!.requestPermission(alert: true, badge: true, sound: true);
    await LogService.log('Permission status: ${settings.authorizationStatus}');

    // 3. Local Notifications — only on Android/iOS (not needed on Web)
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
      final initResult = await _localNotifications!.initialize(initSettings);
      await LogService.log('Local Notifications ready. Result: $initResult');

      // Create the High Importance channel for "Heads-up" (Pop-ups)
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'egx_alerts_channel_v2',
        'EGX Portfolio Alerts',
        description: 'Important rebalancing alerts and price updates.',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alert_1'),
      );

      await _localNotifications!
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }

    // 4. Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await LogService.log('FOREGROUND MSG: ${message.notification?.title ?? "No Title"}');
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

    _isInit = true; // Mark as initialized
    
    // 6. Register token with backend
    await updateToken();
  }

  Future<void> updateToken() async {
    try {
      // Auto-init if called prematurely
      if (!_isInit || _fcm == null) {
        await LogService.log('updateToken() called before init, initializing now...');
        await init();
        if (_fcm == null) {
          await LogService.error('FCM still null after emergency init');
          return;
        }
      }

      await LogService.log('Starting updateToken()...');
      
      // On iOS, we sometimes need to wait for the APNS token to be ready
      if (!kIsWeb && Platform.isIOS) {
        await LogService.log('Detected iOS, checking APNS token...');
        int retryCount = 0;
        String? apnsToken;
        
        while (retryCount < 5 && apnsToken == null) {
          apnsToken = await _fcm!.getAPNSToken();
          if (apnsToken == null) {
            await LogService.log('APNS Token not ready yet, retrying... ($retryCount)');
            await Future.delayed(const Duration(seconds: 2));
            retryCount++;
          }
        }
        await LogService.log('APNS Token result: ${apnsToken != null ? "FOUND" : "NOT FOUND"}');
      }

      await LogService.log('Fetching FCM token...');
      final token = kIsWeb
          ? await _fcm!.getToken(vapidKey: _webVapidKey)
          : await _fcm!.getToken();

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
    if (_localNotifications == null) return;

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

    _localNotifications!.show(
      message.notification.hashCode,
      message.notification?.title,
      message.notification?.body,
      details,
    );
  }
}
