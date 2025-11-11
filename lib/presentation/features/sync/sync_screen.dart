import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../provider/sync_provider.dart';
import '../home/home_screen.dart';
import '../../../utils/storage_helper.dart';

/// Sync Screen
/// Handles data synchronization
/// Converted from KMP's SyncScreen.kt
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _hasListener = false;

  @override
  void initState() {
    super.initState();
    developer.log('SyncScreen: initState() called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSync();
    });
  }

  Future<void> _startSync() async {
    developer.log('SyncScreen: _startSync() called');
    try {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      
      // Add listener before starting sync
      if (!_hasListener) {
        syncProvider.addListener(_onSyncStateChanged);
        _hasListener = true;
        developer.log('SyncScreen: Listener added to SyncProvider');
      }
      
      // Start sync
      developer.log('SyncScreen: Calling syncProvider.startSync()');
      await syncProvider.startSync();
      developer.log('SyncScreen: syncProvider.startSync() returned');
    } catch (e, stackTrace) {
      developer.log('SyncScreen: Exception in _startSync: $e', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start sync: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSyncStateChanged() {
    developer.log('SyncScreen: _onSyncStateChanged() called');
    if (!mounted) {
      developer.log('SyncScreen: Widget not mounted, ignoring state change');
      return;
    }

    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    developer.log('SyncScreen: isSyncing=${syncProvider.isSyncing}, showError=${syncProvider.showError}, errorMessage=${syncProvider.errorMessage}');
    
    if (!syncProvider.isSyncing) {
      // Sync completed or stopped
      developer.log('SyncScreen: Sync completed or stopped');
      
      if (_hasListener) {
        syncProvider.removeListener(_onSyncStateChanged);
        _hasListener = false;
        developer.log('SyncScreen: Listener removed');
      }
      
      if (mounted) {
        if (syncProvider.showError && syncProvider.errorMessage != null) {
          developer.log('SyncScreen: Sync failed with error: ${syncProvider.errorMessage}');
          // Don't navigate on error, let user see the error
          return;
        }
        
        developer.log('SyncScreen: Sync successful, navigating to HomeScreen');
        // Mark user as logged in
        StorageHelper.setIsUserLogin('1').then((_) {
          developer.log('SyncScreen: isUserLogin set to 1');
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
            );
          }
        }).catchError((e) {
          developer.log('SyncScreen: Error setting isUserLogin: $e');
        });
      }
    }
  }

  @override
  void dispose() {
    developer.log('SyncScreen: dispose() called');
    if (_hasListener) {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      syncProvider.removeListener(_onSyncStateChanged);
      _hasListener = false;
      developer.log('SyncScreen: Listener removed in dispose()');
    }
    super.dispose();
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
        child: SafeArea(
          child: Consumer<SyncProvider>(
            builder: (context, syncProvider, _) {
              // Log only on significant state changes (not every rebuild)
              if (syncProvider.progress > 0 || syncProvider.showError) {
                developer.log('SyncScreen: UI update - isSyncing=${syncProvider.isSyncing}, progress=${(syncProvider.progress * 100).toStringAsFixed(1)}%, task=${syncProvider.currentTask}');
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
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
                          Icons.sync,
                          size: 50,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Current Task
                      Text(
                        syncProvider.currentTask,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Progress Indicator
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Circular Progress
                            CircularProgressIndicator(
                              value: syncProvider.progress,
                              strokeWidth: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                            // Progress Text
                            Text(
                              '${(syncProvider.progress * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Error Message
                      if (syncProvider.showError && 
                          syncProvider.errorMessage != null && 
                          syncProvider.errorMessage!.isNotEmpty)
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
                                  syncProvider.errorMessage ?? 'An error occurred',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Stop Button
                      if (syncProvider.isSyncing)
                        ElevatedButton(
                          onPressed: () {
                            final syncProvider = Provider.of<SyncProvider>(
                              context,
                              listen: false,
                            );
                            syncProvider.stopSync();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Stop Sync'),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

