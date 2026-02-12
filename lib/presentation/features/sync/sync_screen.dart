import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../provider/sync_provider.dart';
import '../../../utils/navigation_helper.dart';
import '../../../utils/storage_helper.dart';
import '../../../utils/asset_images.dart';
import '../../../utils/push_notification_helper.dart';

/// Sync Screen
/// Handles data synchronization
/// Converted from KMP's SyncScreen.kt
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen>
    with SingleTickerProviderStateMixin {
  bool _hasListener = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
     
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSync();
    });
  }

  Future<void> _startSync() async {
     
    try {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      
      // Add listener before starting sync
      if (!_hasListener) {
        syncProvider.addListener(_onSyncStateChanged);
        _hasListener = true;
         
      }
      
      // Start sync
       
      await syncProvider.startSync();
       
    } catch (e, stackTrace) {
       
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

  void _onSyncStateChanged()async{
     
    if (!mounted) {
       
      return;
    }

    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
     
    
    if (!syncProvider.isSyncing) {
      // Sync completed or stopped
       
      
      if (_hasListener) {
        syncProvider.removeListener(_onSyncStateChanged);
        _hasListener = false;
         
      }
      
      if (mounted) {
        if (syncProvider.showError && syncProvider.errorMessage != null) {
           
          // Don't navigate on error, let user see the error
          return;
        }
        
         
        // CRITICAL FIX: Wait a bit to ensure all database transactions are fully committed
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Mark user as logged in
        await StorageHelper.setIsUserLogin('1');
         
        
        // Process stored notifications (from when app was terminated)
        // This happens AFTER login sync completes, so we don't interfere with login sync
        try {
          await PushNotificationHelper.processStoredNotifications();
        } catch (e) {
          // Log error but don't block navigation
           
        }
        
        if (mounted) {
          // Navigate based on user type (matches KMP BaseScreen.kt logic)
          await NavigationHelper.navigateToInitialScreen(context);
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
     
    if (_hasListener) {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      syncProvider.removeListener(_onSyncStateChanged);
      _hasListener = false;
       
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
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
                   
                }
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
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
                        // SizedBox(
                        //   width: 200,
                        //   height: 200,
                        //   child: Stack(
                        //     alignment: Alignment.center,
                        //     children: [
                        //       // Circular Progress
                        //       CircularProgressIndicator(
                        //         value: syncProvider.progress,
                        //         strokeWidth: 8,
                        //         backgroundColor: Colors.white.withValues(alpha: 0.3),
                        //         valueColor: const AlwaysStoppedAnimation<Color>(
                        //           Colors.white,
                        //         ),
                        //       ),
                        //       // Progress Text
                        //       Text(
                        //         '${(syncProvider.progress * 100).toInt()}%',
                        //         style: const TextStyle(
                        //           color: Colors.white,
                        //           fontSize: 24,
                        //           fontWeight: FontWeight.bold,
                        //         ),
                        //       ),
                        //     ],
                        //   ),
                        // ),
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
                        // if (syncProvider.isSyncing)
                          // ElevatedButton(
                          //   onPressed: () {
                          //     final syncProvider = Provider.of<SyncProvider>(
                          //       context,
                          //       listen: false,
                          //     );
                          //     syncProvider.stopSync();
                          //   },
                          //   style: ElevatedButton.styleFrom(
                          //     backgroundColor: Colors.red,
                          //     foregroundColor: Colors.white,
                          //   ),
                          //   child: const Text('Stop Sync'),
                          // ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

