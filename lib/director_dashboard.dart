import 'package:flutter/material.dart';
import 'quick_card.dart';

class DirectorDashboard extends StatelessWidget {
  const DirectorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Header card
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
                          'Welcome — Director',
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

          // Key stats or insights
          const QuickCard(
            title: 'Overall Attendance',
            subtitle: 'Monitor hostel-wide attendance statistics',
            icon: Icons.bar_chart,
          ),
          const SizedBox(height: 8),
          const QuickCard(
            title: 'Leave Requests',
            subtitle: 'View and approve student leave applications',
            icon: Icons.assignment,
          ),
          const SizedBox(height: 8),
          const QuickCard(
            title: 'Announcements',
            subtitle: 'Create or manage official notices',
            icon: Icons.notifications_active,
          ),

          const SizedBox(height: 16),

          // Small info section
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Tip: You can use the Notices tab below to publish important updates to all students.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
