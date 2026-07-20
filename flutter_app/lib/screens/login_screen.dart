import 'package:flutter/material.dart';
import '../services/local_db_service.dart';
import 'asha_home_screen.dart';
import 'admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _selectedRole = 0; // 0 = ASHA Worker, 1 = Admin

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  void _handleASHALogin() async {
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both Name and Phone Number')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await LocalDbService.loginASHA(
        _nameController.text.trim(),
        _phoneController.text.trim(),
      );

      final token = res['tokens']['access'];
      final user = res['user'];

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome ${user['first_name'] ?? user['username']}!')),
      );

      // Navigate to ASHA Home Screen with token & user data
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ASHAHomeScreen(token: token, user: user),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAdminLogin() async {
    if (_usernameController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both Admin Username and Password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await LocalDbService.loginAdmin(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      final token = res['tokens']['access'];
      final user = res['user'];

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Admin Login Successful! Welcome ${user['username']}')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AdminDashboardScreen(token: token, user: user),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Logo / Icon
                const Icon(Icons.health_and_safety, size: 80, color: Color(0xFF00897B)),
                const SizedBox(height: 12),
                const Text(
                  'T7 HealthVault',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                ),
                const Text('Community Health System', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),

                // Role Selection Segmented Button
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('ASHA Worker'), icon: Icon(Icons.badge)),
                    ButtonSegment(value: 1, label: Text('Admin'), icon: Icon(Icons.admin_panel_settings)),
                  ],
                  selected: {_selectedRole},
                  onSelectionChanged: (val) {
                    setState(() => _selectedRole = val.first);
                  },
                ),
                const SizedBox(height: 28),

                // ASHA Worker Login Form
                if (_selectedRole == 0) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name (as added by Admin)',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleASHALogin,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Login as ASHA Worker', style: TextStyle(fontSize: 16)),
                  ),
                ]
                // Admin Login Form
                else ...[
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Admin Username',
                      prefixIcon: Icon(Icons.account_box),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleAdminLogin,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Login as Admin', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
