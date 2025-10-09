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

/// Loading page: requests notification permission first, then navigates to Login.
/// This enforces the flow: user must allow notifications, then we go to login.
class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});
  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  bool _requesting = false;
  String? _error;
  bool _permissionGranted = false;
  bool _permissionDeniedPermanently = false;

  @override
  void initState() {
    super.initState();
    // Immediately request permission on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _askForNotificationPermission();
    });
  }

  Future<void> _askForNotificationPermission() async {
    setState(() {
      _requesting = true;
      _error = null;
    });

    NotificationSettings? result;
    try {
      result = await FirebaseMessaging.instance
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: true,
            sound: true,
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      result = null;
    } catch (e) {
      debugPrint('[notifications] requestPermission error: $e');
      result = null;
    }

    // If result is null we treat as denied / timed out.
    final allowed =
        result != null &&
        (result.authorizationStatus == AuthorizationStatus.authorized ||
            result.authorizationStatus == AuthorizationStatus.provisional);

    if (allowed) {
      if (!mounted) return;
      setState(() {
        _permissionGranted = true;
      });
      // Navigate to login after a brief visual confirmation
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return;
    }

    // Not allowed — determine current settings (best-effort)
    NotificationSettings? current;
    try {
      current = await FirebaseMessaging.instance
          .getNotificationSettings()
          .timeout(const Duration(seconds: 6));
    } on TimeoutException {
      current = null;
    } catch (_) {
      current = null;
    }

    bool permanentlyDenied = false;
    if (current != null) {
      // On some platforms 'denied' is irreversible without OS settings.
      permanentlyDenied =
          current.authorizationStatus == AuthorizationStatus.denied;
    }

    setState(() {
      _permissionDeniedPermanently = permanentlyDenied;
      _permissionGranted = false;
      _requesting = false;
    });
  }

  // Show a simple instructions dialog guiding the user to the OS settings.
  Future<void> _showOpenSettingsInstructions() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Enable Notifications'),
          content: const Text(
            'Please open your device Settings → Apps → Sacred Heart Hostel → Notifications and enable notifications.\n\n'
            "If your device shows 'Blocked', toggle it on and return to the app.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequesting() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        CircularProgressIndicator(strokeWidth: 4, color: Colors.blue),
        SizedBox(height: 12),
        Text('Requesting notification permission...'),
      ],
    );
  }

  Widget _buildDeniedUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.notifications_off, size: 64, color: Colors.red.shade400),
        const SizedBox(height: 16),
        Text(
          _permissionDeniedPermanently
              ? 'Notifications are blocked. Please enable them in Settings to continue.'
              : 'Notifications are disabled. The app needs notification permission to continue.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: _askForNotificationPermission,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _showOpenSettingsInstructions,
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            // Navigation is intentionally blocked until permission is granted per your request.
            // If you want to allow skipping, uncomment the next line:
            // Navigator.of(context).pushReplacementNamed('/login');
          },
          child: const Text('Need help? Contact support'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _requesting
            ? _buildRequesting()
            : _permissionGranted
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.notifications_active,
                    size: 64,
                    color: Colors.green,
                  ),
                  SizedBox(height: 12),
                  Text('Notification permission granted. Redirecting...'),
                ],
              )
            : _buildDeniedUI(),
      ),
    );
  }
}
