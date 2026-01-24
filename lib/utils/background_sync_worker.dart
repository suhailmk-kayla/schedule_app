import 'dart:developer' as developer;
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/sync_time/sync_time_repository.dart';
import '../repositories/local/database_helper.dart';
import 'package:intl/intl.dart';

/// Task name constant
const String backgroundSyncTaskKey = 'com.schedule.backgroundSyncTask';

/// Top-level callback dispatcher for WorkManager
/// MUST be a top-level function (outside any class) for @pragma to work
/// This function runs in a separate isolate, so it needs to initialize dependencies
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    developer.log('BackgroundSyncWorker: callbackDispatcher called');
    developer.log('BackgroundSyncWorker: Task received: $task');
    developer.log('BackgroundSyncWorker: Expected task: $backgroundSyncTaskKey');
    developer.log('BackgroundSyncWorker: Input data: $inputData');
    
    // Only handle our specific background sync task
    if (task != backgroundSyncTaskKey) {
      developer.log('BackgroundSyncWorker: Unknown task: $task, ignoring (returning true for other tasks)');
      // Return true for other tasks (like OneSignal) so they can complete
      return Future.value(true);
    }
    
    developer.log('BackgroundSyncWorker: Our task matched! Processing...');
    
    try {
      // Reload SharedPreferences to get latest values (matching example pattern)
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      
      // Initialize dependencies in background isolate
      await _initializeDependenciesInBackground();
      
      // Check if sync is needed and set flag
      await _checkAndSetFlagIfNeeded();
      
      developer.log('BackgroundSyncWorker: Task completed successfully');
      return Future.value(true);
    } catch (e, stackTrace) {
      developer.log(
        'BackgroundSyncWorker: Task failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return Future.value(false);
    }
  });
}

/// Initialize dependencies in background isolate
/// Note: We need to reinitialize because background isolate doesn't share memory with main isolate
/// We create instances directly instead of using getIt, as getIt might not work in background isolate
DatabaseHelper? _backgroundDatabaseHelper;
SyncTimeRepository? _backgroundSyncTimeRepository;

Future<void> _initializeDependenciesInBackground() async {
  try {
    // Create database helper instance if not already created
    if (_backgroundDatabaseHelper == null) {
      _backgroundDatabaseHelper = DatabaseHelper();
      await _backgroundDatabaseHelper!.initDatabase();
      developer.log('BackgroundSyncWorker: DatabaseHelper initialized');
    }

    // Create sync time repository instance if not already created
    if (_backgroundSyncTimeRepository == null) {
      _backgroundSyncTimeRepository = SyncTimeRepository(
        databaseHelper: _backgroundDatabaseHelper!,
      );
      developer.log('BackgroundSyncWorker: SyncTimeRepository initialized');
    }
    
    developer.log('BackgroundSyncWorker: All dependencies initialized');
  } catch (e, stackTrace) {
    developer.log(
      'BackgroundSyncWorker: Error initializing dependencies: $e',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

/// Check if sync is needed and set flag in SharedPreferences
Future<void> _checkAndSetFlagIfNeeded() async {
  try {
    // Ensure dependencies are initialized
    if (_backgroundSyncTimeRepository == null) {
      await _initializeDependenciesInBackground();
    }
    
    final syncTimeRepository = _backgroundSyncTimeRepository!;
    final syncTimeResult = await syncTimeRepository.getSyncTime('Product');
    
    bool shouldSync = false;
    
    await syncTimeResult.fold(
      (failure) async {
        // If error getting sync time, assume sync is needed
        developer.log(
          'BackgroundSyncWorker: Error getting sync time: ${failure.message}',
        );
        shouldSync = true;
      },
      (syncTime) async {
        if (syncTime == null) {
          // No sync time exists - first sync needed
          developer.log('BackgroundSyncWorker: No sync time found - sync needed');
          shouldSync = true;
        } else {
          // Check if sync is older than threshold
          final lastSyncDate = _parseSyncDate(syncTime.updateDate);
          if (lastSyncDate != null) {
            final now = DateTime.now();
            final timeSinceSync = now.difference(lastSyncDate);
            
            developer.log(
              'BackgroundSyncWorker: Last sync: ${syncTime.updateDate}, '
              'Hours since sync: ${timeSinceSync.inHours}',
            );
            
            const syncThreshold = Duration(hours: 1);
            if (timeSinceSync >= syncThreshold) {
              developer.log(
                'BackgroundSyncWorker: Sync is ${timeSinceSync.inHours} hours old - setting flag',
              );
              shouldSync = true;
            } else {
              developer.log(
                'BackgroundSyncWorker: Sync is recent (${timeSinceSync.inHours} hours) - no flag needed',
              );
            }
          } else {
            // Could not parse date - assume sync needed
            developer.log('BackgroundSyncWorker: Could not parse sync date - setting flag');
            shouldSync = true;
          }
        }
      },
    );

    if (shouldSync) {
      // Set flag in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(BackgroundSyncWorker.syncNeededFlagKey, true);
      developer.log('BackgroundSyncWorker: Sync needed flag set');
    } else {
      // Clear flag if sync is recent
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(BackgroundSyncWorker.syncNeededFlagKey, false);
      developer.log('BackgroundSyncWorker: Sync needed flag cleared');
    }
  } catch (e, stackTrace) {
    developer.log(
      'BackgroundSyncWorker: Error in checkAndSetFlagIfNeeded: $e',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

/// Parse sync date string to DateTime
/// Handles common date formats from API
DateTime? _parseSyncDate(String dateString) {
  if (dateString.isEmpty) return null;
  
  try {
    // Try common date formats
    final formats = [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-ddTHH:mm:ss',
      'yyyy-MM-dd HH:mm:ss.SSS',
      'yyyy-MM-dd',
    ];
    
    for (final format in formats) {
      try {
        return DateFormat(format).parse(dateString);
      } catch (_) {
        continue;
      }
    }
    
    // Try parsing as ISO 8601
    return DateTime.parse(dateString);
  } catch (e) {
    developer.log('BackgroundSyncWorker: Error parsing date: $dateString - $e');
    return null;
  }
}

/// Background Sync Worker
/// Checks if last sync is 6 hours old and sets a flag for UI to show snackbar
class BackgroundSyncWorker {
  static const String taskName = backgroundSyncTaskKey;
  static const Duration syncThreshold = Duration(minutes: 10);
  static const String syncNeededFlagKey = 'sync_needed_flag';

  /// Register periodic sync check task (runs every 15 minutes)
  static Future<void> registerPeriodicTask() async {
    try {
      // IMPORTANT: Cancel any existing task first to avoid duplicates
      try {
        await Workmanager().cancelByUniqueName(taskName);
        developer.log('BackgroundSyncWorker: Cancelled existing task before registration');
      } catch (e) {
        // Ignore if task doesn't exist
        developer.log('BackgroundSyncWorker: No existing task to cancel: $e');
      }
      
      await Workmanager().registerPeriodicTask(
        taskName,
        taskName,
        frequency: const Duration(hours: 6),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        initialDelay: const Duration(seconds: 10), // 1 minute for testing, can increase later
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
      
      developer.log('BackgroundSyncWorker: Periodic task registered successfully');
      developer.log('BackgroundSyncWorker: Task name: $taskName');
      developer.log('BackgroundSyncWorker: Will run every 6 hours, starting in 10 seconds');
      
      // Verify task is scheduled (Android only)
      try {
        await Future.delayed(const Duration(seconds: 2)); // Wait a bit for registration
        final isScheduled = await Workmanager().isScheduledByUniqueName(taskName);
        developer.log('BackgroundSyncWorker: Task scheduled status: $isScheduled');
        
        if (!isScheduled) {
          developer.log('BackgroundSyncWorker: WARNING - Task registration returned false!');
        }
      } catch (e) {
        developer.log('BackgroundSyncWorker: Could not verify task schedule status: $e');
      }
    } catch (e, stackTrace) {
      developer.log(
        'BackgroundSyncWorker: Error registering periodic task: $e',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Cancel periodic task
  static Future<void> cancelTask() async {
    await Workmanager().cancelByUniqueName(taskName);
    developer.log('BackgroundSyncWorker: Task cancelled');
  }

  /// Register a one-off test task (for immediate testing)
  /// This bypasses Android's 15-minute minimum interval for periodic tasks
  static Future<void> registerTestTask() async {
    try {
      const testTaskName = '${backgroundSyncTaskKey}_test';
      await Workmanager().registerOneOffTask(
        testTaskName,
        backgroundSyncTaskKey, // Use same task key so callback dispatcher recognizes it
        initialDelay: const Duration(seconds: 5),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
      developer.log('BackgroundSyncWorker: Test task registered (will run in 5 seconds)');
    } catch (e) {
      developer.log('BackgroundSyncWorker: Error registering test task: $e');
    }
  }

  /// Check if sync needed flag is set (can be called from UI)
  static Future<bool> isSyncNeededFlagSet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(syncNeededFlagKey) ?? false;
    } catch (e) {
      developer.log('BackgroundSyncWorker: Error checking flag: $e');
      return false;
    }
  }

  /// Clear sync needed flag (called after user triggers sync or dismisses snackbar)
  static Future<void> clearSyncNeededFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(syncNeededFlagKey, false);
      developer.log('BackgroundSyncWorker: Sync needed flag cleared');
    } catch (e) {
      developer.log('BackgroundSyncWorker: Error clearing flag: $e');
    }
  }
}
