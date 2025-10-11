import 'package:flutter/material.dart';
import 'quick_card.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Header card with hostel info
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Image.asset('assets/logo.png', height: 56, width: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Sacred Heart Hostel',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Welcome — Student',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Announcements section
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Announcements',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text('No new announcements.'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick actions
          const QuickCard(
            title: 'View Attendance',
            subtitle: 'Check your daily attendance logs',
            icon: Icons.check_circle,
          ),
          const SizedBox(height: 8),
          const QuickCard(
            title: 'Apply for Leave',
            subtitle: 'Submit your leave request',
            icon: Icons.note_add,
          ),
          const SizedBox(height: 8),
          const QuickCard(
            title: 'Mess Menu',
            subtitle: 'View or change your mess plan',
            icon: Icons.restaurant_menu,
          ),
        ],
      ),
    );
  }
}
