// lib/notification_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'api_service.dart'; // uncomment and use your ApiService method to send token to server

@pragma('vm:entry-point') // required for background handling on release
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Optionally handle background message; e.g. write to local DB, etc.
  print('Background message received: ${message.messageId}, data: ${message.data}');
}

/// Singleton-like service to manage notifications
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  /// Call this once early (before runApp ideally after Firebase.initializeApp())
  static Future<void> init() async {
    // Initialize flutter_local_notifications
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // NOTE: onDidReceiveLocalNotification callback was removed in newer versions.
    // Keep DarwinInitializationSettings simple.
    final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final InitializationSettings settings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    // onDidReceiveNotificationResponse handles taps (for both Android & iOS)
    await _local.initialize(settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
      // This fires when user taps a local/system notification
      print('Local notification tapped. payload: ${response.payload}');
    });

    // Create channel for Android
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Register FCM background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Request permission for notifications (Android 13+, iOS)
  static Future<NotificationSettings> requestPermission() async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('User granted permission: ${settings.authorizationStatus}');
    return settings;
  }

  /// Listen to incoming messages and show local notification when app is foreground
  static void setForegroundNotificationHandler(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message: ${message.messageId}');
      final notification = message.notification;

      // When the push has a notification payload, show a system notification
      if (notification != null) {
        _local.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id,
              _androidChannel.name,
              channelDescription: _androidChannel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: message.data.isNotEmpty ? message.data.toString() : null,
        );
      }
    });

    // When the user taps a notification and app opens/resumes from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification opened app: ${message.messageId}, data: ${message.data}');
      // Navigate if you like:
      // Navigator.of(context).pushNamed('/ad/attendance-records');
    });
  }

  /// Get FCM token and print it. Replace the print with your API call to store token.
static Future<void> saveFcmTokenToServer() async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    print('FCM token: $token');

    if (token != null) {
      // Optionally send token to your backend here:
      // await ApiService().saveFcmToken(token);

      // Subscribe this device to the global topic "all_users"
      try {
        await FirebaseMessaging.instance.subscribeToTopic('all_users');
        print('Subscribed to topic: all_users');
      } catch (e) {
        print('Failed to subscribe to topic all_users: $e');
      }
    }

    // Listen for future token refreshes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('New FCM token: $newToken');
      // update your server if needed
      // await ApiService().saveFcmToken(newToken);

      // Re-subscribe on token refresh just in case
      try {
        await FirebaseMessaging.instance.subscribeToTopic('all_users');
        print('Re-subscribed to topic: all_users');
      } catch (e) {
        print('Failed to re-subscribe to topic all_users: $e');
      }
    });
  } catch (e) {
    print('Failed to get/save FCM token: $e');
  }
}


  /// If app was launched by a notification while terminated, this returns the message
  static Future<RemoteMessage?> getInitialMessage() =>
      FirebaseMessaging.instance.getInitialMessage();
}
