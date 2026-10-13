import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';

/// Top-level background message handler for FCM
/// Must be outside of any class to run in its own isolate
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('FCM Background message received: ${message.messageId}');
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'sabzee_orders_channel',
    'Sabzee Order Updates & Deals',
    description: 'Notifications for grocery orders, delivery status, and offers',
    importance: Importance.high,
    playSound: true,
  );

  /// Initializes permissions, local notification plugin, and FCM listeners
  Future<void> initialize({Function(Map<String, dynamic> data)? onNotificationTap}) async {
    // 1. Request notification permissions (required on iOS and Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (kDebugMode) {
      print('FCM notification permission status: ${settings.authorizationStatus}');
    }

    // 2. Initialize local notifications for heads-up foreground banners
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && onNotificationTap != null) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            onNotificationTap(data);
          } catch (e) {
            if (kDebugMode) print('Error parsing notification payload: $e');
          }
        }
      },
    );

    // 3. Create the Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 4. Configure foreground presentation options
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 5. Handle foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // 6. Handle notification click when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (onNotificationTap != null) {
        onNotificationTap(message.data);
      }
    });

    // 7. Handle notification click when app was launched from terminated state
    final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null && onNotificationTap != null) {
      onNotificationTap(initialMessage.data);
    }

    // 8. Log FCM Device Token for easy testing in Firebase Console
    await logFcmToken();
  }

  /// Displays a heads-up notification banner when message arrives while app is open
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && !kIsWeb) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title ?? 'SabzeeWala',
        notification.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/launcher_icon',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Retrieves and logs the FCM Device Token
  Future<String?> logFcmToken() async {
    try {
      final String? token = await _fcm.getToken();
      if (kDebugMode) {
        print('\n======================================================');
        print('🔔 SabzeeWala FCM Device Token:');
        print(token);
        print('======================================================\n');
      }
      return token;
    } catch (e) {
      if (kDebugMode) print('Failed to get FCM token: $e');
      return null;
    }
  }

  /// Syncs FCM Token with the Supabase users table for targeted push alerts
  Future<void> syncTokenWithSupabase(String userMobile) async {
    try {
      final String? token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        final client = SupabaseService().client;
        if (client != null) {
          await client.from('users').update({
            'fcm_token': token,
            'last_active_time': DateTime.now().toIso8601String(),
          }).eq('id', userMobile);
          if (kDebugMode) {
            print('FCM Token successfully synced to Supabase for $userMobile');
          }
        }
      }

      // Automatically sync updated token on token rotation
      _fcm.onTokenRefresh.listen((newToken) async {
        final client = SupabaseService().client;
        if (client != null) {
          await client.from('users').update({
            'fcm_token': newToken,
            'last_active_time': DateTime.now().toIso8601String(),
          }).eq('id', userMobile);
        }
      });
    } catch (e) {
      if (kDebugMode) print('Failed to sync FCM token with Supabase: $e');
    }
  }
}
