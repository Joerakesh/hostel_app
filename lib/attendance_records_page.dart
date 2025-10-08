// lib/attendance_records_page.dart
import 'package:flutter/material.dart';
import 'api_service.dart';

class RecordEntry {
  final String id;
  final String name;
  final String roomNo;
  final String accountNumber;
  final String status;

  RecordEntry({
    required this.id,
    required this.name,
    required this.roomNo,
    required this.accountNumber,
    required this.status,
  });

  factory RecordEntry.fromMap(Map m) {
    return RecordEntry(
      id: m['_id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      roomNo: m['roomNo']?.toString() ?? m['roomno']?.toString() ?? '',
      accountNumber: m['accountNumber']?.toString() ?? m['accNo']?.toString() ?? '',
      status: m['status']?.toString() ?? '',
    );
  }
}

class RawAttendance {
  final String id;
  final String adUsername;
  final DateTime date;
  final String? type;
  final List<RecordEntry> records;

  RawAttendance({
    required this.id,
    required this.adUsername,
    required this.date,
    required this.type,
    required this.records,
  });

  factory RawAttendance.fromMap(Map m) {
    final recordsRaw = (m['records'] is List) ? List.from(m['records']) : <dynamic>[];
    return RawAttendance(
      id: m['_id']?.toString() ?? '',
      adUsername: m['ad']?['username']?.toString() ?? 'Unknown',
      date: DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
      type: m['type']?.toString(),
      records: recordsRaw.map((r) => RecordEntry.fromMap(Map<String, dynamic>.from(r))).toList(),
    );
  }
}

class AttendanceRecordsPage extends StatefulWidget {
  const AttendanceRecordsPage({super.key});

  @override
  State<AttendanceRecordsPage> createState() => _AttendanceRecordsPageState();
}

class _AttendanceRecordsPageState extends State<AttendanceRecordsPage> {
  bool _loading = true;
  String? _error;
  List<RawAttendance> _groups = [];
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceRecords();
  }

  Future<void> _fetchAttendanceRecords() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await ApiService().dio.get('/api/attendance/get-attendance-records');
      final raw = resp.data;
      final list = (raw?['attendance-records'] is List) ? List.from(raw['attendance-records']) : <dynamic>[];

      final parsed = list.map((e) {
        if (e is Map) return RawAttendance.fromMap(Map<String, dynamic>.from(e));
        return null;
      }).whereType<RawAttendance>().toList();

      // Sort by date, most recent first
      parsed.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _groups = parsed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load attendance records: ${e.toString()}';
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDay = DateTime(dt.year, dt.month, dt.day);
    
    if (recordDay == today) {
      return 'Today, ${_formatTime(dt)}';
    } else if (recordDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${_formatTime(dt)}';
    } else {
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      return '$day/$month/${dt.year}, ${_formatTime(dt)}';
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  Map<String, int> _getStatusCount(List<RecordEntry> records) {
    int present = 0, absent = 0, leave = 0;
    for (final record in records) {
      switch (record.status.toLowerCase()) {
        case 'present':
          present++;
          break;
        case 'absent':
          absent++;
          break;
        case 'leave':
          leave++;
          break;
      }
    }
    return {'present': present, 'absent': absent, 'leave': leave};
  }

  Widget _buildStatusChip(String status, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRow(RecordEntry record, int index) {
    Color statusColor;
    IconData statusIcon;
    
    switch (record.status.toLowerCase()) {
      case 'present':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'absent':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'leave':
        statusColor = Colors.orange;
        statusIcon = Icons.beach_access;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Room ${record.roomNo} • Acc: ${record.accountNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  record.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(RawAttendance attendance, int index) {
    final statusCount = _getStatusCount(attendance.records);
    final isExpanded = _expandedIndex == index;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header - Always visible
            GestureDetector(
              onTap: () {
                setState(() {
                  _expandedIndex = isExpanded ? null : index;
                });
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(attendance.date),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'By: ${attendance.adUsername}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status summary chips
                  Row(
                    children: [
                      _buildStatusChip('Present', statusCount['present']!, Colors.green),
                      const SizedBox(width: 8),
                      _buildStatusChip('Absent', statusCount['absent']!, Colors.red),
                      if (statusCount['leave']! > 0) ...[
                        const SizedBox(width: 8),
                        _buildStatusChip('Leave', statusCount['leave']!, Colors.orange),
                      ],
                    ],
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),

            // Expandable content
            if (isExpanded) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              // Student list
              ...attendance.records.asMap().entries.map(
                (entry) => _buildStudentRow(entry.value, entry.key),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Attendance Records',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _fetchAttendanceRecords,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/ad/dashboard'),
            icon: const Icon(Icons.home),
            tooltip: 'Dashboard',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading attendance records...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchAttendanceRecords,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _groups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.list_alt, color: Colors.grey.shade400, size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'No Attendance Records',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Attendance records will appear here once marked',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _fetchAttendanceRecords,
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListView.builder(
                        itemCount: _groups.length,
                        itemBuilder: (context, index) {
                          return _buildAttendanceCard(_groups[index], index);
                        },
                      ),
                    ),
    );
  }
}