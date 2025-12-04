import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/asset_images.dart';
import '../../provider/auth_provider.dart';
import 'login_screen.dart';
import '../../../utils/navigation_helper.dart';
import '../../../utils/push_notification_helper.dart';

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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _showLogin = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _initialize();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // Initialize auth state from storage
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.initialize();

    // Wait 3 seconds before showing login (like KMP)
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Check if user is already logged in
    if (authProvider.isAuthenticated) {
      // User is already logged in
      // Process stored notifications (from when app was terminated)
      // This happens AFTER login check, so we don't process during login sync
      try {
        await PushNotificationHelper.processStoredNotifications();
      } catch (e) {
        // Log error but don't block navigation
        debugPrint('Error processing stored notifications: $e');
      }
      
      // Navigate based on user type (matches KMP BaseScreen.kt logic)
      if (mounted) {
        await NavigationHelper.navigateToInitialScreen(context);
      }
    } else {
      // User is not logged in, show login screen
      // Don't process stored notifications here - they'll be processed after login
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
              // Logo with animated border
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _showLogin?SizedBox():
                    // Animated rotating border
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _animationController.value * 2 * 3.14159,
                          child: SizedBox(
                            width: 110,
                            height: 110,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.8),
                              ),
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        );
                      },
                    ),
                    // Logo container
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        image: const DecorationImage(
                          image: AssetImage(AssetImages.imagesLogo),
                          fit: BoxFit.cover,
                        ),
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
                    ),
                  ],
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

