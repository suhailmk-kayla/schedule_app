import 'dart:async';

import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import '../../utils/notification_manager.dart';
import '../../repositories/products/products_repository.dart';
import '../../repositories/categories/categories_repository.dart';
import '../../repositories/sub_categories/sub_categories_repository.dart';
import '../../repositories/units/units_repository.dart';
import '../../repositories/orders/orders_repository.dart';
import '../../repositories/customers/customers_repository.dart';
import '../../repositories/routes/routes_repository.dart';
import '../../repositories/users/users_repository.dart';
import '../../repositories/cars/car_brand_repository.dart';
import '../../repositories/cars/car_name_repository.dart';
import '../../repositories/cars/car_model_repository.dart';
import '../../repositories/cars/car_version_repository.dart';
import '../../repositories/user_category/user_category_repository.dart';
import '../../repositories/salesman/salesman_repository.dart';
import '../../repositories/suppliers/suppliers_repository.dart';
import '../../repositories/order_sub_suggestions/order_sub_suggestions_repository.dart';
import '../../repositories/out_of_stock/out_of_stock_repository.dart';
import '../../repositories/sync_time/sync_time_repository.dart';
import '../../repositories/failed_sync/failed_sync_repository.dart';
import '../../repositories/packed_subs/packed_subs_repository.dart';
import '../../models/sync_models.dart';
import '../../models/salesman_model.dart';
import '../../models/supplier_model.dart';
import '../../models/user_category_model.dart';
import '../../models/master_data_api.dart';
import '../../utils/storage_helper.dart';
import '../../utils/notification_id.dart';
import '../../di.dart';
import 'auth_provider.dart';

/// Sync Provider
/// Handles batch downloading and syncing all master data
/// Converted from KMP's SyncViewModel.kt
///
/// TODO: Handle app termination during sync
/// - Add app lifecycle observer to gracefully stop sync on termination (AppLifecycleState.paused/detached)
/// - Persist sync state (current table, progress) to database/secure storage to survive app restart
/// - Add _isStopped checks during sync operations (between batches, during API calls), not just at start
/// - Implement recovery mechanism on app restart to detect incomplete sync and resume/restart appropriately
/// - Ensure atomic database transactions with proper rollback handling
///
/// Current issues:
/// - Sync state flags are in-memory only (lost on termination)
/// - No way to detect incomplete sync on app restart
/// - Sync times may not be saved if app terminates mid-sync
/// - Partial data sync possible (some batches saved, sync time not updated)
class SyncProvider extends ChangeNotifier {
  // Repositories
  final ProductsRepository _productsRepository;
  final CategoriesRepository _categoriesRepository;
  final SubCategoriesRepository _subCategoriesRepository;
  final UnitsRepository _unitsRepository;
  final OrdersRepository _ordersRepository;
  final CustomersRepository _customersRepository;
  final RoutesRepository _routesRepository;
  final UsersRepository _usersRepository;
  final CarBrandRepository _carBrandRepository;
  final CarNameRepository _carNameRepository;
  final CarModelRepository _carModelRepository;
  final CarVersionRepository _carVersionRepository;
  final UserCategoryRepository _userCategoryRepository;
  final SalesManRepository _salesManRepository;
  final SuppliersRepository _suppliersRepository;
  final OrderSubSuggestionsRepository _orderSubSuggestionsRepository;
  final OutOfStockRepository _outOfStockRepository;
  final SyncTimeRepository _syncTimeRepository;
  final FailedSyncRepository _failedSyncRepository;
  final PackedSubsRepository _packedSubsRepository;

  // Batch size
  static const int _limit = 500;

  // Sync state
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String _currentTask = 'Initializing...';
  String get currentTask => _currentTask;

  double _progress = 0.0;
  double get progress => _progress;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _showError = false;
  bool get showError => _showError;

  bool _isStopped = false;

  // Table sync flags
  bool _isProductDownloaded = false;
  bool _isCarBrandDownloaded = false;
  bool _isCarNameDownloaded = false;
  bool _isCarModelDownloaded = false;
  bool _isCarVersionDownloaded = false;
  bool _isCategoryDownloaded = false;
  bool _isSubCategoryDownloaded = false;
  bool _isOrderDownloaded = false;
  bool _isOrderSubDownloaded = false;
  bool _isOrderSubSuggestionDownloaded = false;
  bool _isOutOfStockDownloaded = false;
  bool _isOutOfStockSubDownloaded = false;
  bool _isCustomerDownloaded = false;
  bool _isUserDownloaded = false;
  bool _isSalesmanDownloaded = false;
  bool _isSupplierDownloaded = false;
  bool _isRoutesDownloaded = false;
  bool _isUnitsDownloaded = false;
  bool _isProductUnitsDownloaded = false;
  bool _isProductCarDownloaded = false;
  bool _isUserCategoryDownloaded = false;

  // Batch counters
  int _productPart = 0;
  int _carBrandPart = 0;
  int _carNamePart = 0;
  int _carModelPart = 0;
  int _carVersionPart = 0;
  int _categoryPart = 0;
  int _subCategoryPart = 0;
  int _orderPart = 0;
  int _orderSubPart = 0;
  int _orderSubSuggestionPart = 0;
  int _outOfStockPart = 0;
  int _outOfStockSubPart = 0;
  int _customerPart = 0;
  int _userPart = 0;
  int _salesmanPart = 0;
  int _supplierPart = 0;
  int _routesPart = 0;
  int _unitsPart = 0;
  int _productUnitsPart = 0;
  int _productCarPart = 0;
  int _userCategoryPart = 0;

  // Cached user data (matching KMP pattern - lines 76-77)
  // These are initialized once at sync start, avoiding 39+ async storage reads
  int? _cachedUserType;
  int? _cachedUserId;

  // Cached sync times (Solution 3: Pre-fetch all sync times at start)
  // This eliminates hundreds of redundant DB queries during sync
  // Maps table name to sync time (update_date string)
  final Map<String, String> _syncTimeCache = {};

  // Performance optimizations
  // Priority 2: Throttle progress updates (reduces UI rebuild overhead)
  DateTime? _lastProgressUpdate;
  static const _progressUpdateInterval = Duration(milliseconds: 500);

  // Priority 4: Simplified progress calculation (cached completed table count)
  int _completedTablesCount = 0;

  SyncProvider({
    required ProductsRepository productsRepository,
    required CategoriesRepository categoriesRepository,
    required SubCategoriesRepository subCategoriesRepository,
    required UnitsRepository unitsRepository,
    required OrdersRepository ordersRepository,
    required CustomersRepository customersRepository,
    required RoutesRepository routesRepository,
    required UsersRepository usersRepository,
    required CarBrandRepository carBrandRepository,
    required CarNameRepository carNameRepository,
    required CarModelRepository carModelRepository,
    required CarVersionRepository carVersionRepository,
    required UserCategoryRepository userCategoryRepository,
    required SalesManRepository salesManRepository,
    required SuppliersRepository suppliersRepository,
    required OrderSubSuggestionsRepository orderSubSuggestionsRepository,
    required OutOfStockRepository outOfStockRepository,
    required SyncTimeRepository syncTimeRepository,
    required FailedSyncRepository failedSyncRepository,
    required PackedSubsRepository packedSubsRepository,
  }) : _productsRepository = productsRepository,
       _categoriesRepository = categoriesRepository,
       _subCategoriesRepository = subCategoriesRepository,
       _unitsRepository = unitsRepository,
       _ordersRepository = ordersRepository,
       _customersRepository = customersRepository,
       _routesRepository = routesRepository,
       _usersRepository = usersRepository,
       _carBrandRepository = carBrandRepository,
       _carNameRepository = carNameRepository,
       _carModelRepository = carModelRepository,
       _carVersionRepository = carVersionRepository,
       _userCategoryRepository = userCategoryRepository,
       _salesManRepository = salesManRepository,
       _suppliersRepository = suppliersRepository,
       _orderSubSuggestionsRepository = orderSubSuggestionsRepository,
       _outOfStockRepository = outOfStockRepository,
       _syncTimeRepository = syncTimeRepository,
       _failedSyncRepository = failedSyncRepository,
       _packedSubsRepository = packedSubsRepository;

  // ============================================================================
  // Public Methods
  // ============================================================================

  /// Start syncing all data
  Future<void> startSync() async {
    if (_isSyncing) {
      developer.log(
        'SyncProvider: startSync() called but already syncing, ignoring',
      );
      return;
    }

    developer.log('SyncProvider: Starting sync...');
    _isSyncing = true;
    _isStopped = false;
    _resetSyncFlags();
    _resetBatchCounters();
    _clearError();
    _progress = 0.0;
    _currentTask = 'Initializing...';

    // Initialize cached user data (matching KMP pattern - avoids 39+ async reads)
    await _initializeUserData();

    // Solution 3: Pre-fetch all sync times at start (eliminates hundreds of redundant DB queries)
    _currentTask = 'Pre-fetching sync times...';
    notifyListeners();
    await _prefetchAllSyncTimes();

    // Priority 4: Reset completed tables count
    _completedTablesCount = 0;
    _lastProgressUpdate = null;

    notifyListeners();
    developer.log('SyncProvider: State updated, notifyListeners() called');

    try {
      await _startSyncDatabase();
    } catch (e, stackTrace) {
      developer.log(
        'SyncProvider: Exception in startSync: $e',
        error: e,
        stackTrace: stackTrace,
      );
      _updateError('Sync failed: ${e.toString()}', true);
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Stop syncing
  void stopSync() {
    developer.log('SyncProvider: stopSync() called');
    _isStopped = true;
    _isSyncing = false;
    _currentTask = 'Sync stopped';
    notifyListeners();
    developer.log('SyncProvider: Sync stopped, notifyListeners() called');
  }

  /// Sync failed syncs
  Future<void> syncFailedSyncs() async {
    final failedResult = await _failedSyncRepository.getAllFailedSyncs();
    failedResult.fold((failure) => _updateError(failure.message, true), (
      failedSyncs,
    ) async {
      for (final failedSync in failedSyncs) {
        await _syncFailedItem(failedSync);
      }
    });
  }

  /// Get all failed syncs
  Future<List<FailedSync>> getAllFailedSyncs() async {
    final result = await _failedSyncRepository.getAllFailedSyncs();
    return result.fold((failure) => [], (failedSyncs) => failedSyncs);
  }

  // ============================================================================
  // Private Sync Methods
  // ============================================================================

  // Track current syncing table for sync time retrieval
  String _syncingTable = '';

  Future<void> _startSyncDatabase() async {
    developer.log(
      'SyncProvider: _startSyncDatabase() - syncing table: $_syncingTable--the recursive funxtion is running....',
    );
    if (_isStopped) {
      developer.log('SyncProvider: _startSyncDatabase() - sync was stopped');
      _isSyncing = false;
      notifyListeners();
      return;
    }

    try {
      // Use cached values (matching KMP pattern - no async storage reads)
      final userType = _cachedUserType ?? 0;
      developer.log('SyncProvider: _startSyncDatabase() - UserType: $userType');

      if (!_isProductDownloaded) {
        _syncingTable = 'Product';
        developer.log(
          'products not downloaded-calling the recursive function to download the products',
          name: 'SyncProvider',
        );
        await _downloadProducts();
      } else if (!_isCarBrandDownloaded) {
        _syncingTable = 'CarBrand';
        developer.log(
          'car brands not downloaded-calling the recursive function to download the car brands',
          name: 'SyncProvider',
        );
        await _downloadCarBrand();
      } else if (!_isCarNameDownloaded) {
        developer.log(
          'car names not downloaded-calling the recursive function to download the car names',
          name: 'SyncProvider',
        );
        await _downloadCarName();
      } else if (!_isCarModelDownloaded) {
        developer.log(
          'car models not downloaded-calling the recursive function to download the car models',
          name: 'SyncProvider',
        );
        await _downloadCarModel();
      } else if (!_isCarVersionDownloaded) {
        developer.log(
          'car versions not downloaded-calling the recursive function to download the car versions',
          name: 'SyncProvider',
        );
        await _downloadCarVersion();
      } else if (!_isCategoryDownloaded) {
        developer.log(
          'categories not downloaded-calling the recursive function to download the categories',
          name: 'SyncProvider',
        );
        await _downloadCategory();
      } else if (!_isSubCategoryDownloaded) {
        developer.log(
          'sub-categories not downloaded-calling the recursive function to download the sub-categories',
          name: 'SyncProvider',
        );
        await _downloadSubCategory();
      } else if (!_isOrderDownloaded && userType != 4) {
        developer.log(
          'orders not downloaded-calling the recursive function to download the orders',
          name: 'SyncProvider',
        );
        await _downloadOrders();
      } else if (!_isOrderSubDownloaded && userType != 4) {
        await _downloadOrderSubs();
      } else if (!_isOrderSubSuggestionDownloaded && userType != 4) {
        developer.log(
          'order sub suggestions not downloaded-calling the recursive function to download the order sub suggestions',
          name: 'SyncProvider',
        );
        await _downloadOrderSubSuggestions();
      } else if (!_isOutOfStockDownloaded && (userType == 1 || userType == 4)) {
        developer.log(
          'out of stock not downloaded-calling the recursive function to download the out of stock',
          name: 'SyncProvider',
        );
        await _downloadOutOfStock();
      } else if (!_isOutOfStockSubDownloaded &&
          (userType == 1 || userType == 2 || userType == 4)) {
        developer.log(
          'out of stock sub not downloaded-calling the recursive function to download the out of stock sub',
          name: 'SyncProvider',
        );
        await _downloadOutOfStockSub();
      } else if (!_isCustomerDownloaded && userType != 4) {
        developer.log(
          'customers not downloaded-calling the recursive function to download the customers',
          name: 'SyncProvider',
        );
        await _downloadCustomers();
      } else if (!_isUserDownloaded) {
        developer.log(
          'users not downloaded-calling the recursive function to download the users',
          name: 'SyncProvider',
        );
        await _downloadUsers();
      } else if (!_isSalesmanDownloaded && userType != 4) {
        _syncingTable = 'Salesman';
        developer.log(
          'salesmen not downloaded-calling the recursive function to download the salesmen',
          name: 'SyncProvider',
        );
        await _downloadSalesmen();
      } else if (!_isSupplierDownloaded && userType != 4) {
        developer.log(
          'suppliers not downloaded-calling the recursive function to download the suppliers',
          name: 'SyncProvider',
        );
        await _downloadSuppliers();
      } else if (!_isRoutesDownloaded) {
        developer.log(
          'routes not downloaded-calling the recursive function to download the routes',
          name: 'SyncProvider',
        );
        await _downloadRoutes();
      } else if (!_isUnitsDownloaded) {
        developer.log(
          'units not downloaded-calling the recursive function to download the units',
          name: 'SyncProvider',
        );
        await _downloadUnits();
      } else if (!_isProductUnitsDownloaded) {
        developer.log(
          'product units not downloaded-calling the recursive function to download the product units',
          name: 'SyncProvider',
        );
        await _downloadProductUnits();
      } else if (!_isProductCarDownloaded) {
        developer.log(
          'product cars not downloaded-calling the recursive function to download the product cars',
          name: 'SyncProvider',
        );
        await _downloadProductCar();
      } else if (!_isUserCategoryDownloaded) {
        await _downloadUserCategories();
      } else {
        // All syncs completed
        developer.log('SyncProvider: All syncs completed!');
        _isSyncing = false;
        _progress = 1.0;
        _currentTask = 'Sync completed';
        notifyListeners();
        developer.log('SyncProvider: Sync completed, notifyListeners() called');
      }
    } catch (e, stackTrace) {
      developer.log(
        'SyncProvider: Exception in _startSyncDatabase: $e',
        error: e,
        stackTrace: stackTrace,
      );
      _updateError('Database sync error: ${e.toString()}', true);
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Download products (full sync or single record retry)
  /// Converted from KMP's downloadProducts function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all products in batches
  /// 2. Single record retry (id != -1): Downloads specific product and handles FailedSync
  Future<void> _downloadProducts({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      developer.log('SyncProvider: _downloadProducts() - Part: $_productPart');
      _updateTask('Product details downloading...');
    }

    try {
      // Get sync time from cache (pre-fetched at start - Solution 3)
      final updateDate = _getSyncTimeForTable(_syncingTable);
      // Use cached values (matching KMP pattern - no async storage reads)
      final userType = _cachedUserType ?? 0;
      final userId = _cachedUserId ?? 0;

      developer.log(
        'SyncProvider: _downloadProducts() - part_no=$_productPart, user_type=$userType, user_id=$userId, update_date=$updateDate, id=$id',
      );

      final result = await _productsRepository.syncProductsFromApi(
        partNo: _productPart,
        limit: _limit,
        userType: userType,
        userId: userId,
        updateDate: updateDate,
        id: id, // Pass id parameter
      );

      await result.fold(
        (failure) async {
          // Error handling matching KMP
          if (id != -1 && failedId == -1) {
            // Retry mode failed: create FailedSync entry (matches KMP line 200-203)
            await _failedSyncRepository.addFailedSync(
              tableId: 1, // NotificationId.PRODUCT = 1
              dataId: id,
            );
            if (finished != null) finished();
          } else {
            // Full sync mode error: update error message (matches KMP line 209)
            developer.log(
              'SyncProvider: _downloadProducts() - Error: ${failure.message}',
            );
            _updateError(failure.message, true);
            _isSyncing = false;
            notifyListeners();
          }
        },
        (productListApi) async {
          final products = productListApi.data ?? [];
          developer.log(
            'SyncProvider: _downloadProducts() - Received ${products.length} products',
          );

          if (id == -1) {
            // Full sync mode (matches KMP lines 216-225)
            if (products.isEmpty) {
              developer.log(
                'SyncProvider: _downloadProducts() - No more products, marking as downloaded',
              );
              _isProductDownloaded = true;
              _completedTablesCount++; // Priority 4: Track completed tables
              // Fire-and-forget sync time write (matching KMP pattern)
              _syncTimeRepository
                  .addSyncTime(
                    tableName: 'Product',
                    updateDate: productListApi.updated_date,
                  )
                  .then((result) {
                    result.fold(
                      (failure) => developer.log(
                        'SyncProvider: Failed to add sync time: ${failure.message}',
                      ),
                      (_) => developer.log(
                        'SyncProvider: Sync time added for Product',
                      ),
                    );
                  });
              _productPart = 0;
              _updateProgress();
              // Proceed immediately to next table (fire-and-forget pattern)
              _startSyncDatabase();
            } else {
              developer.log(
                'SyncProvider: _downloadProducts() - Adding ${products.length} products to DB',
              );
              // CRITICAL FIX: Await database operation to prevent locks
              final addResult = await _productsRepository.addProducts(products);
              addResult.fold(
                (failure) {
                  developer.log(
                    'SyncProvider: Failed to add products to DB: ${failure.message}',
                  );
                  _updateError(
                    'Failed to save products: ${failure.message}',
                    true,
                  );
                  _isSyncing = false;
                  notifyListeners();
                },
                (_) {
                  developer.log(
                    'SyncProvider: Products added to DB successfully',
                  );
                },
              );
              _productPart++;
              _updateProgress();
              // Now safe to proceed after transaction completes
              _startSyncDatabase();
            }
          } else {
            // Single record retry mode (matches KMP lines 226-230)
            if (products.isNotEmpty) {
              // CRITICAL FIX: Await database operation to prevent locks
              final addResult = await _productsRepository.addProducts(products);
              addResult.fold(
                (failure) => developer.log(
                  'SyncProvider: Failed to add products: ${failure.message}',
                ),
                (_) {},
              );
            }
            if (failedId != -1) {
              await _failedSyncRepository.deleteFailedSync(failedId);
            }
            if (finished != null) finished();
          }
        },
      );
    } catch (e, stackTrace) {
      developer.log(
        'SyncProvider: Exception in _downloadProducts: $e',
        error: e,
        stackTrace: stackTrace,
      );
      _updateError('Product download error: ${e.toString()}', true);
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Download car brands (full sync or single record retry)
  /// Converted from KMP's downloadCarBrand function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all car brands in batches
  /// 2. Single record retry (id != -1): Downloads specific car brand and handles FailedSync
  Future<void> _downloadCarBrand({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      developer.log('SyncProvider: _downloadCarBrand() - Part: $_carBrandPart');
      _updateTask('Car details downloading...');
    }

    try {
      final updateDate = _getSyncTimeForTable(_syncingTable);
      // Use cached values (matching KMP pattern - no async storage reads)
      final userType = _cachedUserType ?? 0;
      final userId = _cachedUserId ?? 0;

      final result = await _carBrandRepository.syncCarBrandsFromApi(
        partNo: _carBrandPart,
        limit: _limit,
        userType: userType,
        userId: userId,
        updateDate: updateDate,
        id: id, // Pass id parameter
      );

      result.fold(
        (failure) {
          // Error handling matching KMP
          if (id != -1 && failedId == -1) {
            // Retry mode failed: create FailedSync entry (matches KMP line 243-245)
            _failedSyncRepository
                .addFailedSync(
                  tableId: 2, // NotificationId.CAR_BRAND = 2
                  dataId: id,
                )
                .then((_) {
                  if (finished != null) finished();
                });
          } else {
            // Full sync mode error: update error message (matches KMP line 248)
            developer.log(
              'SyncProvider: _downloadCarBrand() - Error: ${failure.message}',
            );
            _updateError(failure.message, true);
            _isSyncing = false;
            notifyListeners();
          }
        },
        (carBrandListApi) async {
          final brands = carBrandListApi.data ?? [];
          developer.log(
            'SyncProvider: _downloadCarBrand() - Received ${brands.length} brands',
          );

          if (id == -1) {
            // Full sync mode (matches KMP lines 255-264)
            if (brands.isEmpty) {
              developer.log(
                'SyncProvider: _downloadCarBrand() - No more brands, marking as downloaded',
              );
              _isCarBrandDownloaded = true;
              _completedTablesCount++; // Priority 4: Track completed tables
              // Fire-and-forget sync time write (matching KMP pattern)
              _syncTimeRepository
                  .addSyncTime(
                    tableName: 'CarBrand',
                    updateDate: carBrandListApi.updatedDate,
                  )
                  .then((result) {
                    result.fold(
                      (failure) => developer.log(
                        'SyncProvider: Failed to add sync time: ${failure.message}',
                      ),
                      (_) => developer.log(
                        'SyncProvider: Sync time added for CarBrand',
                      ),
                    );
                  });
              _carBrandPart = 0;
              _updateProgress();
              // Proceed immediately to next table (fire-and-forget pattern)
              _startSyncDatabase();
            } else {
              // CRITICAL FIX: Await database operation to prevent locks
              final addResult = await _carBrandRepository.addCarBrands(brands);
              addResult.fold(
                (failure) {
                  developer.log(
                    'SyncProvider: Failed to add brands to DB: ${failure.message}',
                  );
                  _updateError(
                    'Failed to save brands: ${failure.message}',
                    true,
                  );
                  _isSyncing = false;
                  notifyListeners();
                },
                (_) {
                  developer.log(
                    'SyncProvider: Brands added to DB successfully',
                  );
                },
              );
              _carBrandPart++;
              _updateProgress();
              // Now safe to proceed after transaction completes
              _startSyncDatabase();
            }
          } else {
            // Single record retry mode (matches KMP lines 265-268)
            if (brands.isNotEmpty) {
              // CRITICAL FIX: Await database operation to prevent locks
              final addResult = await _carBrandRepository.addCarBrands(brands);
              addResult.fold(
                (failure) => developer.log(
                  'SyncProvider: Failed to add brands: ${failure.message}',
                ),
                (_) {},
              );
            }
            if (failedId != -1) {
              await _failedSyncRepository.deleteFailedSync(failedId);
            }
            if (finished != null) finished();
          }
        },
      );
    } catch (e, stackTrace) {
      developer.log(
        'SyncProvider: Exception in _downloadCarBrand: $e',
        error: e,
        stackTrace: stackTrace,
      );
      _updateError('Car brand download error: ${e.toString()}', true);
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Download car names (full sync or single record retry)
  /// Converted from KMP's downloadCarName function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all car names in batches
  /// 2. Single record retry (id != -1): Downloads specific car name and handles FailedSync
  Future<void> _downloadCarName({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Car details downloading...');
    }
    final updateDate = _getSyncTimeForTable('CarName');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _carNameRepository.syncCarNamesFromApi(
      partNo: _carNamePart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry (matches KMP line 281-283)
          _failedSyncRepository
              .addFailedSync(
                tableId: 3, // NotificationId.CAR_NAME = 3
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message (matches KMP line 286)
          _updateError(failure.message, true);
        }
      },
      (carNameListApi) async {
        final names = carNameListApi.data ?? [];
        if (id == -1) {
          // Full sync mode (matches KMP lines 293-301)
          if (names.isEmpty) {
            _isCarNameDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'CarName',
                  updateDate: carNameListApi.updatedDate,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _carNamePart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _carNameRepository.addCarNames(names);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add car names: ${failure.message}',
              ),
              (_) {},
            );
            _carNamePart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matches KMP lines 303-306)
          if (names.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _carNameRepository.addCarNames(names);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add car names: ${failure.message}',
              ),
              (_) {},
            );
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download car models (full sync or single record retry)
  /// Converted from KMP's downloadCarModel function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all car models in batches
  /// 2. Single record retry (id != -1): Downloads specific car model and handles FailedSync
  Future<void> _downloadCarModel({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Car details downloading...');
    }
    final updateDate = _getSyncTimeForTable('CarModel');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _carModelRepository.syncCarModelsFromApi(
      partNo: _carModelPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry (matches KMP line 319-321)
          _failedSyncRepository
              .addFailedSync(
                tableId: 4, // NotificationId.CAR_MODEL = 4
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message (matches KMP line 324)
          _updateError(failure.message, true);
        }
      },
      (carModelListApi) async {
        final models = carModelListApi.data ?? [];
        if (id == -1) {
          // Full sync mode (matches KMP lines 331-339)
          if (models.isEmpty) {
            _isCarModelDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'CarModel',
                  updateDate: carModelListApi.updatedDate,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _carModelPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _carModelRepository.addCarModels(models);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add car models: ${failure.message}',
              ),
              (_) {},
            );
            _carModelPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matches KMP lines 341-344)
          if (models.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _carModelRepository.addCarModels(models);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add car models: ${failure.message}',
              ),
              (_) {},
            );
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download car versions (full sync or single record retry)
  /// Converted from KMP's downloadCarVersion function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all car versions in batches
  /// 2. Single record retry (id != -1): Downloads specific car version and handles FailedSync
  Future<void> _downloadCarVersion({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Car details downloading...');
    }
    final updateDate = _getSyncTimeForTable('CarVersion');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _carVersionRepository.syncCarVersionsFromApi(
      partNo: _carVersionPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry (matches KMP line 357-359)
          _failedSyncRepository
              .addFailedSync(
                tableId: 5, // NotificationId.CAR_VERSION = 5
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message (matches KMP line 362)
          _updateError(failure.message, true);
        }
      },
      (carVersionListApi) async {
        final versions = carVersionListApi.data ?? [];
        if (id == -1) {
          // Full sync mode (matches KMP lines 369-377)
          if (versions.isEmpty) {
            _isCarVersionDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'CarVersion',
                  updateDate: carVersionListApi.updatedDate,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _carVersionPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _carVersionRepository.addCarVersions(
              versions,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add car versions: ${failure.message}',
              ),
              (_) {},
            );
            _carVersionPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matches KMP lines 379-382)
          if (versions.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _carVersionRepository.addCarVersions(
              versions,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add car versions: ${failure.message}',
              ),
              (_) {},
            );
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download categories (full sync or single record retry)
  /// Converted from KMP's downloadCategory function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all categories in batches
  /// 2. Single record retry (id != -1): Downloads specific category and handles FailedSync
  Future<void> _downloadCategory({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Category downloading...');
    }

    final updateDate = _getSyncTimeForTable('Category');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _categoriesRepository.syncCategoriesFromApi(
      partNo: _categoryPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry
          _failedSyncRepository
              .addFailedSync(
                tableId: 6, // NotificationId.CATEGORY = 6
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message
          _updateError(failure.message, true);
        }
      },
      (categoryListApi) async {
        final categories = categoryListApi.data ?? [];

        if (id == -1) {
          // Full sync mode
          if (categories.isEmpty) {
            _isCategoryDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'Category',
                  updateDate: categoryListApi.updatedDate,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _categoryPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _categoriesRepository.addCategories(
              categories,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add categories: ${failure.message}',
              ),
              (_) {},
            );
            _categoryPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode
          if (categories.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _categoriesRepository.addCategories(
              categories,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add categories: ${failure.message}',
              ),
              (_) {},
            );
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download sub categories (full sync or single record retry)
  /// Converted from KMP's downloadSubCategory function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all sub categories in batches
  /// 2. Single record retry (id != -1): Downloads specific sub category and handles FailedSync
  Future<void> _downloadSubCategory({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Sub-Category downloading...');
    }
    final updateDate = _getSyncTimeForTable('SubCategory');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _subCategoriesRepository.syncSubCategoriesFromApi(
      partNo: _subCategoryPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry (matches KMP line 434-436)
          _failedSyncRepository
              .addFailedSync(
                tableId: 7, // NotificationId.SUB_CATEGORY = 7
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          developer.log(
            'SyncProvider: _downloadSubCategory error: ${failure.message}',
          );
          // Full sync mode error: update error message (matches KMP line 439)
          _updateError(failure.message, true);
        }
      },
      (subCategoryListApi) async {
        final subCategories = subCategoryListApi.data ?? [];
        if (id == -1) {
          // Full sync mode (matches KMP lines 446-454)
          if (subCategories.isEmpty) {
            _isSubCategoryDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            developer.log(
              'Sub-categories are all downloaded-time to move on to next table',
            );
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'SubCategory',
                  updateDate: subCategoryListApi.updatedDate,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _subCategoryPart = 0;
            developer.log(
              'Sub-categories are all downloaded-calling the recursive function to download the next table',
            );
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _subCategoriesRepository.addSubCategories(
              subCategories,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add sub categories: ${failure.message}',
              ),
              (_) {},
            );
            _subCategoryPart++;
            developer.log('downloading sub-categories part: $_subCategoryPart');
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matches KMP lines 456-459)
          if (subCategories.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _subCategoriesRepository.addSubCategories(
              subCategories,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add sub categories: ${failure.message}',
              ),
              (_) {},
            );
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download orders (full sync or single record retry)
  /// Converted from KMP's downloadOrder function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all orders in batches
  /// 2. Single record retry (id != -1): Downloads specific order, processes nested items/suggestions, and handles FailedSync
  Future<void> _downloadOrders({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    // Skip if supplier (matching KMP pattern)
    final userType = _cachedUserType ?? 0;
    if (userType == 4) {
      // UserType.SUPPLIER = 4 (not 5!)
      // Mark as downloaded and continue sync chain to prevent infinite loop
      if (id == -1) {
        // Full sync mode: mark as downloaded and continue
        _isOrderDownloaded = true;
        _completedTablesCount++;
        _orderPart = 0;
        if (finished != null) finished();
        _startSyncDatabase(); // Continue to next table
      } else {
        // Retry mode: just finish
        if (finished != null) finished();
      }
      return;
    }

    if (id == -1) {
      // Full sync mode
      _updateTask('Order details downloading...');
    }

    final updateDate = _getSyncTimeForTable('Orders');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userId = _cachedUserId ?? 0;
    final result = await _ordersRepository.syncOrdersFromApi(
      partNo: _orderPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry
          _failedSyncRepository
              .addFailedSync(
                tableId: 8, // NotificationId.ORDER = 8
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message
          _updateError(failure.message, true);
        }
      },
      (orderListApi) async {
        final orders = orderListApi.data ?? [];

        if (id == -1) {
          // Full sync mode
          if (orders.isEmpty) {
            _isOrderDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'Orders',
                  updateDate: orderListApi.updatedDate,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _orderPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            // Pass userType and userId for filtering (matching KMP's addOrder(list, userId, userType))
            final addResult = await _ordersRepository.addOrders(
              orders,
              userType: userType,
              userId: userId,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add orders: ${failure.message}',
              ),
              (_) {},
            );
            _orderPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matching KMP lines 498-519)
          if (orders.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            // Pass userType and userId for filtering (matching KMP's addOrder(list, userId, userType, isNotification=true))
            final addResult = await _ordersRepository.addOrders(
              orders,
              userType: userType,
              userId: userId,
              isNotification: true,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add orders: ${failure.message}',
              ),
              (_) {},
            );

            // Process nested items and suggestions (matching KMP lines 501-515)
            for (final order in orders) {
              if (order.items != null && order.items!.isNotEmpty) {
                // CRITICAL FIX: Await database operation to prevent locks
                final addSubsResult = await _ordersRepository.addOrderSubs(
                  order.items!,
                );
                addSubsResult.fold(
                  (failure) => developer.log(
                    'SyncProvider: Failed to add order subs: ${failure.message}',
                  ),
                  (_) {},
                );

                // Add suggestions for each order sub
                for (final orderSub in order.items!) {
                  if (orderSub.suggestions != null &&
                      orderSub.suggestions!.isNotEmpty) {
                    // CRITICAL FIX: Await database operation to prevent locks
                    final addSuggestionsResult =
                        await _orderSubSuggestionsRepository.addSuggestions(
                          orderSub.suggestions!,
                        );
                    addSuggestionsResult.fold(
                      (failure) => developer.log(
                        'SyncProvider: Failed to add order sub suggestions: ${failure.message}',
                      ),
                      (_) {},
                    );
                  }
                }
              }
            }

            // Trigger UI refresh after order is downloaded and saved
            // Matching KMP's PushNotificationHandler.kt line 69: NotificationManager.triggerRefresh()
            NotificationManager().triggerRefresh();
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download order subs (full sync or single record retry)
  /// Converted from KMP's downloadOrderSub function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all order subs in batches
  /// 2. Single record retry (id != -1): Downloads specific order sub, processes nested suggestions, and handles FailedSync
  Future<void> _downloadOrderSubs({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    // Skip if supplier (matching KMP pattern)
    final userType = _cachedUserType ?? 0;
    if (userType == 4) {
      // UserType.SUPPLIER = 4 (not 5!)
      // Mark as downloaded and continue sync chain to prevent infinite loop
      if (id == -1) {
        // Full sync mode: mark as downloaded and continue
        _isOrderSubDownloaded = true;
        _completedTablesCount++;
        _orderSubPart = 0;
        if (finished != null) finished();
        _startSyncDatabase(); // Continue to next table
      } else {
        // Retry mode: just finish
        if (finished != null) finished();
      }
      return;
    }

    if (id == -1) {
      // Full sync mode
      _updateTask('Order details downloading...');
    }

    final updateDate = _getSyncTimeForTable('OrderSub');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userId = _cachedUserId ?? 0;
    final result = await _ordersRepository.syncOrderSubsFromApi(
      partNo: _orderSubPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry
          _failedSyncRepository
              .addFailedSync(
                tableId: 9, // NotificationId.ORDER_SUB = 9
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message
          _updateError(failure.message, true);
        }
      },
      (orderSubListApi) async {
        final orderSubs = orderSubListApi.data ?? [];

        if (id == -1) {
          // Full sync mode
          if (orderSubs.isEmpty) {
            _isOrderSubDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'OrderSub',
                  updateDate: orderSubListApi.updatedDate,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _orderSubPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _ordersRepository.addOrderSubs(orderSubs);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add order subs: ${failure.message}',
              ),
              (_) {},
            );
            _orderSubPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matching KMP lines 558-575)
          if (orderSubs.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _ordersRepository.addOrderSubs(orderSubs);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add order subs: ${failure.message}',
              ),
              (_) {},
            );

            // Process nested suggestions (matching KMP lines 565-571)
            for (final orderSub in orderSubs) {
              if (orderSub.suggestions != null &&
                  orderSub.suggestions!.isNotEmpty) {
                // CRITICAL FIX: Await database operation to prevent locks
                final addSuggestionsResult =
                    await _orderSubSuggestionsRepository.addSuggestions(
                      orderSub.suggestions!,
                    );
                addSuggestionsResult.fold(
                  (failure) => developer.log(
                    'SyncProvider: Failed to add order sub suggestions: ${failure.message}',
                  ),
                  (_) {},
                );
              }
            }
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download order sub suggestions (full sync or single record retry)
  /// Converted from KMP's downloadOrderSubSuggestion function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all suggestions in batches
  /// 2. Single record retry (id != -1): Downloads specific suggestion and handles FailedSync
  Future<void> _downloadOrderSubSuggestions({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Order details downloading...');
    }

    final updateDate = _getSyncTimeForTable('OrderSubSuggestion');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _orderSubSuggestionsRepository.syncSuggestionsFromApi(
      partNo: _orderSubSuggestionPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry
          _failedSyncRepository
              .addFailedSync(
                tableId: 10, // NotificationId.ORDER_SUB_SUGGESTION = 10
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message
          _updateError(failure.message, true);
        }
      },
      (suggestionsListApi) async {
        final suggestions = suggestionsListApi.data ?? [];

        if (id == -1) {
          // Full sync mode
          if (suggestions.isEmpty) {
            _isOrderSubSuggestionDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'OrderSubSuggestions',
                  updateDate: suggestionsListApi.updatedDate,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _orderSubSuggestionPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _orderSubSuggestionsRepository
                .addSuggestions(suggestions);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add order sub suggestions: ${failure.message}',
              ),
              (_) {},
            );
            _orderSubSuggestionPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matching KMP lines 613-619)
          if (suggestions.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _orderSubSuggestionsRepository
                .addSuggestions(suggestions);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add order sub suggestions: ${failure.message}',
              ),
              (_) {},
            );
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download out of stock masters (full sync or single record retry)
  /// Converted from KMP's downloadOutOfStock function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all out of stock masters in batches
  /// 2. Single record retry (id != -1): Downloads specific out of stock master, processes nested items, and handles FailedSync
  Future<void> _downloadOutOfStock({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Out of Stock details downloading...');
    }

    final updateDate = _getSyncTimeForTable('OutOfStockMaster');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _outOfStockRepository.syncOutOfStockMastersFromApi(
      partNo: _outOfStockPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry
          _failedSyncRepository
              .addFailedSync(
                tableId: 11, // NotificationId.OUT_OF_STOCK = 11
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message
          _updateError(failure.message, true);
        }
      },
      (outOfStockListApi) async {
        final outOfStocks = outOfStockListApi.data ?? [];

        if (id == -1) {
          // Full sync mode
          if (outOfStocks.isEmpty) {
            _isOutOfStockDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'OutOfStockMaster',
                  updateDate: outOfStockListApi.updatedDate,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _outOfStockPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _outOfStockRepository.addOutOfStockMasters(
              outOfStocks,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add out of stock masters: ${failure.message}',
              ),
              (_) {},
            );
            _outOfStockPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matching KMP pattern)
          if (outOfStocks.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _outOfStockRepository.addOutOfStockMasters(
              outOfStocks,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add out of stock masters: ${failure.message}',
              ),
              (_) {},
            );

            // Process nested items if present (matching KMP pattern for nested data)
            for (final outOfStock in outOfStocks) {
              if (outOfStock.items != null && outOfStock.items!.isNotEmpty) {
                // CRITICAL FIX: Await database operation to prevent locks
                final addProductsResult = await _outOfStockRepository
                    .addOutOfStockProducts(outOfStock.items!);
                addProductsResult.fold(
                  (failure) => developer.log(
                    'SyncProvider: Failed to add out of stock products: ${failure.message}',
                  ),
                  (_) {},
                );
              }
            }
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download out of stock products (full sync or single record retry)
  /// Converted from KMP's downloadOutOfStockSub function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all out of stock products in batches
  /// 2. Single record retry (id != -1): Downloads specific out of stock product and handles FailedSync
  Future<void> _downloadOutOfStockSub({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Out of Stock details downloading...');
    }

    final updateDate = _getSyncTimeForTable('OutOfStockProducts');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _outOfStockRepository.syncOutOfStockProductsFromApi(
      partNo: _outOfStockSubPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry
          _failedSyncRepository
              .addFailedSync(
                tableId: 12, // NotificationId.OUT_OF_STOCK_SUB = 12
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message
          _updateError(failure.message, true);
        }
      },
      (outOfStockSubListApi) async {
        final outOfStockSubs = outOfStockSubListApi.data ?? [];

        if (id == -1) {
          // Full sync mode
          if (outOfStockSubs.isEmpty) {
            _isOutOfStockSubDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'OutOfStockProducts',
                  updateDate: outOfStockSubListApi.updatedDate,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _outOfStockSubPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _outOfStockRepository.addOutOfStockProducts(
              outOfStockSubs,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add out of stock products: ${failure.message}',
              ),
              (_) {},
            );
            _outOfStockSubPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matching KMP pattern)
          if (outOfStockSubs.isNotEmpty) {
            // CRITICAL FIX: Create master records from sub data
            // The query getOutOfStockMastersWithDetails reads from OutOfStockMaster table
            // So we must ensure master exists before sub can be displayed
            final masters = outOfStockSubs.map((sub) {
              return OutOfStock(
                outOfStockId: sub.outosSubOutosId, // Master ID from sub
                outosOrderSubId: sub.outosSubOrderSubId,
                outosCustId: sub.outosSubCustId,
                outosSalesManId: sub.outosSubSalesManId,
                outosStockKeeperId: sub.outosSubStockKeeperId,
                outosDateAndTime: sub.outosSubDateAndTime,
                outosProdId: sub.outosSubProdId,
                outosUnitId: sub.outosSubUnitId,
                outosCarId: sub.outosSubCarId,
                outosQty: sub.outosSubQty,
                outosAvailableQty: sub.outosSubAvailableQty,
                outosUnitBaseQty: sub.outosSubUnitBaseQty,
                outosNarration: sub.outosSubNarration,
                outosIsCompleatedFlag: -1, // Default value
                outosFlag: 1, // Active
                uuid: sub.uuid,
                createdAt: sub.createdAt,
                updatedAt: sub.updatedAt,
              );
            }).toList();

            // Store masters first (INSERT OR REPLACE will update if exists)
            final addMastersResult = await _outOfStockRepository.addOutOfStockMasters(masters);
            addMastersResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add out of stock masters: ${failure.message}',
              ),
              (_) {},
            );

            // Then store subs
            final addResult = await _outOfStockRepository.addOutOfStockProducts(
              outOfStockSubs,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add out of stock products: ${failure.message}',
              ),
              (_) {},
            );
            NotificationManager().triggerRefresh();
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download customers (full sync or single record retry)
  /// Converted from KMP's downloadCustomer function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all customers in batches
  /// 2. Single record retry (id != -1): Downloads specific customer and handles FailedSync
  Future<void> _downloadCustomers({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Customer details downloading...');
    }

    final updateDate = _getSyncTimeForTable('Customer');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _customersRepository.syncCustomersFromApi(
      partNo: _customerPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry
          _failedSyncRepository
              .addFailedSync(
                tableId: 13, // NotificationId.CUSTOMER = 13
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message
          _updateError(failure.message, true);
        }
      },
      (customerListApi) async {
        final customers = (customerListApi.data ?? []).map((customer) {
          if (userType == 3) {
            final isAssigned = customer.salesManId == userId;
            final updatedFlag = isAssigned ? (customer.flag ?? 1) : 0;
            return customer.copyWith(flag: updatedFlag);
          }
          return customer;
        }).toList();

        if (id == -1) {
          // Full sync mode
          if (customers.isEmpty) {
            _isCustomerDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'Customers',
                  updateDate: customerListApi.updatedDate,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _customerPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _customersRepository.addCustomers(
              customers,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add customers: ${failure.message}',
              ),
              (_) {},
            );
            _customerPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matching KMP lines 768-774)
          if (customers.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _customersRepository.addCustomers(
              customers,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add customers: ${failure.message}',
              ),
              (_) {},
            );
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download users (full sync or single record retry)
  /// Converted from KMP's downloadUser function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all users in batches
  /// 2. Single record retry (id != -1): Downloads specific user and handles FailedSync
  Future<void> _downloadUsers({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Users details downloading...');
    }

    final updateDate = _getSyncTimeForTable('Users');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _usersRepository.syncUsersFromApi(
      partNo: _userPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry
          _failedSyncRepository
              .addFailedSync(
                tableId: 14, // NotificationId.USER = 14
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message
          _updateError(failure.message, true);
        }
      },
      (userListApi) async {
        final users = userListApi.data ?? [];

        if (id == -1) {
          // Full sync mode
          if (users.isEmpty) {
            _isUserDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'Users',
                  updateDate: userListApi.updatedDate,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _userPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _usersRepository.addUsers(users);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add users: ${failure.message}',
              ),
              (_) {},
            );
            _userPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode
          if (users.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _usersRepository.addUsers(users);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add users: ${failure.message}',
              ),
              (_) {},
            );
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download salesmen (full sync or single record retry)
  /// Converted from KMP's downloadSalesman function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all salesmen in batches
  /// 2. Single record retry (id != -1): Downloads specific salesman and handles FailedSync
  Future<void> _downloadSalesmen({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Salesman details downloading...');
    }

    final updateDate = _getSyncTimeForTable('SalesMan');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;

    final result = await _salesManRepository.syncSalesMenFromApi(
      partNo: _salesmanPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry (matches KMP line 825-826)
          _failedSyncRepository
              .addFailedSync(
                tableId: 15, // NotificationId.SALESMAN = 15
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message (matches KMP line 829)
          _updateError(failure.message, true);
        }
      },
      (response) async {
        final data = response['data'] as List<dynamic>?;
        final updatedDate = response['updated_date'] as String? ?? '';
        final salesmen =
            data
                ?.map(
                  (e) => SalesMan.fromMapServerData(e as Map<String, dynamic>),
                )
                .toList() ??
            [];

        if (id == -1) {
          // Full sync mode (matches KMP lines 836-845)
          if (salesmen.isEmpty) {
            _isSalesmanDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(tableName: 'SalesMan', updateDate: updatedDate)
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _salesmanPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _salesManRepository.addSalesMen(salesmen);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add salesmen: ${failure.message}',
              ),
              (_) {},
            );
            _salesmanPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matches KMP lines 846-849)
          if (salesmen.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _salesManRepository.addSalesMen(salesmen);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add salesmen: ${failure.message}',
              ),
              (_) {},
            );
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download suppliers (full sync or single record retry)
  /// Converted from KMP's downloadSupplier function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all suppliers in batches
  /// 2. Single record retry (id != -1): Downloads specific supplier and handles FailedSync
  Future<void> _downloadSuppliers({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Supplier details downloading...');
    }

    final updateDate = _getSyncTimeForTable('Supplier');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _suppliersRepository.syncSuppliersFromApi(
      partNo: _supplierPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry
          _failedSyncRepository
              .addFailedSync(
                tableId: 16, // NotificationId.SUPPLIER = 16
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message
          _updateError(failure.message, true);
        }
      },
      (response) async {
        final data = response['data'] as List<dynamic>?;
        final updatedDate = response['updated_date'] as String? ?? '';
        final suppliers =
            data
                ?.map(
                  (e) => Supplier.fromMapServerData(e as Map<String, dynamic>),
                )
                .toList() ??
            [];

        if (id == -1) {
          // Full sync mode
          if (suppliers.isEmpty) {
            _isSupplierDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(tableName: 'Suppliers', updateDate: updatedDate)
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _supplierPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _suppliersRepository.addSuppliers(
              suppliers,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add suppliers: ${failure.message}',
              ),
              (_) {},
            );
            _supplierPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matching KMP pattern)
          if (suppliers.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _suppliersRepository.addSuppliers(
              suppliers,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add suppliers: ${failure.message}',
              ),
              (_) {},
            );
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download routes (full sync or single record retry)
  /// Converted from KMP's downloadRoutes function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all routes in batches
  /// 2. Single record retry (id != -1): Downloads specific route and handles FailedSync
  Future<void> _downloadRoutes({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Route details downloading...');
    }
    final updateDate = _getSyncTimeForTable('Routes');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _routesRepository.syncRoutesFromApi(
      partNo: _routesPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry (matches KMP line 900-902)
          _failedSyncRepository
              .addFailedSync(
                tableId: 17, // NotificationId.ROUTES = 17
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message (matches KMP line 905)
          _updateError(failure.message, true);
        }
      },
      (routeListApi) async {
        final routes = routeListApi.data ?? [];
        if (id == -1) {
          // Full sync mode (matches KMP lines 912-920)
          if (routes.isEmpty) {
            _isRoutesDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'Routes',
                  updateDate: routeListApi.updatedDate,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _routesPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _routesRepository.addRoutes(routes);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add routes: ${failure.message}',
              ),
              (_) {},
            );
            _routesPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matches KMP lines 922-925)
          if (routes.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _routesRepository.addRoutes(routes);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add routes: ${failure.message}',
              ),
              (_) {},
            );
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download units (full sync or single record retry)
  /// Converted from KMP's downloadUnits function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all units in batches
  /// 2. Single record retry (id != -1): Downloads specific unit and handles FailedSync
  Future<void> _downloadUnits({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Units details downloading...');
    }
    final updateDate = _getSyncTimeForTable('Units');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _unitsRepository.syncUnitsFromApi(
      partNo: _unitsPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry (matches KMP line 940-942)
          _failedSyncRepository
              .addFailedSync(
                tableId: 18, // NotificationId.UNITS = 18
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message (matches KMP line 945)
          _updateError(failure.message, true);
        }
      },
      (unitListApi) async {
        final units = unitListApi.data ?? [];
        if (id == -1) {
          // Full sync mode (matches KMP lines 952-960)
          if (units.isEmpty) {
            _isUnitsDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'Units',
                  updateDate: unitListApi.updatedDate,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _unitsPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _unitsRepository.addUnits(units);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add units: ${failure.message}',
              ),
              (_) {},
            );
            _unitsPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matches KMP lines 962-965)
          if (units.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _unitsRepository.addUnits(units);
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add units: ${failure.message}',
              ),
              (_) {},
            );
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download product units from API
  /// Matches KMP's downloadProductUnits (SyncViewModel.kt lines 971-1008)
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all product units in batches
  /// 2. Single record retry (id != -1): Downloads specific product unit and handles FailedSync
  Future<void> _downloadProductUnits({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Product unit details downloading...');
    }

    final updateDate = _getSyncTimeForTable('ProductUnits');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;

    final result = await _productsRepository.syncProductUnitsFromApi(
      partNo: _productUnitsPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry (matches KMP line 978-980)
          _failedSyncRepository
              .addFailedSync(
                tableId: 19, // NotificationId.PRODUCT_UNITS = 19
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message (matches KMP line 982)
          _updateError(failure.message, true);
        }
      },
      (productUnitListApi) async {
        final productUnits = productUnitListApi.data ?? [];

        if (id == -1) {
          // Full sync mode (matches KMP lines 989-998)
          if (productUnits.isEmpty) {
            _isProductUnitsDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'ProductUnits',
                  updateDate: productUnitListApi.updated_date,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _productUnitsPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _productsRepository.addProductUnits(
              productUnits,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add product units: ${failure.message}',
              ),
              (_) {},
            );
            _productUnitsPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matches KMP lines 999-1005)
          if (productUnits.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _productsRepository.addProductUnits(
              productUnits,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add product units: ${failure.message}',
              ),
              (_) {},
            );
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download product cars (full sync or single record retry)
  /// Matches KMP's downloadProductCar (SyncViewModel.kt lines 1012-1046)
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all product cars in batches
  /// 2. Single record retry (id != -1): Downloads specific product car and handles FailedSync
  Future<void> _downloadProductCar({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('Product car details downloading...');
    }

    final updateDate = _getSyncTimeForTable('ProductCar');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;

    final result = await _productsRepository.syncProductCarsFromApi(
      partNo: _productCarPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry (matches KMP line 1018-1020)
          _failedSyncRepository
              .addFailedSync(
                tableId: 20, // NotificationId.PRODUCT_CAR = 20
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message (matches KMP line 1022)
          _updateError(failure.message, true);
        }
      },
      (productCarListApi) async {
        final productCars = productCarListApi.data ?? [];

        if (id == -1) {
          // Full sync mode (matches KMP lines 1029-1038)
          if (productCars.isEmpty) {
            _isProductCarDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'ProductCar',
                  updateDate: productCarListApi.updated_date,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _productCarPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _productsRepository.addProductCars(
              productCars,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add product cars: ${failure.message}',
              ),
              (_) {},
            );
            _productCarPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matches KMP lines 1039-1043)
          if (productCars.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _productsRepository.addProductCars(
              productCars,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add product car: ${failure.message}',
              ),
              (_) {},
            );
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Download user categories (full sync or single record retry)
  /// Converted from KMP's downloadUserCategory function
  /// Supports two modes matching KMP exactly:
  /// 1. Full sync (id == -1): Downloads all user categories in batches
  /// 2. Single record retry (id != -1): Downloads specific user category and handles FailedSync
  Future<void> _downloadUserCategories({
    int id = -1, // -1 for full sync, specific id for retry
    int failedId = -1, // FailedSync record id if this is a retry
    void Function()?
    finished, // Callback for retry mode (doesn't continue sync chain)
  }) async {
    if (id == -1) {
      // Full sync mode
      _updateTask('User Category details downloading...');
    }

    final updateDate = _getSyncTimeForTable('UsersCategory');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _userCategoryRepository.syncUserCategoriesFromApi(
      partNo: _userCategoryPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
      id: id, // Pass id parameter
    );

    result.fold(
      (failure) {
        // Error handling matching KMP
        if (id != -1 && failedId == -1) {
          // Retry mode failed: create FailedSync entry
          // Note: UserCategory doesn't have a specific NotificationId in KMP, using a placeholder
          // Check KMP's _syncFailedItem to see what tableId is used
          _failedSyncRepository
              .addFailedSync(
                tableId:
                    23, // Note: UserCategory doesn't appear in KMP's failed sync retry mechanism, using placeholder
                dataId: id,
              )
              .then((_) {
                if (finished != null) finished();
              });
        } else {
          // Full sync mode error: update error message
          _updateError(failure.message, true);
        }
      },
      (response) async {
        final data = response['data'] as List<dynamic>?;
        final updatedDate = response['updated_date'] as String? ?? '';
        final userCategories =
            data
                ?.map(
                  (e) =>
                      UserCategory.fromMapServerData(e as Map<String, dynamic>),
                )
                .toList() ??
            [];

        if (id == -1) {
          // Full sync mode
          if (userCategories.isEmpty) {
            _isUserCategoryDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository
                .addSyncTime(
                  tableName: 'UsersCategory',
                  updateDate: updatedDate,
                )
                .then((result) {
                  result.fold(
                    (failure) => developer.log(
                      'SyncProvider: Failed to add sync time: ${failure.message}',
                    ),
                    (_) {},
                  );
                });
            _userCategoryPart = 0;
            _startSyncDatabase();
          } else {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _userCategoryRepository.addUserCategories(
              userCategories,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add user categories: ${failure.message}',
              ),
              (_) {},
            );
            _userCategoryPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matching KMP pattern)
          if (userCategories.isNotEmpty) {
            // CRITICAL FIX: Await database operation to prevent locks
            final addResult = await _userCategoryRepository.addUserCategories(
              userCategories,
            );
            addResult.fold(
              (failure) => developer.log(
                'SyncProvider: Failed to add user categories: ${failure.message}',
              ),
              (_) {},
            );
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  /// Retry sync for failed item based on tableId
  /// Converted from KMP's download function (lines 1262-1295)
  Future<void> _syncFailedItem(FailedSync failedSync) async {
    // Ensure cached user data is initialized before retrying
    await _ensureUserDataInitialized();
    
    final failedId = failedSync.id;
    final tableId = failedSync.tableId;
    final dataId = failedSync.dataId;

    // Route to appropriate download method based on tableId (matches KMP's when expression)
    switch (tableId) {
      case 1: // NotificationId.PRODUCT = 1 (matches KMP line 1268)
        await _downloadProducts(
          id: dataId,
          failedId: failedId,
          finished: () {}, // Retry mode doesn't continue sync chain
        );
        break;
      case 2: // NotificationId.CAR_BRAND = 2 (matches KMP line 1269)
        await _downloadCarBrand(
          id: dataId,
          failedId: failedId,
          finished: () {},
        );
        break;
      case 3: // NotificationId.CAR_NAME = 3 (matches KMP line 1270)
        await _downloadCarName(id: dataId, failedId: failedId, finished: () {});
        break;
      case 4: // NotificationId.CAR_MODEL = 4 (matches KMP line 1271)
        await _downloadCarModel(
          id: dataId,
          failedId: failedId,
          finished: () {},
        );
        break;
      case 5: // NotificationId.CAR_VERSION = 5 (matches KMP line 1272)
        await _downloadCarVersion(
          id: dataId,
          failedId: failedId,
          finished: () {},
        );
        break;
      case 6: // NotificationId.CATEGORY = 6 (matches KMP line 1273)
        await _downloadCategory(
          id: dataId,
          failedId: failedId,
          finished: () {},
        );
        break;
      case 7: // NotificationId.SUB_CATEGORY = 7 (matches KMP line 1274)
        await _downloadSubCategory(
          id: dataId,
          failedId: failedId,
          finished: () {},
        );
        break;
      case 14: // NotificationId.USER = 14 (matches KMP line 1281)
        await _downloadUsers(id: dataId, failedId: failedId, finished: () {});
        break;
      case 15: // NotificationId.SALESMAN = 15 (matches KMP line 1282)
        await _downloadSalesmen(
          id: dataId,
          failedId: failedId,
          finished: () {},
        );
        break;
      case 17: // NotificationId.ROUTES = 17 (matches KMP line 1284)
        await _downloadRoutes(id: dataId, failedId: failedId, finished: () {});
        break;
      case 8: // NotificationId.ORDER = 8 (matches KMP line 1275)
        await _downloadOrders(id: dataId, failedId: failedId, finished: () {});
        break;
      case 9: // NotificationId.ORDER_SUB = 9 (matches KMP line 1276)
        await _downloadOrderSubs(
          id: dataId,
          failedId: failedId,
          finished: () {},
        );
        break;
      case 10: // NotificationId.ORDER_SUB_SUGGESTION = 10 (matches KMP line 1277)
        await _downloadOrderSubSuggestions(
          id: dataId,
          failedId: failedId,
          finished: () {},
        );
        break;
      case 11: // NotificationId.OUT_OF_STOCK = 11 (matches KMP line 1278)
        await _downloadOutOfStock(
          id: dataId,
          failedId: failedId,
          finished: () {},
        );
        break;
      case 12: // NotificationId.OUT_OF_STOCK_SUB = 12 (matches KMP line 1279)
        await _downloadOutOfStockSub(
          id: dataId,
          failedId: failedId,
          finished: () {},
        );
        break;
      case 13: // NotificationId.CUSTOMER = 13 (matches KMP line 1280)
        await _downloadCustomers(
          id: dataId,
          failedId: failedId,
          finished: () {},
        );
        break;
      case 16: // NotificationId.SUPPLIER = 16 (matches KMP line 1283)
        await _downloadSuppliers(
          id: dataId,
          failedId: failedId,
          finished: () {},
        );
        break;
      case 18: // NotificationId.UNITS = 18 (matches KMP line 1285)
        await _downloadUnits(id: dataId, failedId: failedId, finished: () {});
        break;
      case 19: // NotificationId.PRODUCT_UNITS = 19 (matches KMP line 1286)
        await _downloadProductUnits(
          id: dataId,
          failedId: failedId,
          finished: () {},
        );
        break;
      case 20: // NotificationId.PRODUCT_CAR = 20 (matches KMP line 1287)
        await _downloadProductCar(
          id: dataId,
          failedId: failedId,
          finished: () {},
        );
        break;
      case 21: // NotificationId.updateStoreKeeper = 21 (matches KMP line 1288)
        await updateStoreKeeper(id: dataId);
        break;
      default:
        // Unknown table type, just delete the failed sync
        await _failedSyncRepository.deleteFailedSync(failedId);
        break;
    }
  }

  // ============================================================================
  // Public Download Methods for Push Notifications
  // These methods download individual records by ID (called from PushNotificationHandler)
  // Converted from KMP's downloadX(id) methods in SyncViewModel.kt
  //
  // NOTE: Most of these methods require updating the corresponding private _downloadX
  // methods to support the 'id' parameter. See PUSH_NOTIFICATIONS_IMPLEMENTATION.md
  // ============================================================================

  /// Download single product by ID
  /// ✅ Already implemented - _downloadProducts supports id parameter
  Future<void> downloadProduct({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadProducts(id: id);
  }

  /// Download single car brand by ID
  /// ✅ Already implemented - _downloadCarBrand supports id parameter
  Future<void> downloadCarBrand({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadCarBrand(id: id);
  }

  /// Download single car name by ID
  /// ✅ Already implemented - _downloadCarName supports id parameter
  Future<void> downloadCarName({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadCarName(id: id);
  }

  /// Download single car model by ID
  /// ✅ Already implemented - _downloadCarModel supports id parameter
  Future<void> downloadCarModel({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadCarModel(id: id);
  }

  /// Download single car version by ID
  /// ✅ Already implemented - _downloadCarVersion supports id parameter
  Future<void> downloadCarVersion({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadCarVersion(id: id);
  }

  /// Download single category by ID
  /// ✅ Already implemented - _downloadCategory supports id parameter
  Future<void> downloadCategory({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadCategory(id: id);
  }

  /// Download single sub-category by ID
  /// ✅ Already implemented - _downloadSubCategory supports id parameter
  Future<void> downloadSubCategory({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadSubCategory(id: id);
  }

  /// Download single order by ID
  /// ✅ Already implemented - _downloadOrders supports id parameter
  Future<void> downloadOrder({required int id}) async {
    await _ensureUserDataInitialized();
    if (id != -1) {
      developer.log('Handling order download for id: $id');
    }
    await _downloadOrders(id: id);
  }

  /// Download single order sub by ID
  /// ✅ Already implemented - _downloadOrderSubs supports id parameter
  Future<void> downloadOrderSub({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadOrderSubs(id: id);
  }

  /// Download single order sub suggestion by ID
  /// ✅ Already implemented - _downloadOrderSubSuggestions supports id parameter
  Future<void> downloadOrderSubSuggestion({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadOrderSubSuggestions(id: id);
  }

  /// Download single out of stock master by ID
  /// ✅ Already implemented - _downloadOutOfStock supports id parameter
  Future<void> downloadOutOfStock({required int id}) async {
    developer.log('downloadOutOfStock: downloading out of stock with id: $id');
    await _ensureUserDataInitialized();
    await _downloadOutOfStock(id: id);
  }

  /// Download single out of stock sub by ID
  /// ✅ Already implemented - _downloadOutOfStockSub supports id parameter
  Future<void> downloadOutOfStockSub({required int id}) async {
    developer.log('downloadOutOfStockSub: downloading out of stock sub with id: $id');
    await _ensureUserDataInitialized();
    await _downloadOutOfStockSub(id: id);
  }

  /// Download single customer by ID
  /// ✅ Already implemented - _downloadCustomers supports id parameter
  Future<void> downloadCustomer({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadCustomers(id: id);
  }

  /// Download single user by ID
  /// ✅ Already implemented - _downloadUsers supports id parameter
  Future<void> downloadUser({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadUsers(id: id);
  }

  /// Download single salesman by ID
  /// ✅ Already implemented - _downloadSalesmen supports id parameter
  Future<void> downloadSalesman({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadSalesmen(id: id);
  }

  /// Download single supplier by ID
  /// ✅ Already implemented - _downloadSuppliers supports id parameter
  Future<void> downloadSupplier({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadSuppliers(id: id);
  }

  /// Download single route by ID
  /// ✅ Already implemented - _downloadRoutes supports id parameter
  Future<void> downloadRoutes({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadRoutes(id: id);
  }

  /// Download single unit by ID
  /// ✅ Already implemented - _downloadUnits supports id parameter
  Future<void> downloadUnits({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadUnits(id: id);
  }

  /// Download single product unit by ID
  /// ✅ Already implemented - _downloadProductUnits supports id parameter
  Future<void> downloadProductUnits({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadProductUnits(id: id);
  }

  /// Download single product car by ID
  /// ✅ Already implemented - _downloadProductCar supports id parameter
  Future<void> downloadProductCar({required int id}) async {
    await _ensureUserDataInitialized();
    await _downloadProductCar(id: id);
  }

  /// Update store keeper (special notification type)
  /// Matches KMP's updateStoreKeeper (SyncViewModel.kt line 1089-1112)
  Future<void> updateStoreKeeper({required int id}) async {
    // Ensure cached user data is initialized before updating
    await _ensureUserDataInitialized();
    
    try {
      developer.log('SyncProvider: updateStoreKeeper called with id: $id');

      // Download order from API (matching KMP line 1092)
      // Uses orderDownload endpoint with id parameter
      final result = await _ordersRepository.syncOrdersFromApi(
        partNo: _orderPart,
        limit: _limit,
        userType: _cachedUserType ?? 0,
        userId: _cachedUserId ?? 0,
        updateDate: '', // Not used for single record download (id != -1)
        id: id, // Download specific order by ID
      );

      result.fold(
        (failure) {
          // Store in FailedSync for retry (matching KMP line 1094-1095)
          _failedSyncRepository
              .addFailedSync(
                tableId: 21, // NotificationId.updateStoreKeeper = 21
                dataId: id,
              )
              .then((_) {
                developer.log(
                  'SyncProvider: updateStoreKeeper failed for order $id, stored in FailedSync',
                );
              });
          developer.log(
            'SyncProvider: updateStoreKeeper failed for order $id: ${failure.message}',
          );
        },
        (orderListApi) async {
          final orders = orderListApi.data ?? [];
          if (orders.isNotEmpty) {
            final order = orders[0];
            final userType = _cachedUserType ?? 0;
            final userId = _cachedUserId ?? 0;

            // Add order to local DB with filtering (matching KMP's addOrder with filtering)
            // This ensures the order is added if it doesn't exist, and filtered based on userType
            final addResult = await _ordersRepository.addOrder(
              order,
              userType: userType,
              userId: userId,
              isNotification: true,
            );

            addResult.fold(
              (failure) {
                developer.log(
                  'SyncProvider: Failed to add order ${order.orderId}: ${failure.message}',
                );
              },
              (_) {
                // After adding, update storekeeperId in local DB (matching KMP line 1105)
                _ordersRepository
                    .updateOrderStoreKeeperLocal(
                      orderId: order.orderId,
                      storekeeperId: order.orderStockKeeperId,
                    )
                    .then((updateResult) {
                      updateResult.fold(
                        (failure) {
                          developer.log(
                            'SyncProvider: Failed to update storekeeperId for order ${order.orderId}: ${failure.message}',
                          );
                        },
                        (_) {
                          developer.log(
                            'SyncProvider: updateStoreKeeper successful for order ${order.orderId}, storekeeperId: ${order.orderStockKeeperId}',
                          );
                        },
                      );
                    });
              },
            );
          } else {
            developer.log(
              'SyncProvider: updateStoreKeeper - no orders returned for id: $id',
            );
          }
        },
      );
    } catch (e, stackTrace) {
      developer.log(
        'SyncProvider: updateStoreKeeper error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      // Store in FailedSync for retry
      await _failedSyncRepository.addFailedSync(
        tableId: 21, // NotificationId.updateStoreKeeper = 21
        dataId: id,
      );
    }
  }

  Future<void> logout() async {
    developer.log(
      'SyncProvider: logout() - Start (triggered by push notification)',
    );
    _isSyncing = true;
    notifyListeners();
    try {
      await clearAllTable();
      final authProvider = getIt<AuthProvider>();
      await authProvider.logout();
      NotificationManager().triggerLogout();
      developer.log('SyncProvider: logout() - Completed');
    } catch (e, stackTrace) {
      developer.log(
        'SyncProvider: logout() - Error: $e',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /// Pre-fetch all sync times at start (Solution 3: Performance optimization)
  /// This eliminates hundreds of redundant DB queries during sync
  /// Converted from KMP's pattern where sync time is retrieved once per table
  Future<void> _prefetchAllSyncTimes() async {
    developer.log(
      'SyncProvider: _prefetchAllSyncTimes() - Pre-fetching all sync times',
    );
    _syncTimeCache.clear();

    // List of all tables that need sync times (matching KMP's sync order)
    final tables = [
      'Product',
      'CarBrand',
      'CarName',
      'CarModel',
      'CarVersion',
      'Category',
      'SubCategory',
      'Orders',
      'OrderSub',
      'OrderSubSuggestion',
      'OutOfStockMaster',
      'OutOfStockProducts',
      'Customer',
      'Users',
      'SalesMan',
      'Supplier',
      'Routes',
      'Units',
      'ProductUnits',
      'ProductCar',
      'UsersCategory',
    ];

    // Pre-fetch all sync times in parallel for better performance
    final futures = tables.map((table) async {
      final syncTimeResult = await _syncTimeRepository.getSyncTime(table);
      final updateDate = syncTimeResult.fold(
        (_) => '',
        (syncTime) => syncTime?.updateDate ?? '',
      );
      _syncTimeCache[table] = updateDate;
      developer.log('SyncProvider: Cached sync time for $table: $updateDate');
    });

    await Future.wait(futures);
    developer.log(
      'SyncProvider: _prefetchAllSyncTimes() - Completed, cached ${_syncTimeCache.length} sync times',
    );
  }

  /// Get sync time for current table (uses cache after pre-fetch)
  /// Matches KMP's getSyncTimeParams but uses pre-fetched cache
  String _getSyncTimeForTable(String tableName) {
    // Return cached sync time (pre-fetched at start)
    final cachedTime = _syncTimeCache[tableName] ?? '';
    if (cachedTime.isEmpty) {
      developer.log(
        'SyncProvider: WARNING - No cached sync time for $tableName, using empty string',
      );
    }
    return cachedTime;
  }

  void _updateTask(String task) {
    developer.log('SyncProvider: _updateTask() - $task');
    _currentTask = task;
    notifyListeners();
  }

  void _updateError(String message, bool show) {
    developer.log('SyncProvider: _updateError() - $message (show: $show)');
    _errorMessage = message;
    _showError = show;
    _isSyncing = false; // Stop syncing on error
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    _showError = false;
  }

  /// Clear all tables (used during logout)
  /// Converted from KMP's clearAllTable function
  Future<void> clearAllTable() async {
    developer.log('SyncProvider: clearAllTable() - Clearing all tables');
    try {
      await _productsRepository.clearAll();
      await _unitsRepository.clearAll();
      await _categoriesRepository.clearAll();
      await _subCategoriesRepository.clearAll();
      await _carBrandRepository.clearAll();
      await _carNameRepository.clearAll();
      await _carVersionRepository.clearAll();
      await _carModelRepository.clearAll();
      await _usersRepository.clearAll();
      await _routesRepository.clearAll();
      await _salesManRepository.clearAll();
      await _suppliersRepository.clearAll();
      await _customersRepository.clearAll();
      await _ordersRepository.clearAll();
      await _outOfStockRepository.clearAll();
      await _orderSubSuggestionsRepository.clearAll();
      await _failedSyncRepository.clearAll();
      await _syncTimeRepository.clearAll();
      await _packedSubsRepository.clearAll();

      developer.log('SyncProvider: clearAllTable() - All tables cleared');
    } catch (e) {
      developer.log('SyncProvider: clearAllTable() - Error: $e');
      rethrow;
    }
  }

  /// Logout all users from all devices (admin only - matches KMP About screen)
  Future<void> logoutAllUsersFromDevices() async {
    developer.log('SyncProvider: logoutAllUsersFromDevices() - Start');

    final usersResult = await _usersRepository.getAllUsers();
    final users = usersResult.fold<List<User>>((failure) {
      developer.log(
        'SyncProvider: logoutAllUsersFromDevices() - Failed to load users: ${failure.message}',
      );
      throw Exception(failure.message);
    }, (data) => data);

    final currentUserId = await StorageHelper.getUserId();
    final payload = _buildLogoutNotificationPayload(users, currentUserId);

    final result = await _usersRepository.logoutAllUsersFromDevices(
      currentUserId: currentUserId,
      notificationPayload: payload,
    );

    result.fold(
      (failure) {
        developer.log(
          'SyncProvider: logoutAllUsersFromDevices() - API error: ${failure.message}',
        );
        throw Exception(failure.message);
      },
      (_) =>
          developer.log('SyncProvider: logoutAllUsersFromDevices() - Success'),
    );
  }

  Map<String, dynamic> _buildLogoutNotificationPayload(
    List<User> users,
    int currentUserId,
  ) {
    final ids = users
        .where((user) => user.userId != currentUserId)
        .map((user) => {'user_id': user.userId ?? -1, 'silent_push': 1})
        .toList();

    return {
      'ids': ids,
      'data_message': 'Logout device',
      'data': {
        'data_ids': [
          {'table': NotificationId.logout, 'id': 0},
        ],
        'show_notification': '0',
        'message': 'Logout device',
      },
    };
  }

  /// Update progress with throttling (Priority 2: Performance optimization)
  /// Only updates UI at most every 500ms to reduce rebuild overhead
  void _updateProgress() {
    // Priority 2: Throttle progress updates
    final now = DateTime.now();
    if (_lastProgressUpdate != null &&
        now.difference(_lastProgressUpdate!) < _progressUpdateInterval) {
      return; // Skip update - too soon since last one
    }
    _lastProgressUpdate = now;

    // Priority 4: Use cached completed tables count (simplified calculation)
    int totalTables = 19; // Total number of tables to sync (updated count)

    // Add partial progress for current table being synced
    double currentTableProgress = 0.0;
    if (!_isProductDownloaded && _productPart > 0) {
      // Estimate: each batch is ~5% of products (assuming ~10,000 products = 20 batches)
      // Use a conservative estimate: each batch = 2% progress within the table
      currentTableProgress = (_productPart * 0.02).clamp(0.0, 0.95);
    } else if (!_isCarBrandDownloaded && _carBrandPart > 0) {
      currentTableProgress = (_carBrandPart * 0.1).clamp(0.0, 0.95);
    } else if (!_isCarNameDownloaded && _carNamePart > 0) {
      currentTableProgress = (_carNamePart * 0.1).clamp(0.0, 0.95);
    } else if (!_isCarModelDownloaded && _carModelPart > 0) {
      currentTableProgress = (_carModelPart * 0.1).clamp(0.0, 0.95);
    } else if (!_isCarVersionDownloaded && _carVersionPart > 0) {
      currentTableProgress = (_carVersionPart * 0.1).clamp(0.0, 0.95);
    } else if (!_isCategoryDownloaded && _categoryPart > 0) {
      currentTableProgress = (_categoryPart * 0.1).clamp(0.0, 0.95);
    } else if (!_isSubCategoryDownloaded && _subCategoryPart > 0) {
      currentTableProgress = (_subCategoryPart * 0.1).clamp(0.0, 0.95);
    } else if (!_isOrderDownloaded && _orderPart > 0) {
      currentTableProgress = (_orderPart * 0.02).clamp(0.0, 0.95);
    } else if (!_isOrderSubDownloaded && _orderSubPart > 0) {
      currentTableProgress = (_orderSubPart * 0.02).clamp(0.0, 0.95);
    } else if (!_isOrderSubSuggestionDownloaded &&
        _orderSubSuggestionPart > 0) {
      currentTableProgress = (_orderSubSuggestionPart * 0.1).clamp(0.0, 0.95);
    } else if (!_isOutOfStockDownloaded && _outOfStockPart > 0) {
      currentTableProgress = (_outOfStockPart * 0.1).clamp(0.0, 0.95);
    } else if (!_isOutOfStockSubDownloaded && _outOfStockSubPart > 0) {
      currentTableProgress = (_outOfStockSubPart * 0.1).clamp(0.0, 0.95);
    } else if (!_isCustomerDownloaded && _customerPart > 0) {
      currentTableProgress = (_customerPart * 0.1).clamp(0.0, 0.95);
    } else if (!_isUserDownloaded && _userPart > 0) {
      currentTableProgress = (_userPart * 0.1).clamp(0.0, 0.95);
    } else if (!_isSalesmanDownloaded && _salesmanPart > 0) {
      currentTableProgress = (_salesmanPart * 0.1).clamp(0.0, 0.95);
    } else if (!_isSupplierDownloaded && _supplierPart > 0) {
      currentTableProgress = (_supplierPart * 0.1).clamp(0.0, 0.95);
    } else if (!_isRoutesDownloaded && _routesPart > 0) {
      currentTableProgress = (_routesPart * 0.1).clamp(0.0, 0.95);
    } else if (!_isUnitsDownloaded && _unitsPart > 0) {
      currentTableProgress = (_unitsPart * 0.1).clamp(0.0, 0.95);
    } else if (!_isProductUnitsDownloaded && _productUnitsPart > 0) {
      currentTableProgress = (_productUnitsPart * 0.1).clamp(0.0, 0.95);
    } else if (!_isUserCategoryDownloaded && _userCategoryPart > 0) {
      currentTableProgress = (_userCategoryPart * 0.1).clamp(0.0, 0.95);
    }

    // Calculate total progress: completed tables + partial progress for current table
    _progress = (_completedTablesCount + currentTableProgress) / totalTables;
    developer.log(
      'SyncProvider: _updateProgress() - Completed: $_completedTablesCount, Current table progress: ${(currentTableProgress * 100).toStringAsFixed(1)}%, Total: ${(_progress * 100).toStringAsFixed(1)}%',
    );
    notifyListeners();
  }

  void _resetSyncFlags() {
    _isProductDownloaded = false;
    _isCarBrandDownloaded = false;
    _isCarNameDownloaded = false;
    _isCarModelDownloaded = false;
    _isCarVersionDownloaded = false;
    _isCategoryDownloaded = false;
    _isSubCategoryDownloaded = false;
    _isOrderDownloaded = false;
    _isOrderSubDownloaded = false;
    _isOrderSubSuggestionDownloaded = false;
    _isOutOfStockDownloaded = false;
    _isOutOfStockSubDownloaded = false;
    _isCustomerDownloaded = false;
    _isUserDownloaded = false;
    _isSalesmanDownloaded = false;
    _isSupplierDownloaded = false;
    _isRoutesDownloaded = false;
    _isUnitsDownloaded = false;
    _isProductUnitsDownloaded = false;
    _isUserCategoryDownloaded = false;
  }

  void _resetBatchCounters() {
    _productPart = 0;
    _carBrandPart = 0;
    _carNamePart = 0;
    _carModelPart = 0;
    _carVersionPart = 0;
    _categoryPart = 0;
    _subCategoryPart = 0;
    _orderPart = 0;
    _orderSubPart = 0;
    _orderSubSuggestionPart = 0;
    _outOfStockPart = 0;
    _outOfStockSubPart = 0;
    _customerPart = 0;
    _userPart = 0;
    _salesmanPart = 0;
    _supplierPart = 0;
    _routesPart = 0;
    _unitsPart = 0;
    _productUnitsPart = 0;
    _userCategoryPart = 0;
  }

  /// Initialize cached user data (call once at start of sync)
  /// Matching KMP pattern where userType/userId are class properties (lines 76-77)
  Future<void> _initializeUserData() async {
    _cachedUserType = await StorageHelper.getUserType();
    _cachedUserId = await StorageHelper.getUserId();
    developer.log(
      'SyncProvider: User data cached - userType: $_cachedUserType, userId: $_cachedUserId',
    );
  }

  /// Ensure cached user data is initialized (lazy initialization)
  /// Called by public download methods to ensure cached values exist before use
  /// This prevents null errors when notifications trigger downloads before startSync() is called
  Future<void> _ensureUserDataInitialized() async {
    if (_cachedUserType == null || _cachedUserId == null) {
      developer.log(
        'SyncProvider: Cached user data not initialized, initializing now...',
      );
      await _initializeUserData();
    }
  }
}
