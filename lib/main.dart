// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'notification_service.dart';
import 'api_service.dart';
import 'login_page.dart';
import 'ad_dashboard.dart';
import 'logout_page.dart';
import 'attendance_page.dart';
import 'attendance_records_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

  // Register a single onMessageOpenedApp listener here so tapping notification navigates.
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final route = message.data['route'] ?? message.data['screen'];
    if (route != null && route is String && route.isNotEmpty) {
      // use navigatorKey (MaterialApp must include navigatorKey)
      navigatorKey.currentState?.pushNamed(route);
    }
  });

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // For background messages: keep minimal
  if (message.data.containsKey('route')) {
    debugPrint('Background route: ${message.data['route']}');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // <<< important so notifications can navigate
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
        // Support both route strings so your node script and app both work
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

    // Listen to onMessageOpenedApp here too if you want additional handling,
    // but note we already registered a global listener in main().
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.containsKey('route')) {
        final route = message.data['route'];
        debugPrint('Navigating to from LoadingPage listener: $route');
        // Use navigatorKey to navigate even if context isn't ready
        navigatorKey.currentState?.pushNamed(route);
      }
    });

    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final data = await ApiService().authenticate();
      final bool isLoggedIn = data['isLoggedIn'] == true;

      role = (data['role'] ?? data['user']?['role'])?.toString();
      userId = data['user']?['id']?.toString(); // ✅ store for notification

      if (!isLoggedIn) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      // ----- NOTIFICATIONS: only set up when user IS logged in -----
      try {
        await NotificationService.requestPermission();

        // set a foreground handler that takes BuildContext for in-app UI handling
        NotificationService.setForegroundNotificationHandler(context);

        // Save FCM token to server (make sure NotificationService uses userId param right)
        await NotificationService.saveFcmTokenToServer(userId: userId);

        // If the app was launched from terminated state by tapping a notification,
        // getInitialMessage() returns that RemoteMessage; handle navigation if needed.
        final msg = await NotificationService.getInitialMessage();
        if (msg != null) {
          final route = msg.data['route'] ?? msg.data['screen'];
          if (route != null && route is String && route.isNotEmpty) {
            // Use navigatorKey to push the requested route
            navigatorKey.currentState?.pushReplacementNamed(route);
            return;
          }
        }
      } catch (e) {
        // Log but continue navigation
        debugPrint('Notification setup failed: $e');
      }

      // ----- Role-based navigation -----
      if (role == 'ad') {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/ad/dashboard');
      } else if (role == 'director') {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login'); // fallback
      } else if (role == 'student') {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login'); // fallback
      } else {
        setState(() {
          _error = "Unknown role from server. Contact admin.";
        });
      }
    } catch (e) {
      // on network/server error, show retry option and let user continue to login
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
