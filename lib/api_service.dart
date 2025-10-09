// lib/api_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'services/cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ApiService._privateConstructor();
  static final ApiService _instance = ApiService._privateConstructor();
  factory ApiService() => _instance;

  late Dio dio;
  late PersistCookieJar cookieJar;

  // IMPORTANT: set your backend base URL here (no trailing slash needed)
  static const String baseUrl = "https://sh-backend.devnoel.org";

  /// Initialize cookie jar and Dio. Call this in main() before runApp().
  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    final cookieDir = "${docs.path}/.cookies/";
    final cookieDirFile = Directory(cookieDir);
    if (!await cookieDirFile.exists())
      await cookieDirFile.create(recursive: true);

    cookieJar = PersistCookieJar(storage: FileStorage(cookieDir));

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // ✅ store & send cookies automatically
    dio.interceptors.add(CookieManager(cookieJar));

    // ✅ verbose logs while debugging
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ),
    );

    // after adding interceptors in init()
    try {
      final stored = await _loadTokenFromStorage(); // from helper above
      if (stored != null && stored.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $stored';
        debugPrint('Restored auth token from storage');
      } else {
        debugPrint('No stored auth token found');
      }
    } catch (e) {
      debugPrint('Error restoring token: $e');
    }
  }

  /// POST /api/auth/login
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      // Clear previous cookies (optional)
      try {
        await cookieJar.deleteAll();
      } catch (_) {}

      final resp = await dio.post(
        '/api/auth/login',
        data: {'username': username, 'password': password},
        options: Options(responseType: ResponseType.json),
      );

      final data = resp.data;
      if (data is Map<String, dynamic>) {
        // try to detect token in common keys
        final token =
            (data['token'] ??
                    data['accessToken'] ??
                    data['access_token'] ??
                    data['data']?['token'])
                ?.toString();

        if (token != null && token.isNotEmpty) {
          // attach token to dio for subsequent requests
          dio.options.headers['Authorization'] = 'Bearer $token';

          // persist token (use CacheService or SharedPreferences)
          try {
            await _saveTokenToStorage(
              token,
            ); // if using shared_preferences helper
            // OR: await CacheService.saveAuthCache(role: ..., username: ..., token: token);
          } catch (e) {
            debugPrint('Failed to persist auth token: $e');
          }

          debugPrint('Saved auth token and attached to dio');
        } else {
          debugPrint('No token found in login response: $data');
        }

        return data;
      }

      return {};
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? e.response?.data);
      }
      throw Exception(e.message);
    }
  }

  Future<void> _saveTokenToStorage(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('auth_token', token);
  }

  Future<String?> _loadTokenFromStorage() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('auth_token');
  }

  /// Central authenticate: uses cached auth info quickly; if forceVerify==true it will call the server (/api/auth/me)
  Future<Map<String, dynamic>> authenticate({bool forceVerify = false}) async {
    // Load cached auth info
    final cached = await CacheService.loadAuthCache();
    final cachedRole = cached['role'];
    final cachedUsername = cached['username'];

    // Check for cookie-based session presence
    try {
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
    } catch (e) {
      debugPrint('Warning: cookieJar not available or failed to read: $e');
      // continue to attempt server verification if requested
    }

    // Force verification with server
    try {
      final resp = await dio.get(
        '/api/auth/me',
        options: Options(responseType: ResponseType.json),
      );
      final data = resp.data as Map<String, dynamic>? ?? {};
      final serverUsername = data['username'] ?? data['user']?['username'];
      final serverRole = data['role'] ?? data['user']?['role'];

      // Update local cache if server provided values
      if (serverRole != null) {
        await CacheService.saveAuthCache(
          role: serverRole.toString(),
          username: serverUsername?.toString(),
        );
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
        'isLoggedIn': cachedRole != null,
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
      try {
        await cookieJar.deleteAll();
      } catch (e) {
        debugPrint('Failed to clear cookies on logout: $e');
      }
    }
  }
}
