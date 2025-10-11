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
import 'student_dashboard.dart'; // should export class StudentDashboard
import 'director_dashboard.dart';
// RoleShell - make sure this file exists: lib/shell/role_shell.dart
import 'role_shell.dart';

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

  // print token for debug
  FirebaseMessaging.instance.getToken().then((t) {
    debugPrint('*** DEBUG: device FCM token => $t');
  });

  // init ApiService (Dio + cookie jar + token restore)
  await ApiService().init();

  // initialize local notifications and register bg handler from your service
  await NotificationService.init();

  // You may register background handler here OR inside NotificationService.init(), but not both.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Add global listeners (safe to add here)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint(
      '*** onMessage: ${message.messageId}, notification=${message.notification}, data=${message.data}',
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint(
      '*** onMessageOpenedApp: ${message.messageId}, data=${message.data}',
    );
    final route = message.data['route'] ?? message.data['screen'];
    if (route is String && route.isNotEmpty) {
      _safeNavigate(route);
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
        // use new text theme names if needed; keep defaults otherwise
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoadingPage(),
        '/login': (context) => const LoginPage(),
        '/logout': (context) => const LogoutPage(),
        '/ad/dashboard': (context) => const AdDashboard(),
        '/student/dashboard': (context) => const StudentDashboard(),
        '/director/dashboard': (context) => const DirectorDashboard(),
        '/ad/take-attendance': (ctx) => const AttendancePage(),
        '/ad/attendance': (ctx) => const AttendancePage(),
        '/ad/attendance-records': (ctx) => const AttendanceRecordsPage(),
      },
    );
  }
}

/// Loading page: requests notification permission first, then routes.
/// After permission is granted:
///  - if user is authenticated -> show role shell (persistent header/footer)
///  - otherwise -> go to /login
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

      // After a small confirmation show correct next screen:
      // If user already authenticated, go to RoleShell; otherwise go to login.
      // Use authenticate(forceVerify:false) to check quickly.
      Future.delayed(const Duration(milliseconds: 250), () async {
        if (!mounted) return;

        try {
          final auth = await ApiService().authenticate(forceVerify: false);
          final isLoggedIn = auth['isLoggedIn'] == true;

          if (isLoggedIn) {
            // Resolve role string (normalized)
            String roleString = 'student';
            try {
              roleString = await ApiService().getCurrentUserRole();
            } catch (e) {
              debugPrint(
                'Failed to get role string, defaulting to student: $e',
              );
            }

            // Push the RoleShell as replacement root
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => RoleShell(role: roleString)),
            );
            return;
          } else {
            // Not logged in -> go to login page
            Navigator.of(context).pushReplacementNamed('/login');
            return;
          }
        } catch (e) {
          debugPrint('Error while resolving auth state: $e');
          // fallback to login if anything goes wrong
          Navigator.of(context).pushReplacementNamed('/login');
          return;
        }
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
