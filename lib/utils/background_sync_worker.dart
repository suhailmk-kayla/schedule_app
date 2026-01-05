import 'dart:developer' as developer;
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/sync_time/sync_time_repository.dart';
import '../repositories/local/database_helper.dart';
import '../di.dart';
import 'package:intl/intl.dart';

/// Background Sync Worker
/// Checks if last sync is 6 hours old and sets a flag for UI to show snackbar
class BackgroundSyncWorker {
  static const String taskName = 'backgroundSyncTask';
  static const Duration syncThreshold = Duration(minutes: 10);
  static const String syncNeededFlagKey = 'sync_needed_flag';

  /// Initialize WorkManager and register periodic task
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    developer.log('BackgroundSyncWorker: WorkManager initialized');
  }

  /// Register periodic sync check task (runs every 30 minutes)
  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(minutes: 10), // Check every 30 minutes
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      initialDelay: const Duration(minutes: 5), // Start after 5 minutes
    );
    developer.log('BackgroundSyncWorker: Periodic task registered (every 30 minutes)');
  }

  /// Cancel periodic task
  static Future<void> cancelTask() async {
    await Workmanager().cancelByUniqueName(taskName);
    developer.log('BackgroundSyncWorker: Task cancelled');
  }

  /// Callback function that runs in background isolate
  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      developer.log('BackgroundSyncWorker: Task started - $task');
      
      try {
        await _initializeDependenciesInBackground();
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
  static Future<void> _initializeDependenciesInBackground() async {
    try {
      // Only initialize what we need for sync check
      // Database helper can be accessed from background isolate
      if (!getIt.isRegistered<DatabaseHelper>()) {
        final databaseHelper = DatabaseHelper();
        await databaseHelper.initDatabase();
        getIt.registerSingleton<DatabaseHelper>(databaseHelper);
      }

      if (!getIt.isRegistered<SyncTimeRepository>()) {
        getIt.registerLazySingleton<SyncTimeRepository>(
          () => SyncTimeRepository(
            databaseHelper: getIt<DatabaseHelper>(),
          ),
        );
      }
      
      developer.log('BackgroundSyncWorker: Dependencies initialized');
    } catch (e) {
      developer.log('BackgroundSyncWorker: Error initializing dependencies: $e');
      rethrow;
    }
  }

  /// Check if sync is needed and set flag in SharedPreferences
  static Future<void> _checkAndSetFlagIfNeeded() async {
    try {
      final syncTimeRepository = getIt<SyncTimeRepository>();
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
        await prefs.setBool(syncNeededFlagKey, true);
        developer.log('BackgroundSyncWorker: Sync needed flag set');
      } else {
        // Clear flag if sync is recent
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(syncNeededFlagKey, false);
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
  static DateTime? _parseSyncDate(String dateString) {
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
