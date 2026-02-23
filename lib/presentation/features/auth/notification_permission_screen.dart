import 'package:flutter/material.dart';
import '../../../utils/notification_permission_enforcer.dart';

/// Blocking screen that prevents app usage until notification permission is granted
/// For internal use apps where notifications are critical
class NotificationPermissionScreen extends StatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  State<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends State<NotificationPermissionScreen> {
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    // Start periodic check after initial delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkPermissionPeriodically();
    });
  }

  /// Check permission status periodically
  /// If granted, allow user to proceed
  void _checkPermissionPeriodically() {
    if (!mounted) return;
    
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _checkAndNavigate();
    });
  }

  Future<void> _checkAndNavigate() async {
    final hasPermission = await NotificationPermissionEnforcer.checkPermission();
    if (hasPermission && mounted) {
      // Permission granted, notify parent to proceed
      Navigator.of(context).pop(true);
    } else {
      // Keep checking
      _checkPermissionPeriodically();
    }
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isChecking = true;
    });

    final granted = await NotificationPermissionEnforcer.requestPermission();

    if (!mounted) return;
    setState(() {
      _isChecking = false;
    });

    if (granted) {
      // Permission granted, proceed
      Navigator.of(context).pop(true);
    } else {
      // Show dialog to open settings
      if (mounted) {
        _showSettingsDialog();
      }
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Block dismissal
      builder: (context) => AlertDialog(
        title: const Text('Notification Permission Required'),
        content: const Text(
          'This app requires notification permission to function properly. '
          'Please enable notifications in your device settings.\n\n'
          'This is an internal app and notifications are essential for receiving '
          'order updates and data synchronization.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              NotificationPermissionEnforcer.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.notifications_active,
                  size: 80,
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Notification Permission Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'This internal app requires notification permission to function properly.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Notifications are essential for:\n'
                  '• Receiving order updates\n'
                  '• Data synchronization\n'
                  '• Critical alerts',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isChecking ? null : _requestPermission,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Enable Notifications',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _showSettingsDialog,
                  child: const Text('Open Settings Manually'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

