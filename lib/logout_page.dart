 import 'package:flutter/material.dart';
import 'api_service.dart';

class LogoutPage extends StatefulWidget {
  const LogoutPage({super.key});

  @override
  State<LogoutPage> createState() => _LogoutPageState();
}

class _LogoutPageState extends State<LogoutPage> {
  @override
  void initState() {
    super.initState();
    _performLogout();
  }

  Future<void> _performLogout() async {
    try {
      // Call backend logout endpoint
      await ApiService().logout();
    } catch (e) {
      debugPrint("❌ Logout failed: $e");
    } finally {
      // Always redirect to login after logout
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // gray-50 equivalent
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Spinner
            const SizedBox(
              height: 32,
              width: 32,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: Colors.black,
                backgroundColor: Color(0xFFE5E7EB), // gray-200
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Logging out...",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
