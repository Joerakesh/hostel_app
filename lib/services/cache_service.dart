import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const _attendanceKey = 'attendance_cache';
  static const _attendanceCachedAtKey = 'attendance_cache_at';

  /// Save raw grouped students map (Map<String, dynamic>) as JSON string.
  static Future<void> saveAttendanceCache(Map<String, dynamic> groupedStudents) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(groupedStudents);
    await prefs.setString(_attendanceKey, jsonStr);
    await prefs.setString(_attendanceCachedAtKey, DateTime.now().toIso8601String());
  }

  /// Return null if not present.
  static Future<Map<String, dynamic>?> loadAttendanceCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_attendanceKey);
    if (jsonStr == null) return null;
    try {
      final Map<String, dynamic> map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map;
    } catch (_) {
      // Corrupt data -> clear it
      await clearAttendanceCache();
      return null;
    }
  }

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

  static Future<void> clearAttendanceCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_attendanceKey);
    await prefs.remove(_attendanceCachedAtKey);
  }

  /// Useful helper: is cache fresh for "today"
  static Future<bool> isAttendanceCacheFreshToday() async {
    final cachedAt = await getAttendanceCachedAt();
    if (cachedAt == null) return false;
    final now = DateTime.now();
    return cachedAt.year == now.year && cachedAt.month == now.month && cachedAt.day == now.day;
  }
}
