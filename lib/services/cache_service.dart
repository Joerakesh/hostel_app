import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  // Creating Const for Cache - Attendance, Role, Username
  static const _attendanceKey = 'attendance_cache';
  static const _attendanceCachedAtKey = 'attendance_cache_at';
  static const _attendanceRecordsKey = 'attendance_records_cache';
  static const _attendanceRecordsCachedAtKey = 'attendance_records_cache_at';
  static const _authRoleKey = 'auth_role';
  static const _authUsernameKey = 'auth_username';
  static const _authCachedAtKey = 'auth_cached_at';

  // Saves Auth to cache - Role, Token, Username
  static Future<void> saveAuthCache({
    required String role,
    String? username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authRoleKey, role);
    if (username != null) await prefs.setString(_authUsernameKey, username);
    await prefs.setString(_authCachedAtKey, DateTime.now().toIso8601String());
  }

  // Load cached data - Role, Username
  static Future<Map<String, String?>> loadAuthCache() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'role': prefs.getString(_authRoleKey),
      'username': prefs.getString(_authUsernameKey),
      'cachedAt': prefs.getString(_authCachedAtKey),
    };
  }

  // Save raw grouped students map (Map<String, dynamic>) as JSON string.
  static Future<void> saveAttendanceCache(
    Map<String, dynamic> groupedStudents,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(groupedStudents);
    await prefs.setString(_attendanceKey, jsonStr);
    await prefs.setString(
      _attendanceCachedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  // Return null if not present.
  static Future<Map<String, dynamic>?> loadAttendanceCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_attendanceKey);
    if (jsonStr == null) return null;
    try {
      final Map<String, dynamic> map =
          jsonDecode(jsonStr) as Map<String, dynamic>;
      return map;
    } catch (_) {
      // Corrupt data -> clear it
      await clearAttendanceCache();
      return null;
    }
  }

  // Get Cache Created Date
  static Future<DateTime?> getAttendanceCachedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_attendanceCachedAtKey);
    if (iso == null) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  // Useful helper: is cache fresh for "today"
  static Future<bool> isAttendanceCacheFreshToday() async {
    final cachedAt = await getAttendanceCachedAt();
    if (cachedAt == null) return false;
    final now = DateTime.now();
    return cachedAt.year == now.year &&
        cachedAt.month == now.month &&
        cachedAt.day == now.day;
  }

  // Save attendance records (expected a List or Map) as JSON string.
  static Future<void> saveAttendanceRecordsCache(dynamic records) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(records);
    await prefs.setString(_attendanceRecordsKey, jsonStr);
    await prefs.setString(
      _attendanceRecordsCachedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  // Load attendance records cache. Return null if not present.
  static Future<dynamic> loadAttendanceRecordsCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_attendanceRecordsKey);
    if (jsonStr == null) return null;
    try {
      final decoded = jsonDecode(jsonStr);
      return decoded;
    } catch (_) {
      // Corrupt data -> clear it
      await clearAttendanceRecordsCache();
      return null;
    }
  }

  // Get Cache Created Date for records
  static Future<DateTime?> getAttendanceRecordsCachedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_attendanceRecordsCachedAtKey);
    if (iso == null) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  // Helper: are records fresh (within N hours) — default: 24h
  static Future<bool> areAttendanceRecordsFresh({int withinHours = 24}) async {
    final cachedAt = await getAttendanceRecordsCachedAt();
    if (cachedAt == null) return false;
    final diff = DateTime.now().difference(cachedAt);
    return diff.inHours <= withinHours;
  }

  // Clear Attendance Records Cache
  static Future<void> clearAttendanceRecordsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_attendanceRecordsKey);
    await prefs.remove(_attendanceRecordsCachedAtKey);
  }

  // Clear Attendance Cache
  static Future<void> clearAttendanceCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_attendanceKey);
    await prefs.remove(_attendanceCachedAtKey);
  }

  // Clear Auth Cache
  static Future<void> clearAuthCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authRoleKey);
    await prefs.remove(_authUsernameKey);
    await prefs.remove(_authCachedAtKey);
  }
}
