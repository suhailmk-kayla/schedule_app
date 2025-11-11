import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/auth_provider.dart';
import '../../../utils/storage_helper.dart';
import '../sync/sync_screen.dart';

/// Login Screen
/// Handles user authentication
/// Converted from KMP's SplashLoginScreen.kt login form
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isUserAlreadyLogin = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await StorageHelper.getIsUserLogin();
    setState(() {
      _isUserAlreadyLogin = isLoggedIn == '1';
    });
  }

  @override
  void dispose() {
    _userCodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final result = await authProvider.login(
      userCode: _userCodeController.text.trim(),
      password: _passwordController.text,
    );

    result.fold(
      (failure) {
        // Error is already set in AuthProvider, show snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: Colors.red,
          ),
        );
      },
      (userData) async {
        // Login successful
        // Always navigate to sync screen after fresh login
        // (If user was already logged in, they wouldn't see LoginScreen - SplashScreen would navigate to HomeScreen directly)
        if (mounted) {
          // Navigate to sync screen (sync will then navigate to home)
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const SyncScreen(),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              'Schedule App',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),

            // User Code/Name Field
            TextFormField(
            
              controller: _userCodeController,
              decoration: InputDecoration(
                labelText: _isUserAlreadyLogin ? 'User Name' : 'User Code',
                hintText: _isUserAlreadyLogin ? 'Enter user name' : 'Enter user code',
                prefixIcon: const Icon(Icons.person),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter ${_isUserAlreadyLogin ? 'user name' : 'user code'}';
                }
                return null;
              },
              onChanged: (value) {
                // Remove spaces (like KMP does)
                if (value.contains(' ')) {
                  _userCodeController.value = TextEditingValue(
                    text: value.replaceAll(' ', ''),
                    selection: TextSelection.collapsed(
                      offset: value.replaceAll(' ', '').length,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),

            // Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter password';
                }
                if (value.length < 4) {
                  return 'Password must be at least 4 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Error Message
            if (authProvider.errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authProvider.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            // Login Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: authProvider.isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: authProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

