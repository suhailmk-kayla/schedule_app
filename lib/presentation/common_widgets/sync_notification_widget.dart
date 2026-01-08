import 'package:flutter/material.dart';
import 'package:schedule_frontend_flutter/utils/toast_helper.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../../utils/background_sync_worker.dart';
import '../../di.dart';
import '../../presentation/provider/sync_provider.dart';

/// Widget that checks for sync needed flag and shows snackbar
/// Should be placed in MaterialApp builder or a widget that wraps all screens
class SyncNotificationWidget extends StatefulWidget {
  final Widget child;

  const SyncNotificationWidget({
    super.key,
    required this.child,
  });

  @override
  State<SyncNotificationWidget> createState() => _SyncNotificationWidgetState();
}

class _SyncNotificationWidgetState extends State<SyncNotificationWidget> {
  Timer? _checkTimer;
  bool _hasShownSnackbar = false;

  @override
  void initState() {
    super.initState();
    // Check immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSyncNeeded();
    });
    
    // Check every 30 seconds when app is in foreground
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _checkSyncNeeded();
      }
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkSyncNeeded() async {
    if (!mounted) return;
    
    try {
      final isNeeded = await BackgroundSyncWorker.isSyncNeededFlagSet();
      
      if (isNeeded && !_hasShownSnackbar) {
        _showSyncSnackbar();
        _hasShownSnackbar = true;
      } else if (!isNeeded) {
        // Reset flag if sync is no longer needed
        _hasShownSnackbar = false;
      }
    } catch (e) {
      developer.log('SyncNotificationWidget: Error checking flag: $e');
    }
  }

  void _showSyncSnackbar() {
    if (!mounted) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.sync, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your data is outdated. Please refresh to get the latest updates.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'REFRESH',
          textColor: Colors.white,
          onPressed: () {
            _triggerSync();
          },
        ),
      ),
    );
  }

  void _triggerSync() async {
    // Clear the flag
    await BackgroundSyncWorker.clearSyncNeededFlag();
    _hasShownSnackbar = false;
    
    // Hide current snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    
    // Trigger sync
    try {
      final syncProvider = getIt<SyncProvider>();
      if (!syncProvider.isSyncing) {
        await syncProvider.startSync();
        developer.log('SyncNotificationWidget: Sync triggered from snackbar');
      } else {
        developer.log('SyncNotificationWidget: Sync already in progress');
      }
    } catch (e) {
      developer.log('SyncNotificationWidget: Error triggering sync: $e');
      // Show error snackbar
      if (mounted) {
        ToastHelper.showError('Error starting sync: $e');

      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

