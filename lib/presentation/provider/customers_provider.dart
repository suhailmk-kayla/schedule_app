import 'package:flutter/foundation.dart';
import '../../repositories/customers/customers_repository.dart';
import '../../repositories/routes/routes_repository.dart';
import '../../repositories/salesman/salesman_repository.dart';
import '../../repositories/orders/orders_repository.dart';
import '../../models/master_data_api.dart';
import '../../models/order_api.dart';
import '../../models/salesman_model.dart';
import '../../utils/storage_helper.dart';
import 'package:intl/intl.dart';

/// Customers Provider
/// Manages customer-related state and operations
/// Converted from KMP's CustomersViewModel.kt
class CustomersProvider extends ChangeNotifier {
  final CustomersRepository _customersRepository;
  final RoutesRepository _routesRepository;
  final SalesManRepository _salesManRepository;
  final OrdersRepository _ordersRepository;

  CustomersProvider({
    required CustomersRepository customersRepository,
    required RoutesRepository routesRepository,
    required SalesManRepository salesManRepository,
    required OrdersRepository ordersRepository,
  })  : _customersRepository = customersRepository,
        _routesRepository = routesRepository,
        _salesManRepository = salesManRepository,
        _ordersRepository = ordersRepository;

  // ============================================================================
  // State Variables
  // ============================================================================

  List<Customer> _customers = [];
  List<Customer> get customers => _customers;

  List<Route> _routeList = [];
  List<Route> get routeList => _routeList;

  List<SalesMan> _salesmanList = [];
  List<SalesMan> get salesmanList => _salesmanList;

  String _searchKey = '';
  String get searchKey => _searchKey;

  int _routeId = -1;
  int get routeId => _routeId;
  String _routeSt = 'All Routes';
  String get routeSt => _routeSt;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ============================================================================
  // Public Methods
  // ============================================================================

  /// Set search key
  void setSearchKey(String searchKey) {
    _searchKey = searchKey;
    notifyListeners();
  }

  /// Set route filter
  void setRouteFilter(int routeId, String routeName) {
    _routeId = routeId;
    _routeSt = routeName;
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

  /// Load all salesmen
  Future<void> loadSalesmen() async {
    final result = await _salesManRepository.getAllSalesMan(searchKey: '');

    result.fold(
      (failure) => _setError(failure.message),
      (salesmen) {
        _salesmanList = salesmen;
        notifyListeners();
      },
    );
  }

  /// Load customers with filters
  Future<void> loadCustomers() async {
    _setLoading(true);
    _clearError();

    final userType = await StorageHelper.getUserType();
    final result = await _customersRepository.getAllCustomers(
      searchKey: _searchKey,
      routeId: _routeId == -1 ? -1 : _routeId,
      forAdmin: userType == 1,
    );

    result.fold(
      (failure) => _setError(failure.message),
      (customers) {
        _customers = customers;
        notifyListeners();
      },
    );

    _setLoading(false);
  }

  /// Get customer by ID
  Future<Customer?> getCustomerById(int customerId) async {
    final result = await _customersRepository.getCustomerById(customerId);

    Customer? customer;
    result.fold(
      (failure) => _setError(failure.message),
      (c) => customer = c,
    );

    return customer;
  }

  /// Get or create order for customer
  Future<Order?> getOrderByCustomer(Customer customer) async {
    _setLoading(true);
    _clearError();

    final date = _getDBFormatDate();
    final result = await _ordersRepository.getOrdersByCustomer(
      customerId: customer.id,
      date: date,
    );

    Order? order;
    result.fold(
      (failure) => _setError(failure.message),
      (orders) {
        if (orders.isNotEmpty) {
          order = orders.first;
        }
      },
    );

    // If no order found, create a temp order
    if (order == null) {
      order = await _createTempOrder(customer);
    }

    _setLoading(false);
    return order;
  }

  /// Create customer via API and update local DB
  Future<bool> createCustomer({
    required String code,
    required String name,
    required String phone,
    required String address,
    required int routeId,
    required int salesmanId,
    required int rating,
  }) async {
    _setLoading(true);
    _clearError();

    // Check if code already exists
    final existResult = await _customersRepository.getCustomerByCode(code);
    bool exists = false;
    existResult.fold(
      (failure) => _setError(failure.message),
      (customers) => exists = customers.isNotEmpty,
    );

    if (exists) {
      _setError('Code already exists');
      _setLoading(false);
      return false;
    }

    // Create customer object
    final customer = Customer(
      id: 0,
      code: code,
      name: name,
      phoneNo: phone,
      address: address,
      routId: routeId,
      salesManId: salesmanId,
      rating: rating,
    );

    final result = await _customersRepository.createCustomer(customer);

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (createdCustomer) {
        success = true;
        loadCustomers(); // Reload list
      },
    );

    _setLoading(false);
    return success;
  }

  /// Update customer via API and update local DB
  Future<bool> updateCustomer({
    required int customerId,
    required String code,
    required String name,
    required String phone,
    required String address,
    required int routeId,
    required int salesmanId,
    required int rating,
  }) async {
    _setLoading(true);
    _clearError();

    // Check if code already exists (excluding current customer)
    final existResult = await _customersRepository.getCustomerByCodeWithId(
      code: code,
      customerId: customerId,
    );
    bool exists = false;
    existResult.fold(
      (failure) => _setError(failure.message),
      (customers) => exists = customers.isNotEmpty,
    );

    if (exists) {
      _setError('Code already exists');
      _setLoading(false);
      return false;
    }

    // Create customer object with updated data
    final customer = Customer(
      id: customerId,
      code: code,
      name: name,
      phoneNo: phone,
      address: address,
      routId: routeId,
      salesManId: salesmanId,
      rating: rating,
    );

    final result = await _customersRepository.updateCustomer(customer);

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (updatedCustomer) {
        success = true;
        loadCustomers(); // Reload list
      },
    );

    _setLoading(false);
    return success;
  }

  /// Update customer flag
  Future<bool> updateCustomerFlag({
    required int customerId,
    required int salesmanId,
    required int flag,
  }) async {
    _setLoading(true);
    _clearError();

    final result = await _customersRepository.updateCustomerFlag(
      customerId: customerId,
      flag: flag,
    );

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (_) {
        success = true;
        loadCustomers(); // Reload list
      },
    );

    _setLoading(false);
    return success;
  }

  /// Create route
  Future<bool> createRoute({
    required String name,
    required int salesmanId,
  }) async {
    _setLoading(true);
    _clearError();

    // Check if route name already exists
    final existResult = await _routesRepository.getRouteByName(name);
    bool exists = false;
    existResult.fold(
      (failure) => _setError(failure.message),
      (routes) => exists = routes.isNotEmpty,
    );

    if (exists) {
      _setError('Route name already exists');
      _setLoading(false);
      return false;
    }

    final result = await _routesRepository.createRoute(
      name: name,
      code: '', // Empty code as per KMP pattern
      salesmanId: salesmanId,
    );

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (route) {
        success = true;
        loadRoutes(); // Reload list
      },
    );

    _setLoading(false);
    return success;
  }

  // ============================================================================
  // Private Helper Methods
  // ============================================================================

  /// Create temporary order for customer
  Future<Order?> _createTempOrder(Customer customer) async {
    final userId = await StorageHelper.getUserId();
    final lastResult = await _ordersRepository.getLastOrderEntry();
    int orderId = 1;

    lastResult.fold(
      (failure) => null,
      (order) {
        if (order != null) {
          orderId = order.orderInvNo + 1;
        }
      },
    );

    final now = _getDBFormatDateTime();
    final tempOrder = Order(
      id: 0,
      uuid: '',
      orderInvNo: orderId,
      orderCustId: customer.id,
      orderCustName: customer.name,
      orderSalesmanId: userId,
      orderStockKeeperId: -1,
      orderBillerId: -1,
      orderCheckerId: -1,
      orderDateTime: now,
      orderNote: '',
      orderTotal: 0.0,
      orderFreightCharge: 0.0,
      orderApproveFlag: 0,
      createdAt: now,
      updatedAt: now,
      orderFlag: 2, // Temp/Draft flag
    );

    final result = await _ordersRepository.addOrder(tempOrder);
    Order? order;
    result.fold(
      (failure) => _setError(failure.message),
      (_) => order = tempOrder,
    );

    return order;
  }

  String _getDBFormatDate() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  String _getDBFormatDateTime() {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
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

