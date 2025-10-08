import 'dart:io';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class ApiService {
  ApiService._privateConstructor();
  static final ApiService _instance = ApiService._privateConstructor();
  factory ApiService() => _instance;

  late Dio dio;
  late PersistCookieJar cookieJar;

  // IMPORTANT: set your backend base URL here (from your message)
  static const String baseUrl = "https://sh-backend.devnoel.org";

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
    // Optional: debug logging
    // dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  /// call GET /api/auth/authenticate
  /// returns a map with keys from backend (e.g. isLoggedIn, role, user)
  Future<Map<String, dynamic>> authenticate() async {
    try {
      final resp = await dio.get('/api/auth/authenticate',
          options: Options(responseType: ResponseType.json));
      final data = resp.data;
      if (data is Map<String, dynamic>) return data;
      return {'isLoggedIn': false};
    } on DioException catch (e) {
      // if server unreachable or other error
      throw Exception(e.response?.data ?? e.message);
    }
  }

  /// call POST /api/auth/login with {username, password}
  /// returns backend response data
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final resp = await dio.post('/api/auth/login',
          data: {'username': username, 'password': password},
          options: Options(responseType: ResponseType.json));
      final data = resp.data;
      if (data is Map<String, dynamic>) return data;
      return {};
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        // map backend error to exception with message
        throw Exception(e.response?.data['message'] ?? e.response?.data);
      }
      throw Exception(e.message);
    }
  }

  /// call POST /api/auth/logout if you need
 Future<void> logout() async {
  try {
    await dio.get('/api/auth/logout'); // or POST depending on backend
  } catch (e) {
    debugPrint('Logout error: $e');
  } finally {
    // clear cookies to remove session
    await cookieJar.deleteAll();
  }
}
}
