// lib/profile_page.dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class ProfilePage extends StatefulWidget {
  final String role; // 'student' | 'ad' | 'director'
  const ProfilePage({super.key, required this.role});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _username;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadCachedProfile();
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

  Future<void> _performLogout() async {
    if (!mounted) return;
    // Use the root navigator so the global app routes are used
    Navigator.of(context, rootNavigator: true).pushReplacementNamed('/logout');
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.blue.shade50,
        child: Icon(icon, color: Colors.blue.shade700),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(value ?? '-', style: const TextStyle(fontSize: 13)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = widget.role.toUpperCase();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Image.asset('assets/logo.png', height: 44, width: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sacred Heart Hostel',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.grey[900],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          roleLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : _performLogout,
                    icon: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout, color: Colors.redAccent),
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // Profile Info Card
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Profile',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Account details & session',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Divider(),
                          _buildInfoRow(Icons.person, 'Username', _username),
                          _buildInfoRow(Icons.badge, 'Role', widget.role),
                          ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.notifications),
                            ),
                            title: const Text('Notifications'),
                            subtitle: const Text(
                              'Manage FCM subscriptions & preferences',
                            ),
                            trailing: IconButton(
                              onPressed: () async {
                                final settings =
                                    await NotificationService.requestPermission();
                                final ok =
                                    settings.authorizationStatus ==
                                        AuthorizationStatus.authorized ||
                                    settings.authorizationStatus ==
                                        AuthorizationStatus.provisional;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Notifications allowed'
                                          : 'Notifications not allowed',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Logout Button Card
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            'Signed in as ${_username ?? '—'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _busy ? null : _performLogout,
                              icon: const Icon(Icons.logout),
                              label: const Text('Logout'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
