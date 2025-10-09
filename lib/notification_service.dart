// lib/notification_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

/// Replace with your deployed backend URL (https) and API key.
/// For security, prefer injecting these from a secure place rather than hardcoding.
const String BACKEND_BASE_URL = 'http://10.20.108.165:4000';
const String API_KEY = 'supersecretapikey123';

@pragma('vm:entry-point') // required for background handling on release
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in background isolate.
  await Firebase.initializeApp();
  // Optionally handle background message; e.g. write to local DB, analytics, etc.
  print(
    'Background message received: ${message.messageId}, data: ${message.data}',
  );
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

    final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    // onDidReceiveNotificationResponse handles taps (for both Android & iOS)
    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // This fires when user taps a local/system notification
        print('Local notification tapped. payload: ${response.payload}');
      },
    );

    // Create channel for Android
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
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
      print(
        'Notification opened app: ${message.messageId}, data: ${message.data}',
      );
      // Navigate if you like:
      // Navigator.of(context).pushNamed('/ad/attendance-records');
    });
  }

  /// Upload FCM token to your backend.
  /// - `userId` is optional and useful to map token to your app user.
  /// - `platform` is optional; defaults to the device OS.
  static Future<void> saveFcmTokenToServer({
    String? userId,
    String? platform,
  }) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      print('FCM token: $token');

      if (token == null) return;

      // send to backend
      final uri = Uri.parse('$BACKEND_BASE_URL/api/fcm-token');
      final body = jsonEncode({
        'token': token,
        'userId': userId,
        'platform': platform ?? Platform.operatingSystem,
        'meta': {
          'app': 'your_app_name',
          'timestamp': DateTime.now().toIso8601String(),
        },
      });

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'x-api-key': API_KEY},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Saved token to server: ${response.body}');
      } else {
        print(
          'Failed to save token. status=${response.statusCode} body=${response.body}',
        );
      }

      // Subscribe this device to the global topic "all_users"
      try {
        await FirebaseMessaging.instance.subscribeToTopic('all_users');
        print('Subscribed to topic: all_users');
      } catch (e) {
        print('Failed to subscribe to topic all_users: $e');
      }

      // Listen for future token refreshes and send them to server
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        print('New FCM token: $newToken');

        // Send refreshed token to backend (re-use same endpoint, server will upsert)
        try {
          final r = await http.post(
            uri,
            headers: {'Content-Type': 'application/json', 'x-api-key': API_KEY},
            body: jsonEncode({
              'token': newToken,
              'userId': userId,
              'platform': platform ?? Platform.operatingSystem,
              'meta': {
                'refreshed': true,
                'timestamp': DateTime.now().toIso8601String(),
              },
            }),
          );
          if (r.statusCode == 200 || r.statusCode == 201) {
            print('Refreshed token saved to server.');
          } else {
            print('Failed to save refreshed token: ${r.statusCode} ${r.body}');
          }
        } catch (e) {
          print('Error sending refreshed token: $e');
        }

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

  /// Delete token from server (call on logout if you want to unlink device)
  static Future<void> deleteFcmTokenFromServer({String? token}) async {
    try {
      final t = token ?? await FirebaseMessaging.instance.getToken();
      if (t == null) return;

      final uri = Uri.parse('$BACKEND_BASE_URL/api/fcm-token/$t');
      final response = await http.delete(
        uri,
        headers: {'Content-Type': 'application/json', 'x-api-key': API_KEY},
      );

      if (response.statusCode == 200) {
        print('Deleted token from server');
      } else {
        print(
          'Failed to delete token. status=${response.statusCode} body=${response.body}',
        );
      }

      // Optionally unsubscribe from topic(s)
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic('all_users');
        print('Unsubscribed from topic: all_users');
      } catch (e) {
        print('Failed to unsubscribe from topic all_users: $e');
      }
    } catch (e) {
      print('Error deleting token from server: $e');
    }
  }

  /// If app was launched by a notification while terminated, this returns the message
  static Future<RemoteMessage?> getInitialMessage() =>
      FirebaseMessaging.instance.getInitialMessage();
}
