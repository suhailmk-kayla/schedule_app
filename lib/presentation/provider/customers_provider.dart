import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import '../../repositories/customers/customers_repository.dart';
import '../../repositories/routes/routes_repository.dart';
import '../../repositories/salesman/salesman_repository.dart';
import '../../repositories/orders/orders_repository.dart';
import '../../models/master_data_api.dart';
import '../../models/order_api.dart';
import '../../models/salesman_model.dart';
import '../../models/push_data.dart';
import '../../utils/storage_helper.dart';
import '../../utils/push_notification_sender.dart';
import '../../utils/push_notification_builder.dart';
import '../../utils/notification_id.dart';
import 'package:intl/intl.dart';

/// Customers Provider
/// Manages customer-related state and operations
/// Converted from KMP's CustomersViewModel.kt
class CustomersProvider extends ChangeNotifier {
  final CustomersRepository _customersRepository;
  final RoutesRepository _routesRepository;
  final SalesManRepository _salesManRepository;
  final OrdersRepository _ordersRepository;
  final PushNotificationSender _pushNotificationSender;
  final PushNotificationBuilder _pushNotificationBuilder;

  CustomersProvider({
    required CustomersRepository customersRepository,
    required RoutesRepository routesRepository,
    required SalesManRepository salesManRepository,
    required OrdersRepository ordersRepository,
    required PushNotificationSender pushNotificationSender,
    required PushNotificationBuilder pushNotificationBuilder,
  })  : _customersRepository = customersRepository,
        _routesRepository = routesRepository,
        _salesManRepository = salesManRepository,
        _ordersRepository = ordersRepository,
        _pushNotificationSender = pushNotificationSender,
        _pushNotificationBuilder = pushNotificationBuilder;

  // ============================================================================
  // State Variables
  // ============================================================================

  List<CustomerWithNames> _customers = [];
  List<CustomerWithNames> get customers => _customers;

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
    final userId = await StorageHelper.getUserId();
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
  Future<Order?> getOrderByCustomer(CustomerWithNames customer) async {
    _setLoading(true);
    _clearError();

    final date = _getDBFormatDate();
    final result = await _ordersRepository.getOrdersByCustomer(
      customerId: customer.customerId,
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
    order ??= await _createTempOrder(customer.toCustomer());

    _setLoading(false);
    return order;
  }

  /// Create customer via API and update local DB
  /// Matches KMP's saveCustomer function (lines 121-158)
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

    // Build notification user list BEFORE API call (matches KMP lines 127-136)
    final userId = await StorageHelper.getUserId();
    final userType = await StorageHelper.getUserType();
    final notificationUserIds = await _pushNotificationBuilder.buildCustomerNotificationList(
      currentUserId: userId,
      userType: userType,
      salesmanId: salesmanId,
    );

    // Create customer object
    final customer = Customer(
      // id: 0,
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
        
        // Send push notification (matches KMP lines 146-152)
        final dataIds = [
          PushData(table: NotificationId.customer, id: createdCustomer.customerId!),
        ];
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'Customer updates',
          customUserIds: notificationUserIds,
        ).catchError((e) {
          developer.log('CustomersProvider: Error sending push notification: $e');
        });
        
        loadCustomers(); // Reload list
      },
    );

    _setLoading(false);
    return success;
  }

  /// Update customer via API and update local DB
  /// Matches KMP's updateCustomer function (lines 159-193)
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

    // Get old salesman ID (matches KMP line 165)
    final oldCustomerResult = await _customersRepository.getCustomerById(customerId);
    int oldSalesmanId = -1;
    oldCustomerResult.fold(
      (failure) => null,
      (customer) => oldSalesmanId = customer?.salesManId ?? -1,
    );

    // Build notification user list BEFORE API call (matches KMP lines 166-176)
    final userId = await StorageHelper.getUserId();
    final userType = await StorageHelper.getUserType();
    final notificationUserIds = await _pushNotificationBuilder.buildCustomerNotificationList(
      currentUserId: userId,
      userType: userType,
      salesmanId: salesmanId,
      oldSalesmanId: oldSalesmanId,
    );

    // Create customer object with updated data
    final customer = Customer(
      customerId: customerId, // Use server ID, not local id (id is AUTOINCREMENT)
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
        
        // Send push notification (matches KMP lines 183-185)
        final dataIds = [
          PushData(table: NotificationId.customer, id: customerId),
        ];
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'Customer updates',
          customUserIds: notificationUserIds,
        ).catchError((e) {
          developer.log('CustomersProvider: Error sending push notification: $e');
        });
        
        loadCustomers(); // Reload list
      },
    );

    _setLoading(false);
    return success;
  }

  /// Update customer flag
  /// Matches KMP's updateCustomerFlag function (lines 196-223)
  Future<bool> updateCustomerFlag({
    required int customerId,
    required int salesmanId,
    required int flag,
  }) async {
    _setLoading(true);
    _clearError();

    // Build notification user list BEFORE API call (matches KMP lines 197-206)
    final userId = await StorageHelper.getUserId();
    final userType = await StorageHelper.getUserType();
    final notificationUserIds = await _pushNotificationBuilder.buildCustomerNotificationList(
      currentUserId: userId,
      userType: userType,
      salesmanId: salesmanId,
    );

    final result = await _customersRepository.updateCustomerFlag(
      customerId: customerId,
      flag: flag,
    );

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (_) {
        success = true;
        
        // Send push notification (matches KMP lines 216-218)
        final dataIds = [
          PushData(table: NotificationId.customer, id: customerId),
        ];
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'Customer updates',
          customUserIds: notificationUserIds,
        ).catchError((e) {
          developer.log('CustomersProvider: Error sending push notification: $e');
        });
        
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
          orderId = order.orderId + 1; // Use orderId (int), not orderInvNo (String)
        }
      },
    );

    final now = _getDBFormatDateTime();
    final tempOrder = Order(
      id: 0,
      uuid: '',
      orderInvNo: 'ORDER$orderId',
      orderCustId: customer.customerId!,
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
    await result.fold(
      (failure) async {
        _setError(failure.message);
      },
      (_) async {
        // Query for the temp order we just created to get its local ID
        final tempResult = await _ordersRepository.getTempOrders();
        tempResult.fold(
          (failure) => null,
          (orders) {
            // Find the order we just created by customer ID and invoiceNo
            // This ensures we get the correct order even if there are multiple temp orders
            order = orders.firstWhere(
              (o) => o.orderCustId == customer.customerId! && o.orderInvNo == 'ORDER$orderId',
              orElse: () => tempOrder, // Fallback to tempOrder if not found
            );
          },
        );
      },
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

