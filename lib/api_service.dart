// lib/api_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'services/cache_service.dart';

class ApiService {
  ApiService._privateConstructor();
  static final ApiService _instance = ApiService._privateConstructor();
  factory ApiService() => _instance;

  late Dio dio;
  late PersistCookieJar cookieJar;

  // IMPORTANT: set your backend base URL here
  static const String baseUrl = "https://sh-backend.devnoel.org";

  /// Initialize cookie jar and Dio. Call this in main() before runApp().
  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    final cookieDir = "${docs.path}/.cookies/";

    cookieJar = PersistCookieJar(storage: FileStorage(cookieDir));

    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      // headers: { 'Accept': 'application/json' } // add if needed
    ));

    dio.interceptors.add(CookieManager(cookieJar));
    // Optional debug logging:
    // dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  /// POST /api/auth/login
Future<Map<String, dynamic>> login(String username, String password) async {
  try {
    // Clear previous cookies to force a fresh session
    try {
      await cookieJar.deleteAll();
    } catch (cookieErr) {
      debugPrint('Could not clear cookies inside ApiService.login: $cookieErr');
    }

    final resp = await dio.post('/api/auth/login',
        data: {'username': username, 'password': password},
        options: Options(responseType: ResponseType.json));
    final data = resp.data;
    if (data is Map<String, dynamic>) return data;
    return {};
  } on DioException catch (e) {
    if (e.response != null && e.response?.data != null) {
      throw Exception(e.response?.data['message'] ?? e.response?.data);
    }
    throw Exception(e.message);
  }
}


  /// Central authenticate: uses cached auth info quickly; if forceVerify==true it will call the server (/api/auth/me)
  Future<Map<String, dynamic>> authenticate({bool forceVerify = false}) async {
    // Load cached auth info
    final cached = await CacheService.loadAuthCache();
    final cachedRole = cached['role'];
    final cachedUsername = cached['username'];

    // Check for cookie-based session presence
    final cookies = await cookieJar.loadForRequest(Uri.parse(baseUrl));
    final hasCookie = cookies.isNotEmpty;

    // If not forcing verification, return cached info quickly
    if (!forceVerify) {
      return {
        'isLoggedIn': hasCookie || cachedRole != null,
        'role': cachedRole,
        'username': cachedUsername,
        'fromCache': true,
      };
    }

    // Force verification with server
    try {
      final resp = await dio.get('/api/auth/me', options: Options(responseType: ResponseType.json));
      final data = resp.data as Map<String, dynamic>? ?? {};
      final serverUsername = data['username'] ?? data['user']?['username'];
      final serverRole = data['role'] ?? data['user']?['role'];

      // Update local cache if server provided values
      if (serverRole != null) {
        await CacheService.saveAuthCache(role: serverRole.toString(), username: serverUsername?.toString());
      }

      return {
        'isLoggedIn': true,
        'role': serverRole?.toString() ?? cachedRole,
        'username': serverUsername?.toString() ?? cachedUsername,
        'fromCache': false,
        'data': data,
      };
    } on DioException catch (e) {
      // Network error or server rejected: fall back to cache
      return {
        'isLoggedIn': hasCookie || cachedRole != null,
        'role': cachedRole,
        'username': cachedUsername,
        'fromCache': true,
        'error': e.message ?? e.toString(),
      };
    }
  }

  /// Logout: call backend (best-effort) and clear cookies
  Future<void> logout() async {
    try {
      await dio.get('/api/auth/logout'); // adjust method/path per your backend
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      await cookieJar.deleteAll();
    }
  }
}
