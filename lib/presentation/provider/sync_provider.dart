import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
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
        _failedSyncRepository = failedSyncRepository;

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
      final userType = await StorageHelper.getUserType();
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

  Future<void> _downloadProducts() async {
    developer.log('SyncProvider: _downloadProducts() - Part: $_productPart');
    _updateTask('Product details downloading...');
    
    try {
      // Get sync time, user type, and user id (matching KMP's params() function)
      final updateDate = await _getSyncTimeForTable(_syncingTable);
      final userType = await StorageHelper.getUserType();
      final userId = await StorageHelper.getUserId();
      
      developer.log('SyncProvider: _downloadProducts() - part_no=$_productPart, user_type=$userType, user_id=$userId, update_date=$updateDate');
      
      final result = await _productsRepository.syncProductsFromApi(
        partNo: _productPart,
        limit: _limit,
        userType: userType,
        userId: userId,
        updateDate: updateDate,
      );

      result.fold(
        (failure) {
          developer.log('SyncProvider: _downloadProducts() - Error: ${failure.message}');
          _updateError(failure.message, true);
          _isSyncing = false;
          notifyListeners();
        },
        (productListApi) async {
          final products = productListApi.data ?? [];
          developer.log('SyncProvider: _downloadProducts() - Received ${products.length} products');
          
          if (products.isEmpty) {
            developer.log('SyncProvider: _downloadProducts() - No more products, marking as downloaded');
            _isProductDownloaded = true;
            final syncTimeResult = await _syncTimeRepository.addSyncTime(
              tableName: 'Product',
              updateDate: productListApi.updated_date,
            );
            syncTimeResult.fold(
              (failure) => developer.log('SyncProvider: Failed to add sync time: ${failure.message}'),
              (_) => developer.log('SyncProvider: Sync time added for Product'),
            );
            _productPart = 0;
            _updateProgress();
            // Proceed immediately to next table
            await _startSyncDatabase();
          } else {
            developer.log('SyncProvider: _downloadProducts() - Adding ${products.length} products to DB');
            final addResult = await _productsRepository.addProducts(products);
            addResult.fold(
              (failure) {
                developer.log('SyncProvider: Failed to add products to DB: ${failure.message}');
                _updateError('Failed to save products: ${failure.message}', true);
                _isSyncing = false;
                notifyListeners();
              },
              (_) async {
                developer.log('SyncProvider: Products added to DB successfully');
                _productPart++;
                _updateProgress();
                // Proceed immediately to next batch
                await _startSyncDatabase();
              },
            );
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
      final updateDate = await _getSyncTimeForTable(_syncingTable);
      final userType = await StorageHelper.getUserType();
      final userId = await StorageHelper.getUserId();
      
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
            await _syncTimeRepository.addSyncTime(
              tableName: 'CarBrand',
              updateDate: carBrandListApi.updatedDate,
            );
            _carBrandPart = 0;
            _updateProgress();
            await Future.delayed(const Duration(milliseconds: 100));
            await _startSyncDatabase();
          } else {
            final addResult = await _carBrandRepository.addCarBrands(brands);
            addResult.fold(
              (failure) {
                developer.log('SyncProvider: Failed to add brands to DB: ${failure.message}');
                _updateError('Failed to save brands: ${failure.message}', true);
                _isSyncing = false;
                notifyListeners();
              },
              (_) async {
                developer.log('SyncProvider: Brands added to DB successfully');
                _carBrandPart++;
                _updateProgress();
                await Future.delayed(const Duration(milliseconds: 100));
                await _startSyncDatabase();
              },
            );
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
    final updateDate = await _getSyncTimeForTable('CarName');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
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
          await _syncTimeRepository.addSyncTime(
            tableName: 'CarName',
            updateDate: carNameListApi.updatedDate,
          );
          _carNamePart = 0;
          await _startSyncDatabase();
        } else {
          await _carNameRepository.addCarNames(names);
          _carNamePart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadCarModel() async {
    _updateTask('Car details downloading...');
    final updateDate = await _getSyncTimeForTable('CarModel');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
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
          await _syncTimeRepository.addSyncTime(
            tableName: 'CarModel',
            updateDate: carModelListApi.updatedDate,
          );
          _carModelPart = 0;
          await _startSyncDatabase();
        } else {
          await _carModelRepository.addCarModels(models);
          _carModelPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadCarVersion() async {
    _updateTask('Car details downloading...');
    final updateDate = await _getSyncTimeForTable('CarVersion');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
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
          await _syncTimeRepository.addSyncTime(
            tableName: 'CarVersion',
            updateDate: carVersionListApi.updatedDate,
          );
          _carVersionPart = 0;
          await _startSyncDatabase();
        } else {
          await _carVersionRepository.addCarVersions(versions);
          _carVersionPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadCategory() async {
    _updateTask('Category downloading...');
    final updateDate = await _getSyncTimeForTable('Category');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
    final result = await _categoriesRepository.syncCategoriesFromApi(
      partNo: _categoryPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (categoryListApi) async {
        final categories = categoryListApi.data ?? [];
        if (categories.isEmpty) {
          _isCategoryDownloaded = true;
          await _syncTimeRepository.addSyncTime(
            tableName: 'Category',
            updateDate: categoryListApi.updatedDate,
          );
          _categoryPart = 0;
          await _startSyncDatabase();
        } else {
          await _categoriesRepository.addCategories(categories);
          _categoryPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadSubCategory() async {
    _updateTask('Sub-Category downloading...');
    final updateDate = await _getSyncTimeForTable('SubCategory');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
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
          await _syncTimeRepository.addSyncTime(
            tableName: 'SubCategory',
            updateDate: subCategoryListApi.updatedDate,
          );
          _subCategoryPart = 0;
          await _startSyncDatabase();
        } else {
          await _subCategoriesRepository.addSubCategories(subCategories);
          _subCategoryPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadOrders() async {
    _updateTask('Order details downloading...');
    final updateDate = await _getSyncTimeForTable('Orders');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
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
          await _syncTimeRepository.addSyncTime(
            tableName: 'Orders',
            updateDate: orderListApi.updatedDate,
          );
          _orderPart = 0;
          await _startSyncDatabase();
        } else {
          await _ordersRepository.addOrders(orders);
          _orderPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadOrderSubs() async {
    _updateTask('Order details downloading...');
    final updateDate = await _getSyncTimeForTable('OrderSub');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
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
          await _syncTimeRepository.addSyncTime(
            tableName: 'OrderSub',
            updateDate: orderSubListApi.updatedDate,
          );
          _orderSubPart = 0;
          await _startSyncDatabase();
        } else {
          await _ordersRepository.addOrderSubs(orderSubs);
          _orderSubPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadOrderSubSuggestions() async {
    _updateTask('Order details downloading...');
    final updateDate = await _getSyncTimeForTable('OrderSubSuggestion');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
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
          await _syncTimeRepository.addSyncTime(
            tableName: 'OrderSubSuggestions',
            updateDate: suggestionsListApi.updatedDate,
          );
          _orderSubSuggestionPart = 0;
          await _startSyncDatabase();
        } else {
          await _orderSubSuggestionsRepository.addSuggestions(suggestions);
          _orderSubSuggestionPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadOutOfStock() async {
    _updateTask('Out of Stock details downloading...');
    final updateDate = await _getSyncTimeForTable('OutOfStockMaster');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
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
          await _syncTimeRepository.addSyncTime(
            tableName: 'OutOfStockMaster',
            updateDate: outOfStockListApi.updatedDate,
          );
          _outOfStockPart = 0;
          await _startSyncDatabase();
        } else {
          await _outOfStockRepository.addOutOfStockMasters(outOfStocks);
          _outOfStockPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadOutOfStockSub() async {
    _updateTask('Out of Stock details downloading...');
    final updateDate = await _getSyncTimeForTable('OutOfStockProducts');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
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
          await _syncTimeRepository.addSyncTime(
            tableName: 'OutOfStockProducts',
            updateDate: outOfStockSubListApi.updatedDate,
          );
          _outOfStockSubPart = 0;
          await _startSyncDatabase();
        } else {
          await _outOfStockRepository.addOutOfStockProducts(outOfStockSubs);
          _outOfStockSubPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadCustomers() async {
    _updateTask('Customer details downloading...');
    final updateDate = await _getSyncTimeForTable('Customer');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
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
          await _syncTimeRepository.addSyncTime(
            tableName: 'Customers',
            updateDate: customerListApi.updatedDate,
          );
          _customerPart = 0;
          await _startSyncDatabase();
        } else {
          await _customersRepository.addCustomers(customers);
          _customerPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadUsers() async {
    _updateTask('Users details downloading...');
    final updateDate = await _getSyncTimeForTable('Users');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
    final result = await _usersRepository.syncUsersFromApi(
      partNo: _userPart,
      limit: _limit,
      userType: userType,
      userId: userId,
      updateDate: updateDate,
    );

    result.fold(
      (failure) => _updateError(failure.message, true),
      (userListApi) async {
        final users = userListApi.data ?? [];
        if (users.isEmpty) {
          _isUserDownloaded = true;
          await _syncTimeRepository.addSyncTime(
            tableName: 'Users',
            updateDate: userListApi.updatedDate,
          );
          _userPart = 0;
          await _startSyncDatabase();
        } else {
          await _usersRepository.addUsers(users);
          _userPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadSalesmen() async {
    _updateTask('Salesman details downloading...');
    final updateDate = await _getSyncTimeForTable('SalesMan');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
    final result = await _salesManRepository.syncSalesMenFromApi(
      partNo: _salesmanPart,
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
        final salesmen = data?.map((e) => SalesMan.fromMap(e as Map<String, dynamic>)).toList() ?? [];
        
        if (salesmen.isEmpty) {
          _isSalesmanDownloaded = true;
          await _syncTimeRepository.addSyncTime(
            tableName: 'SalesMan',
            updateDate: updatedDate,
          );
          _salesmanPart = 0;
          await _startSyncDatabase();
        } else {
          await _salesManRepository.addSalesMen(salesmen);
          _salesmanPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadSuppliers() async {
    _updateTask('Supplier details downloading...');
    final updateDate = await _getSyncTimeForTable('Supplier');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
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
          await _syncTimeRepository.addSyncTime(
            tableName: 'Suppliers',
            updateDate: updatedDate,
          );
          _supplierPart = 0;
          await _startSyncDatabase();
        } else {
          await _suppliersRepository.addSuppliers(suppliers);
          _supplierPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadRoutes() async {
    _updateTask('Route details downloading...');
    final updateDate = await _getSyncTimeForTable('Routes');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
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
          await _syncTimeRepository.addSyncTime(
            tableName: 'Routes',
            updateDate: routeListApi.updatedDate,
          );
          _routesPart = 0;
          await _startSyncDatabase();
        } else {
          await _routesRepository.addRoutes(routes);
          _routesPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadUnits() async {
    _updateTask('Units details downloading...');
    final updateDate = await _getSyncTimeForTable('Units');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
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
          await _syncTimeRepository.addSyncTime(
            tableName: 'Units',
            updateDate: unitListApi.updatedDate,
          );
          _unitsPart = 0;
          await _startSyncDatabase();
        } else {
          await _unitsRepository.addUnits(units);
          _unitsPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _downloadUserCategories() async {
    _updateTask('User Category details downloading...');
    final updateDate = await _getSyncTimeForTable('UsersCategory');
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
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
        final userCategories = data?.map((e) => UserCategory.fromMap(e as Map<String, dynamic>)).toList() ?? [];
        
        if (userCategories.isEmpty) {
          _isUserCategoryDownloaded = true;
          await _syncTimeRepository.addSyncTime(
            tableName: 'UsersCategory',
            updateDate: updatedDate,
          );
          _userCategoryPart = 0;
          await _startSyncDatabase();
        } else {
          await _userCategoryRepository.addUserCategories(userCategories);
          _userCategoryPart++;
          await _startSyncDatabase();
        }
      },
    );
  }

  Future<void> _syncFailedItem(FailedSync failedSync) async {
    // Retry sync for failed item based on tableId
    // This is a simplified version - in production, you'd handle each table type
    // For now, we'll just delete the failed sync after retry attempt
    await _failedSyncRepository.deleteFailedSync(failedSync.id);
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /// Get sync time for current table (matches KMP's getSyncTimeParams)
  Future<String> _getSyncTimeForTable(String tableName) async {
    final syncTimeResult = await _syncTimeRepository.getSyncTime(tableName);
    return syncTimeResult.fold(
      (_) => '',
      (syncTime) => syncTime?.updateDate ?? '',
    );
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

  void _updateProgress() {
    // Calculate progress based on completed tables + current table progress
    int completedTables = 0;
    int totalTables = 17; // Total number of tables to sync
    
    // Count completed tables
    if (_isProductDownloaded) completedTables++;
    if (_isCarBrandDownloaded) completedTables++;
    if (_isCarNameDownloaded) completedTables++;
    if (_isCarModelDownloaded) completedTables++;
    if (_isCarVersionDownloaded) completedTables++;
    if (_isCategoryDownloaded) completedTables++;
    if (_isSubCategoryDownloaded) completedTables++;
    if (_isOrderDownloaded) completedTables++;
    if (_isOrderSubDownloaded) completedTables++;
    if (_isOrderSubSuggestionDownloaded) completedTables++;
    if (_isOutOfStockDownloaded) completedTables++;
    if (_isOutOfStockSubDownloaded) completedTables++;
    if (_isCustomerDownloaded) completedTables++;
    if (_isUserDownloaded) completedTables++;
    if (_isSalesmanDownloaded) completedTables++;
    if (_isSupplierDownloaded) completedTables++;
    if (_isRoutesDownloaded) completedTables++;
    if (_isUnitsDownloaded) completedTables++;
    if (_isUserCategoryDownloaded) completedTables++;
    
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
    _progress = (completedTables + currentTableProgress) / totalTables;
    developer.log('SyncProvider: _updateProgress() - Completed: $completedTables, Current table progress: ${(currentTableProgress * 100).toStringAsFixed(1)}%, Total: ${(_progress * 100).toStringAsFixed(1)}%');
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
}

