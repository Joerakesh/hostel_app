// lib/profile_page.dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'cache_service.dart';
import 'notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart'
    show AuthorizationStatus, FirebaseMessaging, NotificationSettings;

import 'models/student_profile.dart'; // make sure this path matches your project

class ProfilePage extends StatefulWidget {
  final String role;
  const ProfilePage({super.key, required this.role});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  StudentProfile? _student;
  Map<String, dynamic>? _rawProfile; // fallback if model isn't available
  bool _busy = false;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadCachedProfile();
    _checkNotificationStatus();

    // Optional: attempt server refresh (uncomment to enable)
    // _refreshProfileFromServer();
  }

  /// Load profile from CacheService. Prefer the typed model, but keep raw map
  /// as fallback (some older caches may store different shapes).
  Future<void> _loadCachedProfile() async {
    try {
      // Try the typed loader first (returns StudentProfile?).
      final StudentProfile? model = await CacheService.loadProfileAsModel();
      if (model != null) {
        if (!mounted) return;
        setState(() {
          _student = model;
          _rawProfile = model.toMap();
        });
        return;
      }

      // Fallback: raw map
      final Map<String, dynamic>? map = await CacheService.loadProfileCache();
      if (!mounted) return;
      if (map != null) {
        setState(() {
          _rawProfile = map;
          try {
            _student = StudentProfile.fromMap(map);
          } catch (_) {
            _student = null;
          }
        });
      } else {
        setState(() {
          _student = null;
          _rawProfile = null;
        });
      }
    } catch (e) {
      debugPrint('Failed to load cached profile: $e');
      if (!mounted) return;
      setState(() {
        _student = null;
        _rawProfile = null;
      });
    }
  }

  /// Optional: refresh profile from server and update cache.
  ///
  /// NOTE: Adjust ApiService.fetchProfile() to your real API method name/signature.
  /// This function handles either a Map<String, dynamic> or StudentProfile return.
  // Future<void> _refreshProfileFromServer() async {
  //   try {
  //     setState(() => _busy = true);

  //     final dynamic res = await ApiService.fetchProfile(); // <-- adapt this

  //     if (res == null) return;

  //     if (res is StudentProfile) {
  //       _student = res;
  //       _rawProfile = res.toMap();
  //       await CacheService.saveProfileCache(_rawProfile!);
  //     } else if (res is Map<String, dynamic>) {
  //       _rawProfile = res;
  //       try {
  //         _student = StudentProfile.fromMap(res);
  //       } catch (_) {
  //         _student = null;
  //       }
  //       await CacheService.saveProfileCache(res);
  //     } else {
  //       // unexpected shape; try toJson() if model-like
  //       try {
  //         final map = (res as dynamic).toJson() as Map<String, dynamic>;
  //         _rawProfile = map;
  //         _student = StudentProfile.fromMap(map);
  //         await CacheService.saveProfileCache(map);
  //       } catch (e) {
  //         debugPrint('Unrecognized profile response shape: $e');
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint('Failed to refresh profile from server: $e');
  //   } finally {
  //     if (mounted) setState(() => _busy = false);
  //   }
  // }

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
    final roleString = (widget.role).toLowerCase();
    switch (roleString) {
      case 'ad':
        return Colors.purple;
      case 'director':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getRoleDisplayName() {
    final roleString = (widget.role).toLowerCase();
    switch (roleString) {
      case 'ad':
        return 'Administrator';
      case 'director':
        return 'Director';
      default:
        return 'Student';
    }
  }

  // Unified getter: prefer typed model, fallback to raw map, finally default.
  String? _get(String key) {
    if (_student != null) {
      switch (key) {
        case 'name':
          return _student!.name;
        case 'dNo':
          return _student!.dNo;
        case 'accNo':
          return _student!.accNo?.toString();
        case 'studentNo':
          return _student!.studentNo;
        case 'parentNo':
          return _student!.parentNo;
        case 'block':
          return _student!.block;
        case 'roomNo':
          return _student!.roomNo;
        case 'religion':
          return _student!.religion;
        case 'role':
          return _student!.role;
        case 'id':
        case '_id':
          return _student!.id;
        default:
          return null;
      }
    }
    if (_rawProfile != null && _rawProfile!.containsKey(key)) {
      final v = _rawProfile![key];
      return v == null ? null : v.toString();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final name = _get('name');
    final initial = (name?.isNotEmpty ?? false) ? name![0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
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

                      // Name row (big)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: _getRoleColor().withOpacity(0.1),
                              child: Text(
                                initial,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _getRoleColor(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name ?? 'Unknown User',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor().withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _get('role') ?? _getRoleDisplayName(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getRoleColor(),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Other profile rows:
                      _buildInfoRow(
                        Icons.credit_card_rounded,
                        'D No',
                        _get('dNo'),
                        Colors.teal,
                      ),
                      _buildInfoRow(
                        Icons.account_balance_wallet_rounded,
                        'Account No',
                        _get('accNo'),
                        Colors.indigo,
                      ),
                      _buildInfoRow(
                        Icons.people_alt_rounded,
                        'Student No',
                        _get('studentNo'),
                        Colors.green,
                      ),
                      _buildInfoRow(
                        Icons.phone_iphone_rounded,
                        'Parent No',
                        _get('parentNo'),
                        Colors.pink,
                      ),
                      _buildInfoRow(
                        Icons.house_rounded,
                        'Block',
                        _get('block'),
                        Colors.brown,
                      ),
                      _buildInfoRow(
                        Icons.meeting_room_rounded,
                        'Room No',
                        _get('roomNo'),
                        Colors.cyan,
                      ),
                      _buildInfoRow(
                        Icons.book_rounded,
                        'Religion',
                        _get('religion'),
                        Colors.deepOrange,
                      ),
                      _buildInfoRow(
                        Icons.badge_rounded,
                        'Role',
                        _get('role') ?? _getRoleDisplayName(),
                        _getRoleColor(),
                      ),

                      const SizedBox(height: 12),
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
                                    'Signed in as ${name ?? '—'}',
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
