import 'package:flutter/material.dart';
import 'api_service.dart';
import 'services/cache_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LogoutPage extends StatefulWidget {
  const LogoutPage({super.key});

  @override
  State<LogoutPage> createState() => _LogoutPageState();
}

class _LogoutPageState extends State<LogoutPage> {
  bool _logoutDone = false;

  @override
  void initState() {
    super.initState();
    _performLogout();
  }

  Future<void> _performLogout() async {
    try {
      // 1️⃣ Logout from backend
      await ApiService().logout();

      // 2️⃣ Clear caches
      await CacheService.clearAuthCache();
      await CacheService.clearAttendanceCache();

      // 3️⃣ Delete local FCM token (so user stops getting notifications)
      try {
        await FirebaseMessaging.instance.deleteToken();
        debugPrint("✅ FCM token deleted successfully");
      } catch (e) {
        debugPrint("⚠️ Failed to delete FCM token: $e");
      }

      // 4️⃣ Show success message
      if (mounted) {
        setState(() => _logoutDone = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Logout successful"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );

        // Delay a moment before redirecting (to let the user see it)
        await Future.delayed(const Duration(seconds: 2));
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      }
    } catch (e) {
      debugPrint("❌ Logout failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Logout failed: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
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
          children: [
            if (!_logoutDone)
              const Column(
                children: [
                  SizedBox(
                    height: 32,
                    width: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Logging out...",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              )
            else
              const Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 48),
                  SizedBox(height: 12),
                  Text(
                    "Logout Successful!",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
