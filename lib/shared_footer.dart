// lib/shared_footer.dart
import 'package:flutter/material.dart';

class SharedFooter extends StatelessWidget {
  final String role;
  final int currentIndex;
  final void Function(int) onTap;
  const SharedFooter({
    super.key,
    required this.role,
    required this.currentIndex,
    required this.onTap,
  });

  List<BottomNavigationBarItem> _itemsForRole() {
    if (role == 'student') {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Utilities'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ];
    } else if (role == 'ad') {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Students'),
        BottomNavigationBarItem(
          icon: Icon(Icons.show_chart),
          label: 'Analytics',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ];
    } else {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: 'Notices',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.mark_email_unread),
          label: 'Leaves',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'Analytics',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _itemsForRole();
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: items,
      type: BottomNavigationBarType.fixed,
    );
  }
}
