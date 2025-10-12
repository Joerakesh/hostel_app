// lib/models/student_profile.dart
class StudentProfile {
  final String id; // optional if server returns _id
  final String dNo;
  final int? accNo;
  final String name;
  final String block;
  final String roomNo;
  final String religion;
  final String? parentNo;
  final String? studentNo;
  final String role;

  StudentProfile({
    required this.id,
    required this.dNo,
    required this.accNo,
    required this.name,
    required this.block,
    required this.roomNo,
    required this.religion,
    this.parentNo,
    this.studentNo,
    required this.role,
  });

  factory StudentProfile.fromMap(Map<String, dynamic> m) {
    // backend may use accNo as number or string; try both
    int? acc;
    if (m['accNo'] is int) {
      acc = m['accNo'] as int;
    } else if (m['accNo'] is String) {
      acc = int.tryParse(m['accNo'] as String);
    } else {
      acc = null;
    }

    return StudentProfile(
      id: (m['_id'] ?? m['id'] ?? '').toString(),
      dNo: (m['dNo'] ?? '').toString(),
      accNo: acc,
      name: (m['name'] ?? '').toString(),
      block: (m['block'] ?? '').toString(),
      roomNo: (m['roomNo'] ?? '').toString(),
      religion: (m['religion'] ?? 'Not Specified').toString(),
      parentNo: m['parentNo']?.toString(),
      studentNo: m['studentNo']?.toString(),
      role: (m['role'] ?? 'student').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'dNo': dNo,
      'accNo': accNo,
      'name': name,
      'block': block,
      'roomNo': roomNo,
      'religion': religion,
      'parentNo': parentNo,
      'studentNo': studentNo,
      'role': role,
    };
  }
}
