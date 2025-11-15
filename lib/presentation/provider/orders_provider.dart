import 'package:flutter/foundation.dart';
import '../../repositories/orders/orders_repository.dart';
import '../../repositories/routes/routes_repository.dart';
import '../../repositories/packed_subs/packed_subs_repository.dart';
import '../../models/order_api.dart';
import '../../models/master_data_api.dart';
import '../../utils/storage_helper.dart';
import 'package:intl/intl.dart';

/// Orders Provider
/// Manages order-related state and operations
/// Converted from KMP's OrderViewModel.kt
class OrdersProvider extends ChangeNotifier {
  final OrdersRepository _ordersRepository;
  final RoutesRepository _routesRepository;
  final PackedSubsRepository _packedSubsRepository;

  OrdersProvider({
    required OrdersRepository ordersRepository,
    required RoutesRepository routesRepository,
    required PackedSubsRepository packedSubsRepository,
  })  : _ordersRepository = ordersRepository,
        _routesRepository = routesRepository,
        _packedSubsRepository = packedSubsRepository;

  // ============================================================================
  // State Variables
  // ============================================================================

  List<Order> _orderList = [];
  List<Order> get orderList => _orderList;

  Order? _currentOrder;
  Order? get currentOrder => _currentOrder;

  List<OrderSub> _orderSubs = [];
  List<OrderSub> get orderSubs => _orderSubs;

  List<Route> _routeList = [];
  List<Route> get routeList => _routeList;

  String _searchKey = '';
  String get searchKey => _searchKey;

  String _date = '';
  String get date => _date;

  int _dateFilterIndex = 1; // 0=All, 1=Today, 2=Yesterday, 3=Custom
  int get dateFilterIndex => _dateFilterIndex;

  int _routeId = -1;
  int get routeId => _routeId;
  String _routeSt = 'All Routes';
  String get routeSt => _routeSt;

  int _customerId = -1;
  int get customerId => _customerId;
  String _customerName = 'Select customer';
  String get customerName => _customerName;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ============================================================================
  // Public Methods
  // ============================================================================

  /// Initialize with current date
  void initialize() {
    _date = _getDBFormatDate();
    notifyListeners();
  }

  /// Set search key
  void setSearchKey(String searchKey) {
    _searchKey = searchKey;
    notifyListeners();
  }

  /// Set date filter
  void setDate(String date) {
    _date = date;
    notifyListeners();
  }

  /// Set date filter index
  void setDateFilterIndex(int index) {
    _dateFilterIndex = index;
    notifyListeners();
  }

  /// Set route filter
  void setRouteFilter(int routeId, String routeName) {
    _routeId = routeId;
    _routeSt = routeName;
    notifyListeners();
  }

  /// Set customer
  void setCustomer(int customerId, String customerName) {
    _customerId = customerId;
    _customerName = customerName;
    notifyListeners();
  }

  /// Load all routes
  Future<void> loadRoutes() async {
    final result = await _routesRepository.getAllRoutes();

    result.fold(
      (failure) => _setError(failure.message),
      (routes) {
        _routeList = routes;
        notifyListeners();
      },
    );
  }

  /// Load orders with filters
  Future<void> loadOrders() async {
    _setLoading(true);
    _clearError();

    final userId = await StorageHelper.getUserId();
    final result = await _ordersRepository.getAllOrders(
      searchKey: _searchKey,
      routeId: _routeId == -1 ? -1 : _routeId,
      date: _date,
      salesmanId: userId,
    );

    result.fold(
      (failure) => _setError(failure.message),
      (orders) {
        _orderList = orders;
        notifyListeners();
      },
    );

    _setLoading(false);
  }

  /// Load order by ID
  Future<void> loadOrderById(int orderId) async {
    _setLoading(true);
    _clearError();

    final result = await _ordersRepository.getOrderById(orderId);

    result.fold(
      (failure) => _setError(failure.message),
      (order) {
        _currentOrder = order;
        if (order != null) {
          loadOrderSubs(order.id);
        }
        notifyListeners();
      },
    );

    _setLoading(false);
  }

  /// Load order subs by order ID
  Future<void> loadOrderSubs(int orderId) async {
    final result = await _ordersRepository.getOrderSubsByOrderId(orderId);

    result.fold(
      (failure) => _setError(failure.message),
      (orderSubs) {
        _orderSubs = orderSubs;
        notifyListeners();
      },
    );
  }

  /// Create order via API and update local DB
  Future<bool> createOrder(Order order) async {
    _setLoading(true);
    _clearError();

    final result = await _ordersRepository.createOrder(order);

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (createdOrder) {
        success = true;
        _currentOrder = createdOrder;
        loadOrders(); // Reload list
      },
    );

    _setLoading(false);
    return success;
  }

  /// Update order via API and update local DB
  Future<bool> updateOrder(Order order) async {
    _setLoading(true);
    _clearError();

    final result = await _ordersRepository.updateOrder(order);

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (updatedOrder) {
        success = true;
        _currentOrder = updatedOrder;
        loadOrders(); // Reload list
      },
    );

    _setLoading(false);
    return success;
  }

  /// Add order sub
  Future<bool> addOrderSub(OrderSub orderSub) async {
    _setLoading(true);
    _clearError();

    final result = await _ordersRepository.addOrderSub(orderSub);

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (_) {
        success = true;
        if (_currentOrder != null) {
          loadOrderSubs(_currentOrder!.id);
        }
      },
    );

    _setLoading(false);
    return success;
  }

  /// Update order sub
  Future<bool> updateOrderSub(OrderSub orderSub) async {
    _setLoading(true);
    _clearError();

    final result = await _ordersRepository.updateOrderSub(orderSub);

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (_) {
        success = true;
        if (_currentOrder != null) {
          loadOrderSubs(_currentOrder!.id);
        }
      },
    );

    _setLoading(false);
    return success;
  }

  /// Delete order sub
  Future<bool> deleteOrderSub(int orderSubId) async {
    _setLoading(true);
    _clearError();

    final result = await _ordersRepository.deleteOrderSub(orderSubId);

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (_) {
        success = true;
        if (_currentOrder != null) {
          loadOrderSubs(_currentOrder!.id);
        }
      },
    );

    _setLoading(false);
    return success;
  }

  /// Add packed sub
  Future<bool> addPackedSub({
    required int orderSubId,
    required double quantity,
  }) async {
    final result = await _packedSubsRepository.addPackedSub(
      orderSubId: orderSubId,
      quantity: quantity,
    );

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (_) => success = true,
    );

    return success;
  }

  /// Delete packed sub
  Future<bool> deletePackedSub(int orderSubId) async {
    final result = await _packedSubsRepository.deletePackedSub(orderSubId);

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (_) => success = true,
    );

    return success;
  }

  /// Clear current order
  void clearCurrentOrder() {
    _currentOrder = null;
    _orderSubs = [];
    notifyListeners();
  }

  // ============================================================================
  // Private Helper Methods
  // ============================================================================

  String _getDBFormatDate() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}

