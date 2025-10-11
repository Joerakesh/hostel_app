import 'package:flutter/material.dart';
import 'api_service.dart';
import 'attendance_page.dart'; // real AttendancePage

// Actual dashboards (make sure these files exist)
import 'student_dashboard.dart';
import 'ad_dashboard.dart';
import 'director_dashboard.dart';

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
        _wrapWithNavigator(0, const StudentDashboard()),
        _wrapWithNavigator(1, const StudentUtilitiesPage()),
        _wrapWithNavigator(2, const ProfilePage(role: 'student')),
      ];
    } else if (isAd) {
      return [
        _wrapWithNavigator(0, const AdDashboard()),
        _wrapWithNavigator(1, const AdStudentsPage()),
        _wrapWithNavigator(2, const AdAnalyticsPage()),
        _wrapWithNavigator(3, const ProfilePage(role: 'ad')),
      ];
    } else {
      return [
        _wrapWithNavigator(0, const DirectorDashboard()),
        _wrapWithNavigator(1, const DirectorNoticesPage()),
        _wrapWithNavigator(2, const DirectorLeaveRequestsPage()),
        _wrapWithNavigator(3, const ProfilePage(role: 'director')),
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
      // ❌ No AppBar or header here
      body: IndexedStack(index: _currentIndex, children: tabs),

      // ✅ Bottom navigation bar
      bottomNavigationBar: SharedFooter(
        role: widget.role,
        currentIndex: _currentIndex,
        onTap: _onTapBottom,
      ),

      // ✅ ADs keep their floating button for Attendance
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

//
// ----------------- Placeholder pages -----------------
//

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
