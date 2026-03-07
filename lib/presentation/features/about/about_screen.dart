import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:schedule_frontend_flutter/utils/toast_helper.dart';

import '../../provider/auth_provider.dart';
import '../../provider/sync_provider.dart';
import '../../../utils/storage_helper.dart';
import '../auth/splash_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const MethodChannel _urlChannel =
      MethodChannel('com.foms.schedule/url_launcher');

  bool _isProcessing = false;
  String _appName = 'Schedule';
  String _versionName = '';
  String _buildNumber = '';
  int _userType = 0;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final userType = await StorageHelper.getUserType();
    if (!mounted) return;
    setState(() {
      _appName = packageInfo.appName.isNotEmpty ? packageInfo.appName : 'Schedule';
      _versionName = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
      _userType = userType;
    });
  }

  Future<void> _handleLogoutAll() async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout All'),
            content: const Text('Do you want to logout all users from every device?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isProcessing = true;
    });

    try {
      final syncProvider = context.read<SyncProvider>();
      final authProvider = context.read<AuthProvider>();

      await syncProvider.logoutAllUsersFromDevices();
      await syncProvider.clearAllTable();
      await authProvider.logout();

      if (!mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final result = await _urlChannel.invokeMethod<bool>(
        'openUrl',
        {'url': url},
      );
      if (result != true && mounted) {
        _showError('Unable to open link');
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      _showError(e.message ?? 'Unable to open link');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ToastHelper.showError(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTopBar(),
                  _buildLogoSection(),
                  _buildFooter(),
                ],
              ),
            ),
            if (_isProcessing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
        const Spacer(),
        if (_userType == 1)
          ElevatedButton(
            onPressed: _isProcessing ? null : _handleLogoutAll,
            style: ElevatedButton.styleFrom(
              shape: const StadiumBorder(),
              backgroundColor: const Color(0xFF2D2D2D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout All'),
          ),
      ],
    );
  }

  Widget _buildLogoSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: 150,
          height: 150,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 16),
        Text(
          _appName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _versionName.isNotEmpty
              ? 'Version $_versionName ($_buildNumber)'
              : 'Version info not available',
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StoreButton(
              icon: Icons.apple,
              label: 'App Store',
              onTap: () => _openUrl(
                'https://apps.apple.com/in/app/schedule-orders/id6747952309',
              ),
            ),
            const SizedBox(width: 32),
            _StoreButton(
              icon: Icons.android,
              label: 'Google Play',
              onTap: () => _openUrl(
                'https://play.google.com/store/apps/details?id=com.foms.schedule',
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Text(
          'Copyright © 2025 Foms. All rights reserved.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StoreButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StoreButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

