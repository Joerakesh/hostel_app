// lib/ad_dashboard.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'api_service.dart';

class AdDashboard extends StatefulWidget {
  const AdDashboard({super.key});

  @override
  State<AdDashboard> createState() => _AdDashboardState();
}

class _AdDashboardState extends State<AdDashboard> {
  String adName = 'AD';
  DateTime currentTime = DateTime.now();
  bool loading = true;
  bool checkingSession = true;
  bool redirectingAttendance = false;
  bool redirectingAnalytics = false;
  bool redirectingRecords = false;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _startClock();
    _checkSessionAndLoadProfile();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => currentTime = DateTime.now());
      }
    });
  }

  Future<void> _checkSessionAndLoadProfile() async {
    try {
      final auth = await ApiService().authenticate(); // quick cached response
      final isLoggedIn = auth['isLoggedIn'] == true;
      final role = auth['role']?.toString();
      final cachedUsername = auth['username']?.toString();

      if (!isLoggedIn) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      if (role == 'student') {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/student/dashboard');
        return;
      }

      if (cachedUsername != null && mounted) {
        setState(() => adName = cachedUsername);
      }

      // Only call server when username missing or when you want to refresh
      if (cachedUsername == null) {
        final verified = await ApiService().authenticate(forceVerify: true);
        if (verified['isLoggedIn'] != true) {
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/login');
          return;
        }
        final networkUsername = verified['username']?.toString();
        if (networkUsername != null && mounted)
          setState(() => adName = networkUsername);
      }
    } catch (e) {
      // fallback to login on unexpected error
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          checkingSession = false;
        });
      }
    }
  }

  String _greetingForHour(int hour) {
    if (hour < 6) return 'Good Night';
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  Future<void> _logout() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/logout');
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool disabled,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (disabled)
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: color,
                      size: 16,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (checkingSession || loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading Dashboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final greeting = _greetingForHour(currentTime.hour);
    final formattedDate = MaterialLocalizations.of(
      context,
    ).formatFullDate(currentTime);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              // ---------- Top compact bar: logout on right ----------
              Row(
                children: [
                  const SizedBox(width: 4),
                  // You can keep this empty or put a small back button / spacing here
                  const Spacer(),
                  IconButton(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.grey),
                    tooltip: 'Logout',
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ---------- Logo centered above the card ----------
              Column(
                children: [
                  // Circular logo with subtle shadow
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.white,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(38),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 68,
                          height: 68,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.apartment,
                            size: 36,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Hostel title (clean, bold)
                  Text(
                    'Sacred Heart Hostel',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[900],
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ---------- Welcome gradient card (now acts as a welcome panel) ----------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting,',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adName,
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Date info
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Colors.white.withOpacity(0.85),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Actions Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 12),
                    child: Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  _buildActionCard(
                    title: 'Take Attendance',
                    description: 'Mark attendance for current sessions',
                    icon: Icons.checklist_rounded,
                    color: const Color(0xFF10B981),
                    disabled: redirectingAttendance,
                    onTap: () {
                      setState(() => redirectingAttendance = true);
                      Navigator.of(
                        context,
                      ).pushNamed('/ad/take-attendance').then((_) {
                        if (!mounted) return;
                        setState(() => redirectingAttendance = false);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildActionCard(
                    title: 'Attendance Records',
                    description: 'View and manage attendance history',
                    icon: Icons.history_rounded,
                    color: const Color(0xFFF59E0B),
                    disabled: redirectingRecords,
                    onTap: () {
                      setState(() => redirectingRecords = true);
                      Navigator.of(
                        context,
                      ).pushNamed('/ad/attendance-records').then((_) {
                        if (!mounted) return;
                        setState(() => redirectingRecords = false);
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // You can add stats or other widgets below...
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
