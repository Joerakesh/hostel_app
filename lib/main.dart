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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // initialize Firebase
  await Firebase.initializeApp();

  // init ApiService (your existing Dio + cookie jar init)
  await ApiService().init();

  // initialize local notifications and FCM background handler
  await NotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        '/ad/take-attendance': (ctx) => const AttendancePage(),
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

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final data = await ApiService().authenticate();
      final bool isLoggedIn = data['isLoggedIn'] == true;
      final String? role = (data['role'] ?? data['user']?['role'])?.toString();

      if (!isLoggedIn) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      // ----- NOTIFICATIONS: only set up when user IS logged in -----
      // We run this in a try/catch so notification setup errors don't block navigation.
      try {
        await NotificationService.requestPermission();
        NotificationService.setForegroundNotificationHandler(context);
        await NotificationService.saveFcmTokenToServer();

        // If the app was launched from a terminated state by tapping a notification,
        // getInitialMessage() returns that RemoteMessage; handle navigation if needed.
        final msg = await NotificationService.getInitialMessage();
        if (msg != null) {
          // Example: if your server sends data like {"screen":"attendance_records"}
          final screen = msg.data['screen'];
          if (screen == 'attendance_records') {
            if (!mounted) return;
            Navigator.of(context).pushReplacementNamed('/ad/attendance-records');
            return;
          }
          // add other message-based navigation handling here
        }
      } catch (e) {
        // Log but continue
        // ignore: avoid_print
        print('Notification setup failed: $e');
      }

      // ----- Role-based navigation -----
      if (role == 'ad') {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/ad/dashboard');
      } else if (role == 'director') {
        // adjust route if you add director's page
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login'); // fallback
      } else if (role == 'student') {
        // add student route similarly
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login'); // fallback
      } else {
        setState(() {
          _error = "Unknown role from server. Contact admin.";
        });
      }
    } catch (e) {
      // on network/server error, go to login but show option to retry
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
                  )
                ],
              ),
      ),
    );
  }
}
