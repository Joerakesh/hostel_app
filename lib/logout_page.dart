// lib/logout_page.dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'services/cache_service.dart'; // <-- add this

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
      await ApiService().logout();
      await CacheService.clearAuthCache();
    } catch (e) {
      debugPrint("❌ Logout failed: $e");
    } finally {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              height: 32,
              width: 32,
              child: CircularProgressIndicator(strokeWidth: 4, color: Colors.black),
            ),
            SizedBox(height: 16),
            Text("Logging out...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}
