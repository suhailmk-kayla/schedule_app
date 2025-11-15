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
import '../../utils/storage_helper.dart';

/// Sync Provider
/// Handles batch downloading and syncing all master data
/// Converted from KMP's SyncViewModel.kt
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
  })  : _productsRepository = productsRepository,
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
      developer.log('SyncProvider: startSync() called but already syncing, ignoring');
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
      developer.log('SyncProvider: Exception in startSync: $e', error: e, stackTrace: stackTrace);
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
    failedResult.fold(
      (failure) => _updateError(failure.message, true),
      (failedSyncs) async {
        for (final failedSync in failedSyncs) {
          await _syncFailedItem(failedSync);
        }
      },
    );
  }

  /// Get all failed syncs
  Future<List<FailedSync>> getAllFailedSyncs() async {
    final result = await _failedSyncRepository.getAllFailedSyncs();
    return result.fold(
      (failure) => [],
      (failedSyncs) => failedSyncs,
    );
  }

  // ============================================================================
  // Private Sync Methods
  // ============================================================================

  // Track current syncing table for sync time retrieval
  String _syncingTable = '';



  Future<void> _startSyncDatabase() async {
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
      await _downloadProducts();
    } else if (!_isCarBrandDownloaded) {
      _syncingTable = 'CarBrand';
      await _downloadCarBrand();
    } else if (!_isCarNameDownloaded) {
      await _downloadCarName();
    } else if (!_isCarModelDownloaded) {
      await _downloadCarModel();
    } else if (!_isCarVersionDownloaded) {
      await _downloadCarVersion();
    } else if (!_isCategoryDownloaded) {
      await _downloadCategory();
    } else if (!_isSubCategoryDownloaded) {
      await _downloadSubCategory();
    } else if (!_isOrderDownloaded && userType != 4) {
      await _downloadOrders();
    } else if (!_isOrderSubDownloaded && userType != 4) {
      await _downloadOrderSubs();
    } else if (!_isOrderSubSuggestionDownloaded && userType != 4) {
      await _downloadOrderSubSuggestions();
    } else if (!_isOutOfStockDownloaded && (userType == 1 || userType == 4)) {
      await _downloadOutOfStock();
    } else if (!_isOutOfStockSubDownloaded &&
        (userType == 1 || userType == 2 || userType == 4)) {
      await _downloadOutOfStockSub();
    } else if (!_isCustomerDownloaded && userType != 4) {
      await _downloadCustomers();
    } else if (!_isUserDownloaded) {
      await _downloadUsers();
    } else if (!_isSalesmanDownloaded && userType != 4) {
      _syncingTable = 'Salesman';
      await _downloadSalesmen();
    } else if (!_isSupplierDownloaded && userType != 4) {
      await _downloadSuppliers();
    } else if (!_isRoutesDownloaded) {
      await _downloadRoutes();
    } else if (!_isUnitsDownloaded) {
      await _downloadUnits();
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
      developer.log('SyncProvider: Exception in _startSyncDatabase: $e', error: e, stackTrace: stackTrace);
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
    void Function()? finished, // Callback for retry mode (doesn't continue sync chain)
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
      
      developer.log('SyncProvider: _downloadProducts() - part_no=$_productPart, user_type=$userType, user_id=$userId, update_date=$updateDate, id=$id');
      
      final result = await _productsRepository.syncProductsFromApi(
        partNo: _productPart,
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
            // Retry mode failed: create FailedSync entry (matches KMP line 200-203)
            _failedSyncRepository.addFailedSync(
              tableId: 1, // NotificationId.PRODUCT = 1
              dataId: id,
            ).then((_) {
              if (finished != null) finished();
            });
          } else {
            // Full sync mode error: update error message (matches KMP line 209)
            developer.log('SyncProvider: _downloadProducts() - Error: ${failure.message}');
            _updateError(failure.message, true);
            _isSyncing = false;
            notifyListeners();
          }
        },
        (productListApi) async {
          final products = productListApi.data ?? [];
          developer.log('SyncProvider: _downloadProducts() - Received ${products.length} products');
          
          if (id == -1) {
            // Full sync mode (matches KMP lines 216-225)
            if (products.isEmpty) {
              developer.log('SyncProvider: _downloadProducts() - No more products, marking as downloaded');
              _isProductDownloaded = true;
              _completedTablesCount++; // Priority 4: Track completed tables
              // Fire-and-forget sync time write (matching KMP pattern)
              _syncTimeRepository.addSyncTime(
                tableName: 'Product',
                updateDate: productListApi.updated_date,
              ).then((result) {
                result.fold(
                  (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
                  (_) => developer.log('SyncProvider: Sync time added for Product'),
                );
              });
              _productPart = 0;
              _updateProgress();
              // Proceed immediately to next table (fire-and-forget pattern)
              _startSyncDatabase();
            } else {
              developer.log('SyncProvider: _downloadProducts() - Adding ${products.length} products to DB');
              // Fire-and-forget DB write (matching KMP pattern)
              _productsRepository.addProducts(products).then((result) {
                result.fold(
                  (failure) {
                    developer.log('SyncProvider: Failed to add products to DB: ${failure.message}');
                    _updateError('Failed to save products: ${failure.message}', true);
                    _isSyncing = false;
                    notifyListeners();
                  },
                  (_) {
                    developer.log('SyncProvider: Products added to DB successfully');
                  },
                );
              });
              _productPart++;
              _updateProgress();
              // Proceed immediately to next batch (fire-and-forget pattern)
              _startSyncDatabase();
            }
          } else {
            // Single record retry mode (matches KMP lines 226-230)
            if (products.isNotEmpty) {
              // Fire-and-forget DB write (matching KMP pattern)
              _productsRepository.addProducts(products).then((result) {
                result.fold(
                  (failure) => developer.log('SyncProvider: Failed to add products: ${failure.message}'),
                  (_) {},
                );
              });
            }
            if (failedId != -1) {
              await _failedSyncRepository.deleteFailedSync(failedId);
            }
            if (finished != null) finished();
          }
        },
      );
    } catch (e, stackTrace) {
      developer.log('SyncProvider: Exception in _downloadProducts: $e', error: e, stackTrace: stackTrace);
      _updateError('Product download error: ${e.toString()}', true);
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _downloadCarBrand() async {
    developer.log('SyncProvider: _downloadCarBrand() - Part: $_carBrandPart');
    _updateTask('Car details downloading...');
    
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
      );

      result.fold(
        (failure) {
          developer.log('SyncProvider: _downloadCarBrand() - Error: ${failure.message}');
          _updateError(failure.message, true);
          _isSyncing = false;
          notifyListeners();
        },
        (carBrandListApi) async {
          final brands = carBrandListApi.data ?? [];
          developer.log('SyncProvider: _downloadCarBrand() - Received ${brands.length} brands');
          
          if (brands.isEmpty) {
            developer.log('SyncProvider: _downloadCarBrand() - No more brands, marking as downloaded');
            _isCarBrandDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository.addSyncTime(
              tableName: 'CarBrand',
              updateDate: carBrandListApi.updatedDate,
            ).then((result) {
              result.fold(
                (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
                (_) => developer.log('SyncProvider: Sync time added for CarBrand'),
              );
            });
            _carBrandPart = 0;
            _updateProgress();
            // Proceed immediately to next table (fire-and-forget pattern)
            _startSyncDatabase();
          } else {
            // Fire-and-forget DB write (matching KMP pattern)
            _carBrandRepository.addCarBrands(brands).then((result) {
              result.fold(
                (failure) {
                  developer.log('SyncProvider: Failed to add brands to DB: ${failure.message}');
                  _updateError('Failed to save brands: ${failure.message}', true);
                  _isSyncing = false;
                  notifyListeners();
                },
                (_) {
                  developer.log('SyncProvider: Brands added to DB successfully');
                },
              );
            });
            _carBrandPart++;
            _updateProgress();
            // Proceed immediately to next batch (fire-and-forget pattern)
            _startSyncDatabase();
          }
        },
      );
    } catch (e, stackTrace) {
      developer.log('SyncProvider: Exception in _downloadCarBrand: $e', error: e, stackTrace: stackTrace);
      _updateError('Car brand download error: ${e.toString()}', true);
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _downloadCarName() async {
    _updateTask('Car details downloading...');
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
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (carNameListApi) async {
        final names = carNameListApi.data ?? [];
        if (names.isEmpty) {
          _isCarNameDownloaded = true;
          _completedTablesCount++; // Priority 4: Track completed tables
          // Fire-and-forget sync time write (matching KMP pattern)
          _syncTimeRepository.addSyncTime(
            tableName: 'CarName',
            updateDate: carNameListApi.updatedDate,
          ).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
              (_) {},
            );
          });
          _carNamePart = 0;
          _startSyncDatabase();
        } else {
          // Fire-and-forget DB write (matching KMP pattern)
          _carNameRepository.addCarNames(names).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add car names: ${failure.message}'),
              (_) {},
            );
          });
          _carNamePart++;
          _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadCarModel() async {
    _updateTask('Car details downloading...');
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
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (carModelListApi) async {
        final models = carModelListApi.data ?? [];
        if (models.isEmpty) {
          _isCarModelDownloaded = true;
          _completedTablesCount++; // Priority 4: Track completed tables
          // Fire-and-forget sync time write (matching KMP pattern)
          _syncTimeRepository.addSyncTime(
            tableName: 'CarModel',
            updateDate: carModelListApi.updatedDate,
          ).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
              (_) {},
            );
          });
          _carModelPart = 0;
          _startSyncDatabase();
        } else {
          // Fire-and-forget DB write (matching KMP pattern)
          _carModelRepository.addCarModels(models).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add car models: ${failure.message}'),
              (_) {},
            );
          });
          _carModelPart++;
          _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadCarVersion() async {
    _updateTask('Car details downloading...');
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
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (carVersionListApi) async {
        final versions = carVersionListApi.data ?? [];
        if (versions.isEmpty) {
          _isCarVersionDownloaded = true;
          _completedTablesCount++; // Priority 4: Track completed tables
          // Fire-and-forget sync time write (matching KMP pattern)
          _syncTimeRepository.addSyncTime(
            tableName: 'CarVersion',
            updateDate: carVersionListApi.updatedDate,
          ).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
              (_) {},
            );
          });
          _carVersionPart = 0;
          _startSyncDatabase();
        } else {
          // Fire-and-forget DB write (matching KMP pattern)
          _carVersionRepository.addCarVersions(versions).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add car versions: ${failure.message}'),
              (_) {},
            );
          });
          _carVersionPart++;
          _startSyncDatabase();
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
    void Function()? finished, // Callback for retry mode (doesn't continue sync chain)
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
          _failedSyncRepository.addFailedSync(
            tableId: 6, // NotificationId.CATEGORY = 6
            dataId: id,
          ).then((_) {
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
            _syncTimeRepository.addSyncTime(
              tableName: 'Category',
              updateDate: categoryListApi.updatedDate,
            ).then((result) {
              result.fold(
                (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
                (_) {},
              );
            });
            _categoryPart = 0;
            _startSyncDatabase();
          } else {
            // Fire-and-forget DB write (matching KMP pattern)
            _categoriesRepository.addCategories(categories).then((result) {
              result.fold(
                (failure) => developer.log('SyncProvider: Failed to add categories: ${failure.message}'),
                (_) {},
              );
            });
            _categoryPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode
          if (categories.isNotEmpty) {
            // Fire-and-forget DB write (matching KMP pattern)
            _categoriesRepository.addCategories(categories).then((result) {
              result.fold(
                (failure) => developer.log('SyncProvider: Failed to add categories: ${failure.message}'),
                (_) {},
              );
            });
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  Future<void> _downloadSubCategory() async {
    _updateTask('Sub-Category downloading...');
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
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (subCategoryListApi) async {
        final subCategories = subCategoryListApi.data ?? [];
        if (subCategories.isEmpty) {
          _isSubCategoryDownloaded = true;
          _completedTablesCount++; // Priority 4: Track completed tables
          // Fire-and-forget sync time write (matching KMP pattern)
          _syncTimeRepository.addSyncTime(
            tableName: 'SubCategory',
            updateDate: subCategoryListApi.updatedDate,
          ).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
              (_) {},
            );
          });
          _subCategoryPart = 0;
          _startSyncDatabase();
        } else {
          // Fire-and-forget DB write (matching KMP pattern)
          _subCategoriesRepository.addSubCategories(subCategories).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add sub categories: ${failure.message}'),
              (_) {},
            );
          });
          _subCategoryPart++;
          _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadOrders() async {
    _updateTask('Order details downloading...');
    final updateDate = _getSyncTimeForTable('Orders');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _ordersRepository.syncOrdersFromApi(
      partNo: _orderPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (orderListApi) async {
        final orders = orderListApi.data ?? [];
        if (orders.isEmpty) {
          _isOrderDownloaded = true;
          _completedTablesCount++; // Priority 4: Track completed tables
          // Fire-and-forget sync time write (matching KMP pattern)
          _syncTimeRepository.addSyncTime(
            tableName: 'Orders',
            updateDate: orderListApi.updatedDate,
          ).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
              (_) {},
            );
          });
          _orderPart = 0;
          _startSyncDatabase();
        } else {
          // Fire-and-forget DB write (matching KMP pattern)
          _ordersRepository.addOrders(orders).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add orders: ${failure.message}'),
              (_) {},
            );
          });
          _orderPart++;
          _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadOrderSubs() async {
    _updateTask('Order details downloading...');
    final updateDate = _getSyncTimeForTable('OrderSub');
    // Use cached values (matching KMP pattern - no async storage reads)
    final userType = _cachedUserType ?? 0;
    final userId = _cachedUserId ?? 0;
    final result = await _ordersRepository.syncOrderSubsFromApi(
      partNo: _orderSubPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (orderSubListApi) async {
        final orderSubs = orderSubListApi.data ?? [];
        if (orderSubs.isEmpty) {
          _isOrderSubDownloaded = true;
          _completedTablesCount++; // Priority 4: Track completed tables
          // Fire-and-forget sync time write (matching KMP pattern)
          _syncTimeRepository.addSyncTime(
            tableName: 'OrderSub',
            updateDate: orderSubListApi.updatedDate,
          ).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
              (_) {},
            );
          });
          _orderSubPart = 0;
          _startSyncDatabase();
        } else {
          // Fire-and-forget DB write (matching KMP pattern)
          _ordersRepository.addOrderSubs(orderSubs).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add order subs: ${failure.message}'),
              (_) {},
            );
          });
          _orderSubPart++;
          _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadOrderSubSuggestions() async {
    _updateTask('Order details downloading...');
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
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (suggestionsListApi) async {
        final suggestions = suggestionsListApi.data ?? [];
        if (suggestions.isEmpty) {
          _isOrderSubSuggestionDownloaded = true;
          _completedTablesCount++; // Priority 4: Track completed tables
          // Fire-and-forget sync time write (matching KMP pattern)
          _syncTimeRepository.addSyncTime(
            tableName: 'OrderSubSuggestions',
            updateDate: suggestionsListApi.updatedDate,
          ).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
              (_) {},
            );
          });
          _orderSubSuggestionPart = 0;
          _startSyncDatabase();
        } else {
          // Fire-and-forget DB write (matching KMP pattern)
          _orderSubSuggestionsRepository.addSuggestions(suggestions).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add order sub suggestions: ${failure.message}'),
              (_) {},
            );
          });
          _orderSubSuggestionPart++;
          _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadOutOfStock() async {
    _updateTask('Out of Stock details downloading...');
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
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (outOfStockListApi) async {
        final outOfStocks = outOfStockListApi.data ?? [];
        if (outOfStocks.isEmpty) {
          _isOutOfStockDownloaded = true;
          _completedTablesCount++; // Priority 4: Track completed tables
          // Fire-and-forget sync time write (matching KMP pattern)
          _syncTimeRepository.addSyncTime(
            tableName: 'OutOfStockMaster',
            updateDate: outOfStockListApi.updatedDate,
          ).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
              (_) {},
            );
          });
          _outOfStockPart = 0;
          _startSyncDatabase();
        } else {
          // Fire-and-forget DB write (matching KMP pattern)
          _outOfStockRepository.addOutOfStockMasters(outOfStocks).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add out of stock masters: ${failure.message}'),
              (_) {},
            );
          });
          _outOfStockPart++;
          _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadOutOfStockSub() async {
    _updateTask('Out of Stock details downloading...');
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
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (outOfStockSubListApi) async {
        final outOfStockSubs = outOfStockSubListApi.data ?? [];
        if (outOfStockSubs.isEmpty) {
          _isOutOfStockSubDownloaded = true;
          _completedTablesCount++; // Priority 4: Track completed tables
          // Fire-and-forget sync time write (matching KMP pattern)
          _syncTimeRepository.addSyncTime(
            tableName: 'OutOfStockProducts',
            updateDate: outOfStockSubListApi.updatedDate,
          ).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
              (_) {},
            );
          });
          _outOfStockSubPart = 0;
          _startSyncDatabase();
        } else {
          // Fire-and-forget DB write (matching KMP pattern)
          _outOfStockRepository.addOutOfStockProducts(outOfStockSubs).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add out of stock products: ${failure.message}'),
              (_) {},
            );
          });
          _outOfStockSubPart++;
          _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadCustomers() async {
    _updateTask('Customer details downloading...');
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
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (customerListApi) async {
        final customers = customerListApi.data ?? [];
        if (customers.isEmpty) {
          _isCustomerDownloaded = true;
          _completedTablesCount++; // Priority 4: Track completed tables
          // Fire-and-forget sync time write (matching KMP pattern)
          _syncTimeRepository.addSyncTime(
            tableName: 'Customers',
            updateDate: customerListApi.updatedDate,
          ).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
              (_) {},
            );
          });
          _customerPart = 0;
          _startSyncDatabase();
        } else {
          // Fire-and-forget DB write (matching KMP pattern)
          _customersRepository.addCustomers(customers).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add customers: ${failure.message}'),
              (_) {},
            );
          });
          _customerPart++;
          _startSyncDatabase();
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
    void Function()? finished, // Callback for retry mode (doesn't continue sync chain)
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
          _failedSyncRepository.addFailedSync(
            tableId: 14, // NotificationId.USER = 14
            dataId: id,
          ).then((_) {
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
            _syncTimeRepository.addSyncTime(
              tableName: 'Users',
              updateDate: userListApi.updatedDate,
            ).then((result) {
              result.fold(
                (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
                (_) {},
              );
            });
            _userPart = 0;
            _startSyncDatabase();
          } else {
            // Fire-and-forget DB write (matching KMP pattern)
            _usersRepository.addUsers(users).then((result) {
              result.fold(
                (failure) => developer.log('SyncProvider: Failed to add users: ${failure.message}'),
                (_) {},
              );
            });
            _userPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode
          if (users.isNotEmpty) {
            // Fire-and-forget DB write (matching KMP pattern)
            _usersRepository.addUsers(users).then((result) {
              result.fold(
                (failure) => developer.log('SyncProvider: Failed to add users: ${failure.message}'),
                (_) {},
              );
            });
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
    void Function()? finished, // Callback for retry mode (doesn't continue sync chain)
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
          _failedSyncRepository.addFailedSync(
            tableId: 15, // NotificationId.SALESMAN = 15
            dataId: id,
          ).then((_) {
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
        final salesmen = data?.map((e) => SalesMan.fromMapServerData(e as Map<String, dynamic>)).toList() ?? [];
        
        if (id == -1) {
          // Full sync mode (matches KMP lines 836-845)
          if (salesmen.isEmpty) {
            _isSalesmanDownloaded = true;
            _completedTablesCount++; // Priority 4: Track completed tables
            // Fire-and-forget sync time write (matching KMP pattern)
            _syncTimeRepository.addSyncTime(
              tableName: 'SalesMan',
              updateDate: updatedDate,
            ).then((result) {
              result.fold(
                (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
                (_) {},
              );
            });
            _salesmanPart = 0;
            _startSyncDatabase();
          } else {
            // Fire-and-forget DB write (matching KMP pattern)
            _salesManRepository.addSalesMen(salesmen).then((result) {
              result.fold(
                (failure) => developer.log('SyncProvider: Failed to add salesmen: ${failure.message}'),
                (_) {},
              );
            });
            _salesmanPart++;
            _startSyncDatabase();
          }
        } else {
          // Single record retry mode (matches KMP lines 846-849)
          if (salesmen.isNotEmpty) {
            // Fire-and-forget DB write (matching KMP pattern)
            _salesManRepository.addSalesMen(salesmen).then((result) {
              result.fold(
                (failure) => developer.log('SyncProvider: Failed to add salesmen: ${failure.message}'),
                (_) {},
              );
            });
          }
          if (failedId != -1) {
            await _failedSyncRepository.deleteFailedSync(failedId);
          }
          if (finished != null) finished();
        }
      },
    );
  }

  Future<void> _downloadSuppliers() async {
    _updateTask('Supplier details downloading...');
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
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (response) async {
        final data = response['data'] as List<dynamic>?;
        final updatedDate = response['updated_date'] as String? ?? '';
        final suppliers = data?.map((e) => Supplier.fromMap(e as Map<String, dynamic>)).toList() ?? [];
        
        if (suppliers.isEmpty) {
          _isSupplierDownloaded = true;
          _completedTablesCount++; // Priority 4: Track completed tables
          // Fire-and-forget sync time write (matching KMP pattern)
          _syncTimeRepository.addSyncTime(
            tableName: 'Suppliers',
            updateDate: updatedDate,
          ).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
              (_) {},
            );
          });
          _supplierPart = 0;
          _startSyncDatabase();
        } else {
          // Fire-and-forget DB write (matching KMP pattern)
          _suppliersRepository.addSuppliers(suppliers).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add suppliers: ${failure.message}'),
              (_) {},
            );
          });
          _supplierPart++;
          _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadRoutes() async {
    _updateTask('Route details downloading...');
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
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (routeListApi) async {
        final routes = routeListApi.data ?? [];
        if (routes.isEmpty) {
          _isRoutesDownloaded = true;
          _completedTablesCount++; // Priority 4: Track completed tables
          // Fire-and-forget sync time write (matching KMP pattern)
          _syncTimeRepository.addSyncTime(
            tableName: 'Routes',
            updateDate: routeListApi.updatedDate,
          ).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
              (_) {},
            );
          });
          _routesPart = 0;
          _startSyncDatabase();
        } else {
          // Fire-and-forget DB write (matching KMP pattern)
          _routesRepository.addRoutes(routes).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add routes: ${failure.message}'),
              (_) {},
            );
          });
          _routesPart++;
          _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadUnits() async {
    _updateTask('Units details downloading...');
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
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (unitListApi) async {
        final units = unitListApi.data ?? [];
        if (units.isEmpty) {
          _isUnitsDownloaded = true;
          _completedTablesCount++; // Priority 4: Track completed tables
          // Fire-and-forget sync time write (matching KMP pattern)
          _syncTimeRepository.addSyncTime(
            tableName: 'Units',
            updateDate: unitListApi.updatedDate,
          ).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
              (_) {},
            );
          });
          _unitsPart = 0;
          _startSyncDatabase();
        } else {
          // Fire-and-forget DB write (matching KMP pattern)
          _unitsRepository.addUnits(units).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add units: ${failure.message}'),
              (_) {},
            );
          });
          _unitsPart++;
          _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadUserCategories() async {
    _updateTask('User Category details downloading...');
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
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (response) async {
        final data = response['data'] as List<dynamic>?;
        final updatedDate = response['updated_date'] as String? ?? '';
        final userCategories = data?.map((e) => UserCategory.fromMapServerData(e as Map<String, dynamic>)).toList() ?? [];
        
        if (userCategories.isEmpty) {
          _isUserCategoryDownloaded = true;
          _completedTablesCount++; // Priority 4: Track completed tables
          // Fire-and-forget sync time write (matching KMP pattern)
          _syncTimeRepository.addSyncTime(
            tableName: 'UsersCategory',
            updateDate: updatedDate,
          ).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
              (_) {},
            );
          });
          _userCategoryPart = 0;
          _startSyncDatabase();
        } else {
          // Fire-and-forget DB write (matching KMP pattern)
          _userCategoryRepository.addUserCategories(userCategories).then((result) {
            result.fold(
              (failure) => developer.log('SyncProvider: Failed to add user categories: ${failure.message}'),
              (_) {},
            );
          });
          _userCategoryPart++;
          _startSyncDatabase();
        }
      },
    );
  }

  /// Retry sync for failed item based on tableId
  /// Converted from KMP's download function (lines 1262-1295)
  Future<void> _syncFailedItem(FailedSync failedSync) async {
    final failedId = failedSync.id;
    final tableId = failedSync.tableId;
    final dataId = failedSync.dataId;

    // Route to appropriate download method based on tableId (matches KMP's when expression)
    switch (tableId) {
      case 15: // NotificationId.SALESMAN = 15 (matches KMP line 1282)
        await _downloadSalesmen(
          id: dataId,
          failedId: failedId,
          finished: () {}, // Retry mode doesn't continue sync chain
        );
        break;
      // TODO: Add other table types as needed (Product, Order, etc.)
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
    await _downloadProducts(id: id);
  }

  /// Download single car brand by ID
  /// TODO: Update _downloadCarBrand to support id parameter
  Future<void> downloadCarBrand({required int id}) async {
    developer.log('SyncProvider: downloadCarBrand called with id: $id (TODO: implement)');
    // await _downloadCarBrand(id: id);
  }

  /// Download single car name by ID
  /// TODO: Update _downloadCarName to support id parameter
  Future<void> downloadCarName({required int id}) async {
    developer.log('SyncProvider: downloadCarName called with id: $id (TODO: implement)');
    // await _downloadCarName(id: id);
  }

  /// Download single car model by ID
  /// TODO: Update _downloadCarModel to support id parameter
  Future<void> downloadCarModel({required int id}) async {
    developer.log('SyncProvider: downloadCarModel called with id: $id (TODO: implement)');
    // await _downloadCarModel(id: id);
  }

  /// Download single car version by ID
  /// TODO: Update _downloadCarVersion to support id parameter
  Future<void> downloadCarVersion({required int id}) async {
    developer.log('SyncProvider: downloadCarVersion called with id: $id (TODO: implement)');
    // await _downloadCarVersion(id: id);
  }

  /// Download single category by ID
  /// ✅ Already implemented - _downloadCategory supports id parameter
  Future<void> downloadCategory({required int id}) async {
    await _downloadCategory(id: id);
  }

  /// Download single sub-category by ID
  /// TODO: Update _downloadSubCategory to support id parameter
  Future<void> downloadSubCategory({required int id}) async {
    developer.log('SyncProvider: downloadSubCategory called with id: $id (TODO: implement)');
    // await _downloadSubCategory(id: id);
  }

  /// Download single order by ID
  /// TODO: Update _downloadOrders to support id parameter
  Future<void> downloadOrder({required int id}) async {
    developer.log('SyncProvider: downloadOrder called with id: $id (TODO: implement)');
    // await _downloadOrders(id: id);
  }

  /// Download single order sub by ID
  /// TODO: Update _downloadOrderSubs to support id parameter
  Future<void> downloadOrderSub({required int id}) async {
    developer.log('SyncProvider: downloadOrderSub called with id: $id (TODO: implement)');
    // await _downloadOrderSubs(id: id);
  }

  /// Download single order sub suggestion by ID
  /// TODO: Update _downloadOrderSubSuggestions to support id parameter
  Future<void> downloadOrderSubSuggestion({required int id}) async {
    developer.log('SyncProvider: downloadOrderSubSuggestion called with id: $id (TODO: implement)');
    // await _downloadOrderSubSuggestions(id: id);
  }

  /// Download single out of stock master by ID
  /// TODO: Update _downloadOutOfStock to support id parameter
  Future<void> downloadOutOfStock({required int id}) async {
    developer.log('SyncProvider: downloadOutOfStock called with id: $id (TODO: implement)');
    // await _downloadOutOfStock(id: id);
  }

  /// Download single out of stock sub by ID
  /// TODO: Update _downloadOutOfStockSub to support id parameter
  Future<void> downloadOutOfStockSub({required int id}) async {
    developer.log('SyncProvider: downloadOutOfStockSub called with id: $id (TODO: implement)');
    // await _downloadOutOfStockSub(id: id);
  }

  /// Download single customer by ID
  /// TODO: Update _downloadCustomers to support id parameter
  Future<void> downloadCustomer({required int id}) async {
    developer.log('SyncProvider: downloadCustomer called with id: $id (TODO: implement)');
    // await _downloadCustomers(id: id);
  }

  /// Download single user by ID
  /// ✅ Already implemented - _downloadUsers supports id parameter
  Future<void> downloadUser({required int id}) async {
    await _downloadUsers(id: id);
  }

  /// Download single salesman by ID
  /// ✅ Already implemented - _downloadSalesmen supports id parameter
  Future<void> downloadSalesman({required int id}) async {
    await _downloadSalesmen(id: id);
  }

  /// Download single supplier by ID
  /// TODO: Update _downloadSuppliers to support id parameter
  Future<void> downloadSupplier({required int id}) async {
    developer.log('SyncProvider: downloadSupplier called with id: $id (TODO: implement)');
    // await _downloadSuppliers(id: id);
  }

  /// Download single route by ID
  /// TODO: Update _downloadRoutes to support id parameter
  Future<void> downloadRoutes({required int id}) async {
    developer.log('SyncProvider: downloadRoutes called with id: $id (TODO: implement)');
    // await _downloadRoutes(id: id);
  }

  /// Download single unit by ID
  /// TODO: Update _downloadUnits to support id parameter
  Future<void> downloadUnits({required int id}) async {
    developer.log('SyncProvider: downloadUnits called with id: $id (TODO: implement)');
    // await _downloadUnits(id: id);
  }

  /// Download single product unit by ID
  /// TODO: Implement _downloadProductUnits method
  Future<void> downloadProductUnits({required int id}) async {
    developer.log('SyncProvider: downloadProductUnits called with id: $id (TODO: implement)');
  }

  /// Download single product car by ID
  /// TODO: Implement _downloadProductCars method
  Future<void> downloadProductCar({required int id}) async {
    developer.log('SyncProvider: downloadProductCar called with id: $id (TODO: implement)');
  }

  /// Update store keeper (special notification type)
  Future<void> updateStoreKeeper({required int id}) async {
    // TODO: Implement updateStoreKeeper method
    developer.log('SyncProvider: updateStoreKeeper called with id: $id (TODO: implement)');
  }

  /// Logout user (special notification type)
  Future<void> logout() async {
    // TODO: Implement logout logic
    NotificationManager().triggerLogout();
    developer.log('SyncProvider: logout called (TODO: implement full logout)');
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /// Pre-fetch all sync times at start (Solution 3: Performance optimization)
  /// This eliminates hundreds of redundant DB queries during sync
  /// Converted from KMP's pattern where sync time is retrieved once per table
  Future<void> _prefetchAllSyncTimes() async {
    developer.log('SyncProvider: _prefetchAllSyncTimes() - Pre-fetching all sync times');
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
    developer.log('SyncProvider: _prefetchAllSyncTimes() - Completed, cached ${_syncTimeCache.length} sync times');
  }

  /// Get sync time for current table (uses cache after pre-fetch)
  /// Matches KMP's getSyncTimeParams but uses pre-fetched cache
  String _getSyncTimeForTable(String tableName) {
    // Return cached sync time (pre-fetched at start)
    final cachedTime = _syncTimeCache[tableName] ?? '';
    if (cachedTime.isEmpty) {
      developer.log('SyncProvider: WARNING - No cached sync time for $tableName, using empty string');
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
    } else if (!_isOrderSubSuggestionDownloaded && _orderSubSuggestionPart > 0) {
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
    } else if (!_isUserCategoryDownloaded && _userCategoryPart > 0) {
      currentTableProgress = (_userCategoryPart * 0.1).clamp(0.0, 0.95);
    }
    
    // Calculate total progress: completed tables + partial progress for current table
    _progress = (_completedTablesCount + currentTableProgress) / totalTables;
    developer.log('SyncProvider: _updateProgress() - Completed: $_completedTablesCount, Current table progress: ${(currentTableProgress * 100).toStringAsFixed(1)}%, Total: ${(_progress * 100).toStringAsFixed(1)}%');
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
    _userCategoryPart = 0;
  }

  /// Initialize cached user data (call once at start of sync)
  /// Matching KMP pattern where userType/userId are class properties (lines 76-77)
  Future<void> _initializeUserData() async {
    _cachedUserType = await StorageHelper.getUserType();
    _cachedUserId = await StorageHelper.getUserId();
    developer.log('SyncProvider: User data cached - userType: $_cachedUserType, userId: $_cachedUserId');
  }
}

