// lib/notification_service.dart
import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart' show DioError, DioException, LogInterceptor;

import 'api_service.dart'; // <-- your ApiService (Dio + cookie support)

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(
    'Background message received: ${message.messageId}, data: ${message.data}',
  );
}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );

  /// Initialize local notifications and register background handler
  static Future<void> init() async {
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

    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Local notification tapped. payload: ${response.payload}');
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Request permission (returns NotificationSettings from firebase_messaging)
  static Future<NotificationSettings> requestPermission() async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');
    return settings;
  }

  /// Show local notification for foreground messages and set tap handler
  static void setForegroundNotificationHandler(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message: ${message.messageId}');
      final notification = message.notification;

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

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        'Notification opened app: ${message.messageId}, data: ${message.data}',
      );
      // Optional: navigate using Navigator/GlobalKey if desired
    });
  }

  /// Upload FCM token to backend using ApiService().dio
  /// - if your server expects cookie-based auth (verifyToken), using ApiService().dio will forward cookies
  static Future<void> saveFcmTokenToServer({
    String? userId,
    String? platform,
  }) async {
    developer.log('saveFcmTokenToServer: start', name: 'NotificationService');
    try {
      // log ApiService baseUrl so we can detect path mismatches
      final baseUrl = ApiService().dio.options.baseUrl;
      developer.log(
        'ApiService baseUrl: $baseUrl',
        name: 'NotificationService',
      );

      // get token
      final token = await FirebaseMessaging.instance.getToken();
      developer.log('FCM token: $token', name: 'NotificationService');

      if (token == null) {
        developer.log(
          'No FCM token (null) — aborting upload.',
          name: 'NotificationService',
        );
        return;
      }

      // normalize path depending on whether baseUrl contains /api
      final normalizedPath = (baseUrl.contains('/api'))
          ? '/fcm/register'
          : '/api/fcm/register';

      final bodyMap = {
        'token': token,
        'userId': userId,
        'platform': platform ?? Platform.operatingSystem,
        'meta': {
          'app': 'sacred-heart-hostel',
          'timestamp': DateTime.now().toIso8601String(),
        },
      };

      developer.log(
        'Prepared body for register: $bodyMap',
        name: 'NotificationService',
      );

      // add LogInterceptor only once (avoid stacking)
      try {
        final hasLogInterceptor = ApiService().dio.interceptors.any(
          (i) => i.runtimeType == LogInterceptor,
        );
        if (!hasLogInterceptor) {
          ApiService().dio.interceptors.add(
            LogInterceptor(
              request: true,
              requestHeader: true,
              requestBody: true,
              responseHeader: true,
              responseBody: true,
            ),
          );
        }
      } catch (e) {
        debugPrint('Failed to attach LogInterceptor (non-fatal): $e');
      }

      // Try Dio POST (preferred: sends cookies if ApiService configured with CookieManager)
      bool postedSuccessfully = false;
      try {
        final resp = await ApiService().dio.post(normalizedPath, data: bodyMap);
        debugPrint('Saved token to server: ${resp.statusCode} ${resp.data}');
        postedSuccessfully =
            resp.statusCode != null &&
            resp.statusCode! >= 200 &&
            resp.statusCode! < 300;
      } on DioException catch (dioErr) {
        debugPrint('DioError saving token: ${dioErr.message}');
        debugPrint(
          'DioError.response?.statusCode: ${dioErr.response?.statusCode}',
        );
        debugPrint('DioError.response?.data: ${dioErr.response?.data}');
      } catch (e) {
        debugPrint('Unexpected error saving token: $e');
      }

      // Fallback: try plain http.post if Dio didn't succeed (good for debugging reachability / path)
      if (!postedSuccessfully) {
        try {
          final fullUrl = baseUrl.endsWith('/')
              ? '$baseUrl${normalizedPath.substring(1)}'
              : '$baseUrl$normalizedPath';
          developer.log(
            'Fallback HTTP POST to $fullUrl',
            name: 'NotificationService',
          );

          final response = await http.post(
            Uri.parse(fullUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(bodyMap),
          );

          developer.log(
            'Fallback HTTP response: ${response.statusCode} ${response.body}',
            name: 'NotificationService',
          );

          if (response.statusCode >= 200 && response.statusCode < 300) {
            postedSuccessfully = true;
          }
        } catch (httpErr) {
          developer.log(
            'Fallback http.post failed: $httpErr',
            name: 'NotificationService',
            level: 1000,
          );
        }
      }

      // Subscribe to a topic (optional) only if we successfully posted token
      if (postedSuccessfully) {
        try {
          await FirebaseMessaging.instance.subscribeToTopic('all_users');
          debugPrint('Subscribed to topic: all_users');
        } catch (e) {
          debugPrint('Failed to subscribe to topic all_users: $e');
        }
      } else {
        debugPrint(
          'Token was not posted successfully -> skipping topic subscribe',
        );
      }

      // Listen for token refresh and upsert on server
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('New FCM token: $newToken');

        final refreshBody = {
          'token': newToken,
          'userId': userId,
          'platform': platform ?? Platform.operatingSystem,
          'meta': {
            'refreshed': true,
            'timestamp': DateTime.now().toIso8601String(),
          },
        };

        // Attempt to POST refreshed token; prefer Dio
        try {
          final r = await ApiService().dio.post(
            normalizedPath,
            data: refreshBody,
          );
          debugPrint(
            'Refreshed token saved to server: ${r.statusCode} ${r.data}',
          );

          // subscribe if success
          if (r.statusCode != null &&
              r.statusCode! >= 200 &&
              r.statusCode! < 300) {
            try {
              await FirebaseMessaging.instance.subscribeToTopic('all_users');
              debugPrint('Re-subscribed to topic: all_users');
            } catch (e) {
              debugPrint('Failed to re-subscribe to topic all_users: $e');
            }
          }
        } on DioException catch (dioErr) {
          debugPrint('DioException on refresh POST: ${dioErr.message}');
          debugPrint('DioException.response?.data: ${dioErr.response?.data}');
          // fallback attempt with http
          try {
            final fullUrl = baseUrl.endsWith('/')
                ? '$baseUrl${normalizedPath.substring(1)}'
                : '$baseUrl$normalizedPath';
            final resp = await http.post(
              Uri.parse(fullUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(refreshBody),
            );
            debugPrint(
              'Fallback refresh HTTP response: ${resp.statusCode} ${resp.body}',
            );
            if (resp.statusCode >= 200 && resp.statusCode < 300) {
              try {
                await FirebaseMessaging.instance.subscribeToTopic('all_users');
                debugPrint('Re-subscribed to topic after fallback: all_users');
              } catch (e) {
                debugPrint('Failed to subscribe to topic after fallback: $e');
              }
            }
          } catch (e) {
            debugPrint('Fallback refresh http failed: $e');
          }
        } catch (e) {
          debugPrint('Unexpected error posting refreshed token: $e');
        }
      });
    } catch (e, st) {
      developer.log(
        'Failed to get/save FCM token: $e\n$st',
        name: 'NotificationService',
        level: 1000,
      );
    }
  }

  /// Unregister token from backend using ApiService().dio
  static Future<void> deleteFcmTokenFromServer({String? token}) async {
    try {
      final t = token ?? await FirebaseMessaging.instance.getToken();
      if (t == null) return;

      final baseUrl = ApiService().dio.options.baseUrl;
      final normalizedPath = (baseUrl.contains('/api'))
          ? '/fcm/unregister'
          : '/api/fcm/unregister';

      try {
        final resp = await ApiService().dio.post(
          normalizedPath,
          data: {'token': t},
        );
        debugPrint(
          'Deleted token from server: ${resp.statusCode} ${resp.data}',
        );
      } catch (e) {
        debugPrint('Failed to delete token from server (via Dio): $e');
        // fallback http
        try {
          final fullUrl = baseUrl.endsWith('/')
              ? '$baseUrl${normalizedPath.substring(1)}'
              : '$baseUrl$normalizedPath';
          final r = await http.post(
            Uri.parse(fullUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': t}),
          );
          debugPrint(
            'Fallback delete http response: ${r.statusCode} ${r.body}',
          );
        } catch (httpErr) {
          debugPrint('Fallback http delete failed: $httpErr');
        }
      }

      // Optionally unsubscribe from topic(s)
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic('all_users');
        debugPrint('Unsubscribed from topic: all_users');
      } catch (e) {
        debugPrint('Failed to unsubscribe from topic all_users: $e');
      }
    } catch (e) {
      debugPrint('Error deleting token from server: $e');
    }
  }

  /// If app was launched by a notification while terminated, this returns the message
  static Future<RemoteMessage?> getInitialMessage() =>
      FirebaseMessaging.instance.getInitialMessage();
}
