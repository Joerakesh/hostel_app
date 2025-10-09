// lib/attendance_records_page.dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'services/cache_service.dart';

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
      accountNumber:
          m['accountNumber']?.toString() ?? m['accNo']?.toString() ?? '',
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
    final recordsRaw = (m['records'] is List)
        ? List.from(m['records'])
        : <dynamic>[];
    return RawAttendance(
      id: m['_id']?.toString() ?? '',
      adUsername: m['ad']?['username']?.toString() ?? 'Unknown',
      date: DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
      type: m['type']?.toString(),
      records: recordsRaw.map((r) {
        if (r is Map) return RecordEntry.fromMap(Map<String, dynamic>.from(r));
        return RecordEntry(
          id: '',
          name: '',
          roomNo: '',
          accountNumber: '',
          status: '',
        );
      }).toList(),
    );
  }

  // Convert back to Map for caching if needed
  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'ad': {'username': adUsername},
      'date': date.toIso8601String(),
      'type': type,
      'records': records
          .map(
            (r) => {
              '_id': r.id,
              'name': r.name,
              'roomNo': r.roomNo,
              'accountNumber': r.accountNumber,
              'status': r.status,
            },
          )
          .toList(),
    };
  }
}

class AttendanceRecordsPage extends StatefulWidget {
  const AttendanceRecordsPage({super.key});

  @override
  State<AttendanceRecordsPage> createState() => _AttendanceRecordsPageState();
}

class _AttendanceRecordsPageState extends State<AttendanceRecordsPage> {
  bool _loading = true;
  bool _loadingNetwork = false;
  String? _error;
  List<RawAttendance> _groups = [];
  int? _expandedIndex;
  bool _isStale = false; // shows if cache exists but is not fresh (optional)

  @override
  void initState() {
    super.initState();
    _loadFromCacheOnly();
  }

  /// Load from cache only. Do NOT call network automatically.
  Future<void> _loadFromCacheOnly() async {
    setState(() {
      _loading = true;
      _error = null;
      _isStale = false;
    });

    try {
      final cached = await CacheService.loadAttendanceRecordsCache();
      if (cached != null) {
        final list = _normalizeCachedToList(cached);
        final parsed = list
            .map((e) => RawAttendance.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        parsed.sort((a, b) => b.date.compareTo(a.date));

        final fresh = await CacheService.areAttendanceRecordsFresh();

        setState(() {
          _groups = parsed;
          _isStale = !fresh;
          _loading = false;
        });
      } else {
        // No cache — show empty state and stop loading. User must press Refresh to fetch.
        setState(() {
          _groups = [];
          _isStale = false;
          _loading = false;
        });
      }
    } catch (e) {
      // Cache read failure — show empty UI and let user refresh manually.
      setState(() {
        _groups = [];
        _isStale = false;
        _loading = false;
        _error = null; // prefer letting user try refresh
      });
    }
  }

  /// Convert various cached shapes into a List<Map>
  List<Map<String, dynamic>> _normalizeCachedToList(dynamic cached) {
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    if (cached is Map) {
      // if server saved as { "attendance-records": [...] }
      if (cached.containsKey('attendance-records') &&
          cached['attendance-records'] is List) {
        return List.from(
          cached['attendance-records'],
        ).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      }
      // If cached is a map of id => object, convert values
      return cached.values
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  /// Fetch from network. This is called only when user presses Refresh or pull-to-refresh.
  Future<void> _fetchAttendanceRecordsNetwork() async {
    setState(() {
      _loadingNetwork = true;
      _error = null;
    });

    try {
      final resp = await ApiService().dio.get(
        '/api/attendance/get-attendance-records',
      );
      final raw = resp.data;
      final list = (raw?['attendance-records'] is List)
          ? List.from(raw['attendance-records'])
          : <dynamic>[];

      final parsed = list
          .map((e) {
            if (e is Map)
              return RawAttendance.fromMap(Map<String, dynamic>.from(e));
            return null;
          })
          .whereType<RawAttendance>()
          .toList();

      parsed.sort((a, b) => b.date.compareTo(a.date));

      // Save to cache (store the raw list so load/normalize can read it back)
      final toCache = parsed.map((p) => p.toMap()).toList();
      await CacheService.saveAttendanceRecordsCache(toCache);

      setState(() {
        _groups = parsed;
        _error = null;
        _isStale = false;
      });
    } catch (e) {
      if (_groups.isEmpty) {
        setState(() {
          _error = 'Failed to load attendance records: ${e.toString()}';
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to refresh records: ${e.toString()}'),
            ),
          );
        }
      }
    } finally {
      setState(() {
        _loadingNetwork = false;
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                    child: const Icon(
                      Icons.calendar_today,
                      color: Colors.blue,
                      size: 20,
                    ),
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
                  Row(
                    children: [
                      _buildStatusChip(
                        'Present',
                        statusCount['present']!,
                        Colors.green,
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(
                        'Absent',
                        statusCount['absent']!,
                        Colors.red,
                      ),
                      if (statusCount['leave']! > 0) ...[
                        const SizedBox(width: 8),
                        _buildStatusChip(
                          'Leave',
                          statusCount['leave']!,
                          Colors.orange,
                        ),
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
            if (isExpanded) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              ...attendance.records.asMap().entries.map(
                (entry) => _buildStudentRow(entry.value, entry.key),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    await _fetchAttendanceRecordsNetwork();
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
            onPressed: _onRefresh,
            icon: _loadingNetwork
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/ad/dashboard'),
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
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade400,
                    size: 48,
                  ),
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
                    onPressed: _fetchAttendanceRecordsNetwork,
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No cached records. Press Refresh to fetch latest.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _fetchAttendanceRecordsNetwork,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                if (_isStale)
                  MaterialBanner(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor: Colors.yellow.shade50,
                    leading: const Icon(Icons.info_outline),
                    content: const Text(
                      'Showing cached records. Press Refresh for latest.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: _fetchAttendanceRecordsNetwork,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _groups.length,
                      itemBuilder: (context, index) {
                        return _buildAttendanceCard(_groups[index], index);
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
