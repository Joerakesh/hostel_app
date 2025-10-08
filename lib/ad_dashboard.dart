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
      final authData = await ApiService().authenticate();
      final bool isLoggedIn = authData['isLoggedIn'] == true;
      final String? role = (authData['role'] ?? authData['user']?['role'])?.toString();

      if (!isLoggedIn) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      if (role == 'student') {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/student/dashboard');
        return;
      } else if (role == 'director') {
        // Handle director redirect if needed
      }

      try {
        final resp = await ApiService().dio.get('/api/auth/me');
        final data = resp.data;
        final username = data?['username'] ?? data?['user']?['username'];
        if (username != null && mounted) {
          setState(() => adName = username.toString());
        }
      } catch (_) {
        // ignore profile fetch errors
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not verify session: ${e.toString()}')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
        return;
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
    await ApiService().logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
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
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
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
    final formattedDate = MaterialLocalizations.of(context).formatFullDate(currentTime);
    final formattedTime = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}:${currentTime.second.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              // Header Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 24),
                        ),
                        IconButton(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout, color: Colors.white),
                          tooltip: 'Logout',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$greeting,',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adName,
                      style: const TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.white.withOpacity(0.8), size: 20),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Actions Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 16),
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
                    // Take Attendance button
onTap: () {
  setState(() => redirectingAttendance = true);
  Navigator.of(context).pushNamed('/ad/take-attendance').then((_) {
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
                    // Attendance Records button
onTap: () {
  setState(() => redirectingRecords = true);
  Navigator.of(context).pushNamed('/ad/attendance-records').then((_) {
    if (!mounted) return;
    setState(() => redirectingRecords = false);
  });
},

                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Stats Section (Optional - you can add actual stats here)
              // Container(
              //   padding: const EdgeInsets.all(20),
              //   decoration: BoxDecoration(
              //     color: Colors.white,
              //     borderRadius: BorderRadius.circular(16),
              //     boxShadow: const [
              //       BoxShadow(
              //         color: Colors.black12,
              //         blurRadius: 8,
              //         offset: Offset(0, 2),
              //       ),
              //     ],
              //   ),
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.spaceAround,
              //     children: [
              //       _buildStatItem(
              //         value: 'Today',
              //         label: 'Sessions',
              //         icon: Icons.event_available_rounded,
              //         color: const Color(0xFF3B82F6),
              //       ),
              //       _buildStatItem(
              //         value: '0',
              //         label: 'Pending',
              //         icon: Icons.pending_actions_rounded,
              //         color: const Color(0xFFF59E0B),
              //       ),
              //       _buildStatItem(
              //         value: '100%',
              //         label: 'Efficiency',
              //         icon: Icons.trending_up_rounded,
              //         color: const Color(0xFF10B981),
              //       ),
              //     ],
              //   ),
              // ),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}