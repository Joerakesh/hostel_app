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
    // Example: Tue, 08 Oct 2025 11:14 AM
    final wk = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final mon = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final day = wk[dt.weekday % 7];
    final month = mon[dt.month - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day, ${dt.day} $month ${dt.year}  $hour:$minute $ampm';
  }

  Color _statusBg(String status) {
    final s = status.toLowerCase();
    if (s == 'present') return Colors.green.shade100;
    if (s == 'leave') return Colors.orange.shade100;
    return Colors.red.shade100;
  }

  Color _statusText(String status) {
    final s = status.toLowerCase();
    if (s == 'present') return Colors.green.shade800;
    if (s == 'leave') return Colors.orange.shade800;
    return Colors.red.shade800;
  }

  Widget _buildRecordRow(RecordEntry r, int index, bool isCompact) {
    // For compact screens use vertical card rows, otherwise a table-like row
    if (isCompact) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${index + 1}. ${r.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Room: ${r.roomNo}', style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 12),
                Text('Acc: ${r.accountNumber}', style: const TextStyle(fontSize: 13)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusBg(r.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(r.status.toUpperCase(),
                      style: TextStyle(color: _statusText(r.status), fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ],
            )
          ],
        ),
      );
    }

    // wide/table row
    return Container(
      color: index % 2 == 0 ? Colors.transparent : Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('${index + 1}')),
          Expanded(flex: 3, child: Text(r.name)),
          Expanded(flex: 2, child: Text(r.roomNo)),
          Expanded(flex: 2, child: Text(r.accountNumber)),
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusBg(r.status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(r.status.toUpperCase(),
                    style: TextStyle(color: _statusText(r.status), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(RawAttendance g, bool isCompact) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assistant Director: ${g.adUsername}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Date: ${_formatDate(g.date)}', style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                if (g.type != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(g.type!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // records
            if (g.records.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No records for this group.'),
              )
            else if (isCompact)
              Column(
                children: g.records
                    .asMap()
                    .entries
                    .map((e) => _buildRecordRow(e.value, e.key, true))
                    .toList(),
              )
            else
              // table-like view
              Column(
                children: [
                  // table header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: const [
                        SizedBox(width: 36, child: Text('#', style: TextStyle(fontWeight: FontWeight.w700))),
                        Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.w700))),
                        Expanded(flex: 2, child: Text('Room No', style: TextStyle(fontWeight: FontWeight.w700))),
                        Expanded(flex: 2, child: Text('Acc No', style: TextStyle(fontWeight: FontWeight.w700))),
                        SizedBox(width: 110, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...g.records.asMap().entries.map((e) => _buildRecordRow(e.value, e.key, false)).toList(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Attendance Records'),
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(
            onPressed: _fetchAttendanceRecords,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/ad/dashboard'),
            child: const Text('Dashboard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _fetchAttendanceRecords, child: const Text('Retry')),
                        ],
                      )
                    : _groups.isEmpty
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('No attendance records found.'),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _fetchAttendanceRecords, child: const Text('Refresh')),
                            ],
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _groups.length,
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, idx) {
                              final g = _groups[idx];
                              return _buildGroupCard(g, isCompact);
                            },
                          ),
          ),
        ),
      ),
    );
  }
}
