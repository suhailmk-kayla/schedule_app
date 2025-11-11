import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/auth_provider.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

/// Splash Screen
/// Shows logo and checks if user is logged in
/// Converted from KMP's SplashLoginScreen.kt
/// Navigation logic:
/// - If user is already logged in (isUserLogin == "1"): Navigate to HomeScreen
/// - If user is not logged in: Show LoginScreen after 3 seconds
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showLogin = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Initialize auth state from storage
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.initialize();

    // Wait 3 seconds before showing login (like KMP)
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Check if user is already logged in
    if (authProvider.isAuthenticated) {
      // User is already logged in, navigate to home
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    } else {
      // User is not logged in, show login screen
      setState(() {
        _showLogin = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primaryContainer,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo placeholder - replace with actual logo asset
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.inventory_2,
                  size: 50,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 24),
              AnimatedOpacity(
                opacity: _showLogin ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 1000),
                child: _showLogin
                    ? const LoginScreen()
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

