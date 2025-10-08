// lib/attendance_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';

class Student {
  final String id;
  final String name;
  final String dNo;
  final dynamic accNo;
  final String roomNo;
  final bool leave;
  
  Student({
    required this.id,
    required this.name,
    required this.dNo,
    required this.accNo,
    required this.roomNo,
    required this.leave,
  });

  factory Student.fromMap(Map m) {
    return Student(
      id: m['_id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      dNo: m['dNo']?.toString() ?? '',
      accNo: m['accNo'] ?? m['accno'] ?? '',
      roomNo: m['roomNo']?.toString() ?? m['roomno']?.toString() ?? '',
      leave: m['leave'] == true,
    );
  }
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  bool _loading = true;
  bool _saving = false;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  Map<String, List<Student>> _groupedStudents = {};
  final Map<String, String> _statusMap = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _startClock();
    _checkAuthAndFetch();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _checkAuthAndFetch() async {
    try {
      final auth = await ApiService().authenticate();
      final bool isLoggedIn = auth['isLoggedIn'] == true;
      final role = (auth['role'] ?? auth['user']?['role'])?.toString();

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

      final resp = await ApiService().dio.get('/api/attendance');
      final data = resp.data;
      final rawGroups = data['students'] as Map<dynamic, dynamic>?;

      final Map<String, List<Student>> parsed = {};
      if (rawGroups != null) {
        rawGroups.forEach((key, value) {
          final list = <Student>[];
          if (value is List) {
            for (final item in value) {
              if (item is Map) list.add(Student.fromMap(Map<String, dynamic>.from(item)));
            }
          }
          parsed[key.toString()] = list;
        });
      }

      if (mounted) {
        setState(() {
          _groupedStudents = parsed;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load attendance: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _groupedStudents = {};
          _loading = false;
        });
      }
    }
  }

  void _setStatus(String accNo, String status) {
    setState(() {
      _statusMap[accNo] = status;
    });
  }

  Map<String, int> _getSummary() {
    int present = 0, absent = 0, leave = 0;
    _groupedStudents.values.forEach((students) {
      for (final s in students) {
        final status = s.leave ? 'leave' : (_statusMap[s.accNo.toString()] ?? 'present');
        if (status == 'leave') leave++;
        else if (status == 'absent') absent++;
        else present++;
      }
    });
    return {'present': present, 'absent': absent, 'leave': leave};
  }

  List<String> _sortedRoomKeys() {
    final keys = _groupedStudents.keys.toList();
    keys.sort((a, b) {
      final aParts = a.split('-');
      final bParts = b.split('-');
      final blockA = aParts.isNotEmpty ? aParts[0] : '';
      final blockB = bParts.isNotEmpty ? bParts[0] : '';
      if (blockA != blockB) return blockA.compareTo(blockB);
      final roomA = aParts.length > 1 ? int.tryParse(aParts[1]) ?? 0 : 0;
      final roomB = bParts.length > 1 ? int.tryParse(bParts[1]) ?? 0 : 0;
      return roomA.compareTo(roomB);
    });
    return keys;
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    
    final summary = _getSummary();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Attendance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to save this attendance?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Present', summary['present']!, Colors.green),
                  _buildSummaryRow('Absent', summary['absent']!, Colors.red),
                  _buildSummaryRow('On Leave', summary['leave']!, Colors.orange),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Save Attendance'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;

    setState(() => _saving = true);

    final records = <Map<String, dynamic>>[];
    _groupedStudents.values.forEach((students) {
      for (final s in students) {
        records.add({
          'roomNo': s.roomNo,
          'accountNumber': s.accNo,
          'name': s.name,
          'status': s.leave ? 'leave' : (_statusMap[s.accNo.toString()] ?? 'present'),
        });
      }
    });

    try {
      await ApiService().dio.post('/api/attendance/mark', data: {'records': records});
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.of(context).pushReplacementNamed('/ad/attendance-records');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save attendance: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildSummaryRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Text('$count', style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_statusMap.isEmpty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved attendance changes. Leave without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _formatNow() {
    final day = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][_now.weekday % 7];
    final month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][_now.month - 1];
    final hour = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final ampm = _now.hour >= 12 ? 'PM' : 'AM';
    final hh = hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    final ss = _now.second.toString().padLeft(2, '0');
    return '$day, ${_now.day} $month ${_now.year} • $hh:$mm:$ss $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final summary = _getSummary();

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Take Attendance',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          foregroundColor: Colors.black,
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/ad/dashboard'),
              icon: const Icon(Icons.home),
              tooltip: 'Dashboard',
            ),
          ],
        ),
        body: _loading
            ? _buildLoadingState()
            : _buildContent(summary),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade100,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Attendance Data',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Map<String, int> summary) {
    return Column(
      children: [
        // Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.indigo.shade50,
              ],
            ),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.calendar_today, color: Colors.blue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Today\'s Attendance',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _formatNow(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Summary Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryChip('Present', summary['present']!, Colors.green),
              _buildSummaryChip('Absent', summary['absent']!, Colors.red),
              _buildSummaryChip('Leave', summary['leave']!, Colors.orange),
            ],
          ),
        ),

        // Rooms List with smooth scrolling
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: true,
              overscroll: false,
              physics: const BouncingScrollPhysics(),
            ),
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.all(16),
              itemCount: _sortedRoomKeys().length,
              itemBuilder: (context, index) {
                final roomKey = _sortedRoomKeys()[index];
                return _buildRoomCard(roomKey);
              },
            ),
          ),
        ),

        // Save Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 20),
                  label: _saving
                      ? const Text('Saving...', style: TextStyle(fontSize: 16))
                      : const Text('Save Attendance', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
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
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(String roomKey) {
    final students = _groupedStudents[roomKey] ?? [];
    final parts = roomKey.split('-');
    final block = parts.isNotEmpty ? parts[0] : '';
    final roomNo = parts.length > 1 ? parts[1] : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.meeting_room, color: Colors.blue, size: 16),
                ),
                const SizedBox(width: 12),
                Text(
                  'Block $block • Room $roomNo',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${students.length} students',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Students List
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: students.map((student) => _buildStudentRow(student)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRow(Student student) {
    final accKey = student.accNo.toString();
    final status = student.leave ? 'leave' : (_statusMap[accKey] ?? 'present');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: student.leave ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: student.leave ? Colors.grey.shade300 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Student Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: student.leave ? Colors.grey.shade600 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'D.No: ${student.dNo} • Acc: ${student.accNo}',
                  style: TextStyle(
                    fontSize: 13,
                    color: student.leave ? Colors.grey.shade500 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),

          // Status Controls
          if (student.leave)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.beach_access, color: Colors.orange.shade600, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'On Leave',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                _buildStatusButton('P', 'Present', status == 'present', () => _setStatus(accKey, 'present')),
                const SizedBox(width: 8),
                _buildStatusButton('A', 'Absent', status == 'absent', () => _setStatus(accKey, 'absent')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String label, String tooltip, bool active, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? (label == 'P' ? Colors.green : Colors.red) : Colors.white,
            border: Border.all(
              color: active ? (label == 'P' ? Colors.green : Colors.red) : Colors.grey.shade400,
              width: active ? 0 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: active ? [
              BoxShadow(
                color: (label == 'P' ? Colors.green : Colors.red).withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}