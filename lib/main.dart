// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_service.dart';
import 'api_service.dart';
import 'login_page.dart';
import 'ad_dashboard.dart';
import 'logout_page.dart';
import 'attendance_page.dart';
import 'attendance_records_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Guard to ensure we only navigate once from a notification tap.
bool _hasNavigatedFromNotification = false;
void _safeNavigate(String route) {
  if (_hasNavigatedFromNotification) return;
  if (route.isEmpty) return;
  _hasNavigatedFromNotification = true;
  navigatorKey.currentState?.pushReplacementNamed(route);
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Keep background handler minimal.
  if (message.data.containsKey('route')) {
    debugPrint('Background route: ${message.data['route']}');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // initialize Firebase
  await Firebase.initializeApp();

  // init ApiService (Dio + cookie jar + token restore)
  await ApiService().init();

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // initialize local notifications and FCM background handler (your NotificationService)
  await NotificationService.init();

  // Single global listener for notification taps (works for background -> foreground)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    try {
      final route = message.data['route'] ?? message.data['screen'];
      if (route != null && route is String && route.isNotEmpty) {
        _safeNavigate(route);
      }
    } catch (e) {
      debugPrint('onMessageOpenedApp handler error: $e');
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // important for notification navigation
      title: 'Sacred Heart Hostel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoadingPage(),
        '/login': (context) => const LoginPage(),
        '/ad/dashboard': (context) => const AdDashboard(),
        '/logout': (context) => const LogoutPage(),
        // Support both route strings (so node script and app both work)
        '/ad/take-attendance': (ctx) => const AttendancePage(),
        '/ad/attendance': (ctx) => const AttendancePage(),
        '/ad/attendance-records': (ctx) => const AttendanceRecordsPage(),
      },
    );
  }
}

/// Loading page: checks /api/auth/authenticate and redirects accordingly.
/// If no session, routes to /login.
class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});
  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  String? _error;
  String? role;
  String? userId;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final sw = Stopwatch()..start();
    try {
      // Fast cached authenticate (should be instant most times)
      final data = await ApiService().authenticate();
      sw.stop();
      debugPrint(
        '[auth] authenticate() returned in ${sw.elapsedMilliseconds}ms',
      );

      final bool isLoggedIn = data['isLoggedIn'] == true;
      role = (data['role'] ?? data['user']?['role'])?.toString();
      userId = data['user']?['id']?.toString();

      if (!isLoggedIn) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      // Navigate based on role RIGHT AWAY (do not wait for notification setup)
      if (role == 'ad') {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/ad/dashboard');
      } else if (role == 'director') {
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushReplacementNamed('/login'); // adjust as needed
      } else if (role == 'student') {
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushReplacementNamed('/login'); // adjust as needed
      } else {
        setState(() {
          _error = "Unknown role from server. Contact admin.";
        });
      }

      // --- Run notification setup in background (non-blocking) ---
      // It should not block navigation. Use short timeouts and guard navigation via _safeNavigate.
      () async {
        final bgSw = Stopwatch()..start();
        try {
          // request permission (may show dialog)
          try {
            await NotificationService.requestPermission().timeout(
              const Duration(seconds: 6),
            );
          } on TimeoutException {
            debugPrint('[notifications] requestPermission timed out');
          } catch (e) {
            debugPrint('[notifications] requestPermission error: $e');
          }

          // set foreground handler (fast, local). This uses BuildContext for in-app UI.
          // Only call if still mounted; otherwise it's okay to skip.
          if (mounted) {
            try {
              NotificationService.setForegroundNotificationHandler(context);
            } catch (e) {
              debugPrint(
                '[notifications] setForegroundNotificationHandler error: $e',
              );
            }
          }

          // save FCM token to server, but don't block UI: use a short timeout
          try {
            await NotificationService.saveFcmTokenToServer(
              userId: userId,
            ).timeout(const Duration(seconds: 6));
          } on TimeoutException {
            debugPrint('[notifications] saveFcmTokenToServer timed out');
          } catch (e) {
            debugPrint('[notifications] saveFcmTokenToServer failed: $e');
          }

          // fetch initial message (rare but quick). If found, navigate safely.
          try {
            final msg = await NotificationService.getInitialMessage().timeout(
              const Duration(seconds: 4),
            );
            if (msg != null) {
              final route = msg.data['route'] ?? msg.data['screen'];
              if (route != null && route is String && route.isNotEmpty) {
                _safeNavigate(route);
              }
            }
          } on TimeoutException {
            debugPrint('[notifications] getInitialMessage timed out');
          } catch (e) {
            debugPrint('[notifications] getInitialMessage error: $e');
          }
        } catch (e) {
          debugPrint('[notifications] background setup failed: $e');
        } finally {
          bgSw.stop();
          debugPrint(
            '[notifications] background setup finished in ${bgSw.elapsedMilliseconds}ms',
          );
        }
      }();
    } catch (e) {
      debugPrint('[auth] authenticate() threw: $e');
      setState(() {
        _error = "Cannot reach server. Tap retry or continue to login.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _error == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(
                    strokeWidth: 4,
                    color: Colors.green,
                    backgroundColor: Colors.white,
                  ),
                  SizedBox(height: 12),
                  Text('Checking session...'),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _checkAuth,
                    child: const Text('Retry'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                    child: const Text('Continue to Login'),
                  ),
                ],
              ),
      ),
    );
  }
}
