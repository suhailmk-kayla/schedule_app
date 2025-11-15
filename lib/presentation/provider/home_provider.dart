import 'package:flutter/material.dart';
import 'package:schedule_frontend_flutter/utils/asset_images.dart';
import '../../repositories/orders/orders_repository.dart';
import '../../repositories/out_of_stock/out_of_stock_repository.dart';
import '../../utils/storage_helper.dart';

/// Home Provider
/// Manages home screen state and menu items
/// Converted from KMP's Home.kt
class HomeProvider extends ChangeNotifier {
  final OrdersRepository _ordersRepository;
  final OutOfStockRepository _outOfStockRepository;

  HomeProvider({
    required OrdersRepository ordersRepository,
    required OutOfStockRepository outOfStockRepository,
  })  : _ordersRepository = ordersRepository,
        _outOfStockRepository = outOfStockRepository;

  // ============================================================================
  // State Variables
  // ============================================================================

  int _newOrdersCount = 0;
  int get newOrdersCount => _newOrdersCount;

  int _newOutOfStockCount = 0;
  int get newOutOfStockCount => _newOutOfStockCount;

  List<MenuItem> _menuItems = [];
  List<MenuItem> get menuItems => _menuItems;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ============================================================================
  // Public Methods
  // ============================================================================

  /// Load unviewed counts and initialize menu items
  /// Converted from KMP's getUnViewedCount
  Future<void> loadUnviewedCounts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get unviewed order count
      final orderCountResult = await _ordersRepository.getUnviewedOrderCount();
      orderCountResult.fold(
        (failure) {
          _errorMessage = failure.message;
          _newOrdersCount = 0;
        },
        (count) {
          _newOrdersCount = count;
        },
      );

      // Get unviewed out of stock count based on user type
      final userType = await StorageHelper.getUserType();
      final outOfStockCountResult = userType == 1 // Admin
          ? await _outOfStockRepository.getUnviewedMasterCount()
          : await _outOfStockRepository.getUnviewedProductCount();

      outOfStockCountResult.fold(
        (failure) {
          _errorMessage = failure.message;
          _newOutOfStockCount = 0;
        },
        (count) {
          _newOutOfStockCount = count;
        },
      );

      // Initialize menu items based on user type
      _menuItems = _initMenu(_newOrdersCount, _newOutOfStockCount, userType);
    } catch (e) {
      _errorMessage = 'Failed to load counts: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh counts (called when notifications arrive)
  Future<void> refreshCounts() async {
    await loadUnviewedCounts();
  }

  // ============================================================================
  // Private Methods
  // ============================================================================

  /// Initialize menu items based on user type
  /// Converted from KMP's initMenu function
  List<MenuItem> _initMenu(int newOrders, int newOutOfStock, int userType) {
    final menuList = <MenuItem>[];

    // Orders - All except Supplier (userType != 4)
    if (userType != 4) {
      menuList.add(MenuItem(
        imagePath: AssetImages.imagesOrder,
        type: MenuType.orders,
        title: 'Orders',
        icon: Icons.shopping_cart,
        count: newOrders,
      ));
    }

    // Out of Stock - Admin (1), Storekeeper (2), Supplier (4)
    if (userType == 4 || userType == 1 || userType == 2) {
      final outOfStockText = userType == 4 ? 'Orders' : 'Out of Stock';
      menuList.add(MenuItem(
        imagePath: AssetImages.imagesOutofstock,
        type: MenuType.outOfStock,
        title: outOfStockText,
        icon: Icons.inventory_2,
        count: newOutOfStock,
      ));
    }

    // Products - Admin (1), Salesman (3)
    if (userType == 1 || userType == 3) {
      menuList.add(MenuItem(
        imagePath: AssetImages.imagesProducts,
        type: MenuType.products,
        title: 'Products',
        icon: Icons.inventory,
        count: 0,
      ));
    }

    // Customers - Admin (1), Salesman (3)
    if (userType == 1 || userType == 3) {
      menuList.add(MenuItem(
        imagePath: AssetImages.imagesCustomer,
        type: MenuType.customers,
        title: 'Customers',
        icon: Icons.people,
        count: 0,
      ));
    }

    // Suppliers - Admin only (1)
    if (userType == 1) {
      menuList.add(MenuItem(
        imagePath: AssetImages.imagesSupplier,
        type: MenuType.suppliers,
        title: 'Suppliers',
        icon: Icons.local_shipping,
        count: 0,
      ));
    }

    // Users - Admin only (1)
    if (userType == 1) {
      menuList.add(MenuItem(
        imagePath: AssetImages.imagesUsers,
        type: MenuType.users,
        title: 'Users',
        icon: Icons.person,
        count: 0,
      ));
    }

    // Salesman - Admin only (1)
    if (userType == 1) {
      menuList.add(MenuItem(
        imagePath: AssetImages.imagesSalesman,
        type: MenuType.salesman,
        title: 'Sales Man',
        icon: Icons.person_outline,
        count: 0,
      ));
    }

    // Routes - Admin only (1)
    if (userType == 1) {
      menuList.add(MenuItem(
        imagePath: AssetImages.imagesRoute,
        type: MenuType.routes,
        title: 'Routes',
        icon: Icons.route,
        count: 0,
      ));
    }

    // Product Settings - Admin only (1)
    if (userType == 1) {
      menuList.add(MenuItem(
        imagePath: AssetImages.imagesProductSetting,
        type: MenuType.productSettings,
        title: 'Product Settings',
        icon: Icons.settings,
        count: 0,
      ));
    }

    return menuList;
  }
}

/// Menu Item Model
/// Converted from KMP's MenuItems data class
class MenuItem {
  final MenuType type;
  final String title;
  final IconData icon;
  final int count;
  final String? imagePath;

  const MenuItem({
    required this.type,
    required this.title,
    required this.icon,
    this.count = 0,
    this.imagePath,
  });
}

/// Menu Type Enum
/// Converted from KMP's DashMenu enum
enum MenuType {
  orders,
  outOfStock,
  products,
  customers,
  suppliers,
  users,
  salesman,
  routes,
  productSettings,
  units,
  category,
  subCategory,
  cars,
  syncDetails,
  settings,
  about,
}

