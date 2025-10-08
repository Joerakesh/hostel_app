import 'package:flutter/material.dart';
import 'api_service.dart';
import 'login_page.dart';
import 'ad_dashboard.dart';
import 'logout_page.dart';
import 'attendance_page.dart';
import 'attendance_records_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService().init(); // initialize Dio + cookie jar
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

      if (role == 'ad') {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/ad/dashboard');
      } else if (role == 'director') {
        // adjust route if you add director's page
        // Navigator.of(context).pushReplacementNamed('/director/dashboard');
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
