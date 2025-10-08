import 'package:flutter/material.dart';
import 'api_service.dart';

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

  Future<void> _handleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService().login(_username.text.trim(), _password.text);
      // backend expected to return user information (including role)
      final role = data['user']?['role'] ?? data['role'];

      if (role == 'ad') {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/ad/dashboard');
      } else if (role == 'director') {
        // handle director route if added
        // Navigator.of(context).pushReplacementNamed('/director/dashboard');
        setState(() {
          _error = "Logged in but role is not 'ad'. Role: $role";
        });
      } else if (role == 'student') {
        setState(() {
          _error = "Logged in but role is not 'ad'. Role: $role";
        });
      } else {
        // If backend returns custom structure, handle accordingly
        setState(() {
          _error = "Login succeeded but unknown role: $role";
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
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
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // logo placeholder
                Image.asset('assets/logo.png', height: 80, fit: BoxFit.contain),
                const SizedBox(height: 12),
                const Text(
                  'Sacred Heart Hostel',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text("St. Joseph's College, Trichy",
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 20),

                TextField(
                  controller: _username,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _loading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Login'),
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
