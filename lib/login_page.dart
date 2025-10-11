// lib/login_page.dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'cache_service.dart';
import 'notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'role_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;
  String? _error;
  final _formKey = GlobalKey<FormState>();

  // Local normalizer — returns 'student' | 'ad' | 'director'
  String _normalizeRole(String raw) {
    final r = raw.trim().toLowerCase();
    if (r == 'ad' ||
        r == 'assistant' ||
        r.contains('assistant') ||
        r == 'assistant_director' ||
        r == 'assistant director' ||
        r.contains('ad'))
      return 'ad';
    if (r == 'director' || r.contains('director')) return 'director';
    return 'student';
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Request notification permission (best-effort)
      final settings = await NotificationService.requestPermission();
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      // Perform login POST
      final loginResp = await ApiService().login(
        _username.text.trim(),
        _password.text,
      );

      // After login: ask server for authoritative auth state (uses cookies / token)
      Map<String, dynamic> authInfo = {};
      try {
        authInfo = await ApiService().authenticate(forceVerify: true);
        debugPrint('authenticate(forceVerify:true) => $authInfo');
      } catch (aErr) {
        debugPrint('authenticate() after login failed: $aErr');
      }

      // Derive canonical role & username (prefer authInfo, fallback to login response)
      String canonicalRole = '';
      String? canonicalUsername;

      if (authInfo.isNotEmpty) {
        canonicalRole = (authInfo['role'] ?? '').toString();
        canonicalUsername =
            (authInfo['username'] ?? authInfo['user']?['username'])?.toString();
      }

      // Fallback to login response body (defensive)
      canonicalRole = canonicalRole.isNotEmpty
          ? canonicalRole
          : (loginResp['user']?['role'] ?? loginResp['role'] ?? '').toString();
      canonicalUsername =
          (canonicalUsername != null && canonicalUsername.isNotEmpty)
          ? canonicalUsername
          : (loginResp['user']?['username'] ?? loginResp['username'])
                ?.toString();

      final role = canonicalRole.isNotEmpty
          ? _normalizeRole(canonicalRole)
          : 'student';
      final username = canonicalUsername;

      // Persist canonical auth cache (role + username)
      try {
        await CacheService.saveAuthCache(
          role: role,
          username: username?.toString(),
        );
        final sp = await SharedPreferences.getInstance();
        await sp.setString('role', role);
        if (username != null && username.isNotEmpty) {
          await sp.setString('username', username);
        }
      } catch (e) {
        debugPrint('Warning: failed to persist canonical auth info: $e');
      }

      // Debug: list cookies (helpful when server uses cookie-based session)
      try {
        final cookies = await ApiService().cookieJar.loadForRequest(
          Uri.parse(ApiService.baseUrl),
        );
        debugPrint(
          'Cookies after login: ${cookies.map((c) => '${c.name}=${c.value}').toList()}',
        );
      } catch (cookieErr) {
        debugPrint('Failed to list cookies after login: $cookieErr');
      }

      // If AD: preload AD-specific caches (best-effort)
      if (role == 'ad') {
        try {
          final respStudents = await ApiService().dio.get('/api/attendance');
          final studentsData = respStudents.data;
          if (studentsData != null && studentsData['students'] != null) {
            await CacheService.saveAttendanceCache(
              Map<String, dynamic>.from(studentsData['students']),
            );
          }
        } catch (e) {
          debugPrint('Preload grouped students cache failed: $e');
        }

        try {
          final respRecords = await ApiService().dio.get(
            '/api/attendance/get-attendance-records',
          );
          final recordsData = respRecords.data;
          if (recordsData != null &&
              recordsData['attendance-records'] != null) {
            await CacheService.saveAttendanceRecordsCache(
              recordsData['attendance-records'],
            );
          } else {
            await CacheService.saveAttendanceRecordsCache(recordsData);
          }
        } catch (e) {
          debugPrint('Preload attendance records failed: $e');
        }
      }

      // Navigate into RoleShell for all recognized roles
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RoleShell(role: role)),
      );
      return;
    } on Exception catch (e) {
      // Dio exceptions are wrapped as Exception in ApiService; show friendly message
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } catch (e) {
      // Unexpected errors
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo and Title
                Column(
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 80,
                      width: 80,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sacred Heart Hostel',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "St. Joseph's College, Trichy",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Portal',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Login Form
                Container(
                  width: 400,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Username Field
                        TextFormField(
                          controller: _username,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.blue),
                            ),
                            prefixIcon: Icon(
                              Icons.person,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Please enter username';
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Password Field
                        TextFormField(
                          controller: _password,
                          obscureText: !_showPassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.blue),
                            ),
                            prefixIcon: Icon(
                              Icons.lock,
                              color: Colors.grey.shade600,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Please enter password';
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Error Message
                        if (_error != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade600,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (_error != null) const SizedBox(height: 16),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _loading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Footer Note
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Use your assigned credentials to access your dashboard',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
