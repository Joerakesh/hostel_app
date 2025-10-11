// lib/role_shell.dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'attendance_page.dart'; // real AttendancePage

// Replace these imports with your actual dashboard files.
// Each file must expose a widget with the exact class name used below.
import 'student_dashboard.dart'; // should export class StudentDashboard
import 'ad_dashboard.dart'; // should export class AdDashboard
import 'director_dashboard.dart'; // should export class DirectorDashboard

import 'shared_header.dart';
import 'shared_footer.dart';
import 'quick_card.dart';
import 'profile_page.dart';

class RoleShell extends StatefulWidget {
  final String role; // 'student' | 'ad' | 'director'
  const RoleShell({super.key, required this.role});

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _currentIndex = 0;
  final Map<int, GlobalKey<NavigatorState>> _navigatorKeys = {
    0: GlobalKey<NavigatorState>(),
    1: GlobalKey<NavigatorState>(),
    2: GlobalKey<NavigatorState>(),
    3: GlobalKey<NavigatorState>(),
  };

  bool get isStudent => widget.role == 'student';
  bool get isAd => widget.role == 'ad';
  bool get isDirector => widget.role == 'director';

  void _onTapBottom(int index) {
    if (_currentIndex == index) {
      final nav = _navigatorKeys[index];
      if (nav != null &&
          nav.currentState != null &&
          nav.currentState!.canPop()) {
        nav.currentState!.popUntil((r) => r.isFirst);
      }
    } else {
      setState(() => _currentIndex = index);
    }
  }

  String _titleForIndex(int index) {
    if (isStudent) {
      const titles = ['Home', 'Utilities', 'Profile'];
      return titles[index.clamp(0, titles.length - 1)];
    }
    if (isAd) {
      const titles = ['Home', 'Students', 'Analytics', 'Profile'];
      return titles[index.clamp(0, titles.length - 1)];
    }
    // director
    const titles = ['Dashboard', 'Notices', 'Leaves', 'Analytics'];
    return titles[index.clamp(0, titles.length - 1)];
  }

  Widget _wrapWithNavigator(int idx, Widget child) {
    final key = _navigatorKeys[idx]!;
    return Navigator(
      key: key,
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => child),
    );
  }

  List<Widget> _buildTabs() {
    if (isStudent) {
      return [
        // Use real StudentDashboard file
        _wrapWithNavigator(0, const StudentDashboard()),
        _wrapWithNavigator(1, const StudentUtilitiesPage()),
        // instead of StudentProfilePage()
        _wrapWithNavigator(2, ProfilePage(role: 'student')),
      ];
    } else if (isAd) {
      return [
        // Use real AdDashboard file
        _wrapWithNavigator(0, const AdDashboard()),
        _wrapWithNavigator(1, const AdStudentsPage()),
        _wrapWithNavigator(2, const AdAnalyticsPage()),

        // instead of AdProfilePage()
        _wrapWithNavigator(3, ProfilePage(role: 'ad')),
      ];
    } else {
      return [
        // Use real DirectorDashboard file
        _wrapWithNavigator(0, const DirectorDashboard()),
        _wrapWithNavigator(1, const DirectorNoticesPage()),
        _wrapWithNavigator(2, const DirectorLeaveRequestsPage()),

        // director:
        _wrapWithNavigator(3, ProfilePage(role: 'director')),
      ];
    }
  }

  void _pushAttendance() {
    final nav = _navigatorKeys[_currentIndex];
    nav?.currentState?.push(
      MaterialPageRoute(builder: (_) => const AttendancePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _buildTabs();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SafeArea(
          top: true,
          child: SharedHeader(
            // Title derived from current index and role
            title: _titleForIndex(_currentIndex),
            // subtitle shows role and optional username (if you want)
            subtitle: widget.role.toUpperCase(),
            // example trailing action: ADs can quickly take attendance on home
            trailing: isAd && _currentIndex == 0
                ? TextButton.icon(
                    onPressed: _pushAttendance,
                    icon: const Icon(
                      Icons.check,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Take',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : null,
          ),
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: SharedFooter(
        role: widget.role,
        currentIndex: _currentIndex,
        onTap: _onTapBottom,
      ),
      floatingActionButton: isAd
          ? FloatingActionButton(
              onPressed: _pushAttendance,
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

/// ---------------- Minimal placeholders for pages that remain in this file
/// Keep these small; dashboard contents are imported from separate files (above)

class StudentUtilitiesPage extends StatelessWidget {
  const StudentUtilitiesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const [
        ListTile(
          leading: Icon(Icons.calendar_today),
          title: Text('Attendance'),
        ),
        ListTile(leading: Icon(Icons.note_add), title: Text('Apply Leave')),
        ListTile(leading: Icon(Icons.restaurant), title: Text('Mess Option')),
      ],
    );
  }
}

class StudentProfilePage extends StatelessWidget {
  const StudentProfilePage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Student Profile'));
}

class AdStudentsPage extends StatelessWidget {
  const AdStudentsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('AD Students'));
}

class AdAnalyticsPage extends StatelessWidget {
  const AdAnalyticsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('AD Analytics'));
}

class AdProfilePage extends StatelessWidget {
  const AdProfilePage({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('AD Profile'));
}

class DirectorNoticesPage extends StatelessWidget {
  const DirectorNoticesPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Director Notices'));
}

class DirectorLeaveRequestsPage extends StatelessWidget {
  const DirectorLeaveRequestsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Leave Requests'));
}

class DirectorAnalyticsPage extends StatelessWidget {
  const DirectorAnalyticsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Director Analytics'));
}
