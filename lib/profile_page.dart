// lib/profile_page.dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'cache_service.dart';
import 'notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart'
    show AuthorizationStatus, FirebaseMessaging, NotificationSettings;

class ProfilePage extends StatefulWidget {
  final String role;
  const ProfilePage({super.key, required this.role});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _username;
  bool _busy = false;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadCachedProfile();
    _checkNotificationStatus();
  }

  Future<void> _loadCachedProfile() async {
    try {
      final cached = await CacheService.loadAuthCache();
      setState(() {
        _username = cached['username'] ?? 'Unknown';
      });
    } catch (_) {
      setState(() {
        _username = 'Unknown';
      });
    }
  }

  Future<void> _checkNotificationStatus() async {
    try {
      final NotificationSettings settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (!mounted) return;
      setState(() {
        _notificationsEnabled =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      });
    } catch (e) {
      debugPrint('Failed to get notification settings: $e');
      if (!mounted) return;
      setState(() => _notificationsEnabled = false);
    }
  }

  Future<void> _performLogout() async {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushReplacementNamed('/logout');
  }

  Future<void> _toggleNotifications() async {
    final settings = await NotificationService.requestPermission();
    setState(() {
      _notificationsEnabled =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _notificationsEnabled
              ? 'Notifications enabled ✅'
              : 'Notifications not allowed',
        ),
        backgroundColor: _notificationsEnabled ? Colors.green : Colors.grey,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String? value,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ?? '-',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _notificationsEnabled ? 'Enabled' : 'Disabled',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(
            value: _notificationsEnabled,
            onChanged: (value) => _toggleNotifications(),
            activeColor: Colors.orange,
            activeTrackColor: Colors.orange.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor() {
    switch (widget.role.toLowerCase()) {
      case 'ad':
        return Colors.purple;
      case 'director':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getRoleDisplayName() {
    switch (widget.role.toLowerCase()) {
      case 'ad':
        return 'Administrator';
      case 'director':
        return 'Director';
      default:
        return 'Student';
    }
  }

  @override
  Widget build(BuildContext context) {
    // safe initial letter computation
    final initial = (_username?.isNotEmpty ?? false)
        ? _username![0].toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverAppBar(
              expandedHeight: 180,
              pinned: false,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getRoleColor(),
                        _getRoleColor().withOpacity(0.8),
                      ],
                    ),
                  ),
                  // Align bottom to avoid Column trying to fill the constrained height.
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      // make the inner Column take minimal space so it won't overflow
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _username ?? 'Unknown User',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getRoleDisplayName(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),

                // Profile Information Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROFILE INFORMATION',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        Icons.person_rounded,
                        'Username',
                        _username,
                        Colors.blue,
                      ),
                      _buildInfoRow(
                        Icons.badge_rounded,
                        'Role',
                        _getRoleDisplayName(),
                        _getRoleColor(),
                      ),
                      _buildNotificationToggle(),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Account Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACCOUNT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_rounded,
                                  color: Colors.grey.shade400,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Signed in as ${_username ?? '—'}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade50,
                                  foregroundColor: Colors.red,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.red.shade200,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                onPressed: _busy ? null : _performLogout,
                                icon: const Icon(
                                  Icons.logout_rounded,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Logout',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // App Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text(
                        'Hostel Management System',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
