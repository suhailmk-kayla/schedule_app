import 'package:flutter/foundation.dart';
import '../../repositories/orders/orders_repository.dart';
import '../../repositories/routes/routes_repository.dart';
import '../../repositories/packed_subs/packed_subs_repository.dart';
import '../../repositories/units/units_repository.dart';
import '../../models/order_api.dart';
import '../../models/order_sub_with_details.dart';
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
  final UnitsRepository? _unitsRepository;

  OrdersProvider({
    required OrdersRepository ordersRepository,
    required RoutesRepository routesRepository,
    required PackedSubsRepository packedSubsRepository,
    UnitsRepository? unitsRepository,
  })  : _ordersRepository = ordersRepository,
        _routesRepository = routesRepository,
        _packedSubsRepository = packedSubsRepository,
        _unitsRepository = unitsRepository;

  // ============================================================================
  // State Variables
  // ============================================================================

  List<Order> _orderList = [];
  List<Order> get orderList => _orderList;

  Order? _currentOrder;
  Order? get currentOrder => _currentOrder;

  List<OrderSub> _orderSubs = [];
  List<OrderSub> get orderSubs => _orderSubs;

  List<OrderSubWithDetails> _orderSubsWithDetails = [];
  List<OrderSubWithDetails> get orderSubsWithDetails => _orderSubsWithDetails;

  Order? _orderMaster;
  Order? get orderMaster => _orderMaster;

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
    _orderSubsWithDetails = [];
    _orderMaster = null;
    _customerId = -1;
    _customerName = 'Select customer';
    notifyListeners();
  }

  /// Delete order and all its order subs
  /// Converted from KMP's deleteOrderAndSub
  /// Used when discarding changes in CreateOrderScreen
  Future<bool> deleteOrderAndSub() async {
    if (_orderMaster == null) {
      return false;
    }

    _setLoading(true);
    _clearError();

    final orderId = _orderMaster!.id;
    final result = await _ordersRepository.deleteOrderAndSub(orderId);

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (_) {
        success = true;
        // Clear state after successful deletion
        clearCurrentOrder();
      },
    );

    _setLoading(false);
    return success;
  }

  /// Get temp order (flag = 2) or create new one
  /// Converted from KMP's getTempOrder
  Future<void> getTempOrder() async {
    _setLoading(true);
    _clearError();

    final result = await _ordersRepository.getTempOrders();
    result.fold(
      (failure) => _setError(failure.message),
      (orders) async {
        if (orders.isNotEmpty) {
          _orderMaster = orders.first;
          _customerId = _orderMaster!.orderCustId;
          _customerName = _orderMaster!.orderCustName.isNotEmpty
              ? _orderMaster!.orderCustName
              : 'Select customer';
          
          // Load order subs with details
          final subsResult = await _ordersRepository.getTempOrderSubAndDetails(_orderMaster!.id);
          subsResult.fold(
            (failure) => _setError(failure.message),
            (subs) {
              _orderSubsWithDetails = subs;
              notifyListeners();
            },
          );
        } else {
          // Create new temp order
          await createTempOrder();
        }
      },
    );

    _setLoading(false);
  }

  /// Get draft order by order ID (flag = 3)
  /// Converted from KMP's getDraftOrder
  Future<void> getDraftOrder(int orderId) async {
    _setLoading(true);
    _clearError();

    final result = await _ordersRepository.getDraftOrders(orderId);
    result.fold(
      (failure) => _setError(failure.message),
      (orders) async {
        if (orders.isNotEmpty) {
          _orderMaster = orders.first;
          _customerId = _orderMaster!.orderCustId;
          _customerName = _orderMaster!.orderCustName.isNotEmpty
              ? _orderMaster!.orderCustName
              : 'Select customer';
          
          // Load order subs with details
          final subsResult = await _ordersRepository.getAllOrderSubAndDetails(_orderMaster!.id);
          subsResult.fold(
            (failure) => _setError(failure.message),
            (subs) {
              _orderSubsWithDetails = subs;
              notifyListeners();
            },
          );
        }
      },
    );

    _setLoading(false);
  }

  /// Create new temp order (flag = 2)
  /// Converted from KMP's createTempOrder
  Future<void> createTempOrder() async {
    _setLoading(true);
    _clearError();

    // Get last order entry to determine next orderId
    final lastEntryResult = await _ordersRepository.getLastOrderEntry();
    int nextOrderId = 1;
    lastEntryResult.fold(
      (_) {},
      (lastOrder) {
        if (lastOrder != null) {
          nextOrderId = lastOrder.id + 1;
        }
      },
    );

    final now = DateTime.now();
    final dateTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final userId = await StorageHelper.getUserId();
    final deviceToken = await StorageHelper.getDeviceToken();

    final tempOrder = Order(
      id: nextOrderId,
      uuid: '${now.millisecondsSinceEpoch}$deviceToken$userId',
      orderInvNo: 0,
      orderCustId: -1,
      orderCustName: '',
      orderSalesmanId: userId,
      orderStockKeeperId: -1,
      orderBillerId: -1,
      orderCheckerId: -1,
      orderDateTime: dateTimeStr,
      orderTotal: 0.0,
      orderFreightCharge: 0.0,
      orderNote: '',
      orderApproveFlag: 0,
      orderFlag: 2, // Temp order flag
      createdAt: dateTimeStr,
      updatedAt: dateTimeStr,
    );

    final addResult = await _ordersRepository.addOrder(tempOrder);
    addResult.fold(
      (failure) => _setError(failure.message),
      (_) {
        _orderMaster = tempOrder;
        _orderSubsWithDetails = [];
        notifyListeners();
      },
    );

    _setLoading(false);
  }

  /// Get all order subs with details for current order
  /// Converted from KMP's getAllOrderSubAndDetails
  Future<void> getAllOrderSubAndDetails() async {
    if (_orderMaster == null) return;

    final result = await _ordersRepository.getAllOrderSubAndDetails(_orderMaster!.id);
    result.fold(
      (failure) => _setError(failure.message),
      (subs) {
        _orderSubsWithDetails = subs;
        notifyListeners();
      },
    );
  }

  /// Update order note
  /// Converted from KMP's updateOrderNote
  Future<void> updateOrderNote(String note) async {
    if (_orderMaster == null) return;

    final result = await _ordersRepository.updateOrderNote(
      orderId: _orderMaster!.id,
      note: note,
    );

    result.fold(
      (failure) => _setError(failure.message),
      (_) {
        _orderMaster = Order(
          id: _orderMaster!.id,
          uuid: _orderMaster!.uuid,
          orderInvNo: _orderMaster!.orderInvNo,
          orderCustId: _orderMaster!.orderCustId,
          orderCustName: _orderMaster!.orderCustName,
          orderSalesmanId: _orderMaster!.orderSalesmanId,
          orderStockKeeperId: _orderMaster!.orderStockKeeperId,
          orderBillerId: _orderMaster!.orderBillerId,
          orderCheckerId: _orderMaster!.orderCheckerId,
          orderDateTime: _orderMaster!.orderDateTime,
          orderTotal: _orderMaster!.orderTotal,
          orderFreightCharge: _orderMaster!.orderFreightCharge,
          orderNote: note,
          orderApproveFlag: _orderMaster!.orderApproveFlag,
          orderFlag: _orderMaster!.orderFlag,
          createdAt: _orderMaster!.createdAt,
          updatedAt: _orderMaster!.updatedAt,
        );
        notifyListeners();
      },
    );
  }

  /// Update order customer
  /// Converted from KMP's updateCustomer
  Future<void> updateCustomer(int customerId, String customerName) async {
    if (_orderMaster == null) return;

    final result = await _ordersRepository.updateOrderCustomer(
      orderId: _orderMaster!.id,
      customerId: customerId,
      customerName: customerName,
    );

    result.fold(
      (failure) => _setError(failure.message),
      (_) {
        _customerId = customerId;
        _customerName = customerName;
        _orderMaster = Order(
          id: _orderMaster!.id,
          uuid: _orderMaster!.uuid,
          orderInvNo: _orderMaster!.orderInvNo,
          orderCustId: customerId,
          orderCustName: customerName,
          orderSalesmanId: _orderMaster!.orderSalesmanId,
          orderStockKeeperId: _orderMaster!.orderStockKeeperId,
          orderBillerId: _orderMaster!.orderBillerId,
          orderCheckerId: _orderMaster!.orderCheckerId,
          orderDateTime: _orderMaster!.orderDateTime,
          orderTotal: _orderMaster!.orderTotal,
          orderFreightCharge: _orderMaster!.orderFreightCharge,
          orderNote: _orderMaster!.orderNote,
          orderApproveFlag: _orderMaster!.orderApproveFlag,
          orderFlag: _orderMaster!.orderFlag,
          createdAt: _orderMaster!.createdAt,
          updatedAt: _orderMaster!.updatedAt,
        );
        notifyListeners();
      },
    );
  }

  /// Save order as draft (flag = 3)
  /// Converted from KMP's saveAsDraft
  Future<bool> saveAsDraft(double freightCharge, double total) async {
    if (_orderMaster == null) return false;

    _setLoading(true);
    _clearError();

    final now = DateTime.now();
    final dateTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    // Update flag to 3 (draft)
    final flagResult = await _ordersRepository.updateOrderFlag(
      orderId: _orderMaster!.id,
      flag: 3,
    );

    if (flagResult.isLeft) {
      _setError(flagResult.left.message);
      _setLoading(false);
      return false;
    }

    // Update freight and total
    final updateResult = await _ordersRepository.updateFreightAndTotal(
      orderId: _orderMaster!.id,
      freightCharge: freightCharge,
      total: total,
    );

    if (updateResult.isLeft) {
      _setError(updateResult.left.message);
      _setLoading(false);
      return false;
    }

    // Update updated date
    await _ordersRepository.updateUpdatedDate(
      orderId: _orderMaster!.id,
      updatedDateTime: dateTimeStr,
    );

    _setLoading(false);
    return true;
  }

  /// Send order (check stock) - calls API
  /// Converted from KMP's sendOrder
  Future<bool> sendOrder(double freightCharge, double total) async {
    if (_orderMaster == null) return false;
    if (_orderMaster!.orderCustId == -1) {
      _setError('Please Select a customer!');
      return false;
    }

    _setLoading(true);
    _clearError();

    // TODO: Implement API call to send order
    // This requires building the order payload with all order subs
    // For now, return false
    _setError('Send order API not yet implemented');
    _setLoading(false);
    return false;
  }

  /// Add product to order
  /// Converted from KMP's ProductViewModel.addProductToOrder
  /// Creates OrderSub and saves to database
  Future<bool> addProductToOrder({
    required int productId,
    required double productPrice, // Product's base price
    required double rate, // User-entered rate
    required double quantity,
    required String narration,
    required int unitId,
    OrderSub? replaceOrderSub,
    bool isUpdate = false,
  }) async {
    if (_orderMaster == null) return false;

    _setLoading(true);
    _clearError();

    try {
      // Get order
      final order = _orderMaster!;

      // Get last order sub entry to generate new orderSubId
      final lastEntryResult = await _ordersRepository.getLastOrderSubEntry();
      int orderSubId = 100000000; // Default starting ID
      lastEntryResult.fold(
        (_) {},
        (lastOrderSub) {
          if (lastOrderSub != null) {
            orderSubId = (lastOrderSub.id + 100000000) + 1;
          }
        },
      );

      // Get unit to get baseQty
      double baseQty = 1.0;
      if (_unitsRepository != null) {
        final unitResult = await _unitsRepository.getUnitByUnitId(unitId);
        unitResult.fold(
          (_) {},
          (unit) {
            if (unit != null) {
              baseQty = unit.baseQty > 0 ? unit.baseQty : 1.0;
            }
          },
        );
      }

      // Check if product already exists in order
      final existResult = await _ordersRepository.getExistOrderSub(
        orderId: order.id,
        productId: productId,
        unitId: unitId,
        rate: rate,
      );

      double newQuantity = quantity;
      String noteSt = '';
      int isChecked = 0;

      existResult.fold(
        (_) {},
        (existList) {
          if (existList.isNotEmpty) {
            orderSubId = existList.first.id;
            if (!isUpdate) {
              // Merge quantities
              newQuantity += existList.first.orderSubQty;
              if (existList.first.orderSubIsCheckedFlag == 1) {
                isChecked = 1;
                // TODO: Handle note updates for quantity changes
              }
            }
          }
        },
      );

      // Handle replace order sub note
      if (replaceOrderSub != null) {
        noteSt = '***\$###\$***OrderSubId=${replaceOrderSub.id}';
        isChecked = 1;
      }

      // Create OrderSub
      final now = DateTime.now();
      final dateTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      final newOrderSub = OrderSub(
        id: orderSubId,
        orderSubOrdrInvId: order.orderInvNo,
        orderSubOrdrId: order.id,
        orderSubCustId: order.orderCustId,
        orderSubSalesmanId: order.orderSalesmanId,
        orderSubStockKeeperId: order.orderStockKeeperId,
        orderSubDateTime: order.orderDateTime,
        orderSubPrdId: productId,
        orderSubUnitId: unitId,
        orderSubCarId: -1,
        orderSubRate: productPrice, // Product price (matches KMP line 536)
        orderSubUpdateRate: rate, // User-entered rate (matches KMP line 537)
        orderSubQty: newQuantity,
        orderSubAvailableQty: 0.0,
        orderSubUnitBaseQty: baseQty,
        orderSubNote: noteSt.isEmpty ? null : noteSt,
        orderSubNarration: narration.isEmpty ? null : narration,
        orderSubOrdrFlag: 0, // Temp order flag (matches KMP line 543)
        orderSubIsCheckedFlag: isChecked,
        orderSubFlag: 0, // Temp order flag (matches KMP line 546 where flag=1 for normal, 0 for temp)
        createdAt: dateTimeStr,
        updatedAt: dateTimeStr,
      );

      // Save to database
      final addResult = await _ordersRepository.addOrderSub(newOrderSub);
      bool success = false;
      addResult.fold(
        (failure) => _setError(failure.message),
        (_) {
          success = true;
          // Refresh order subs
          getAllOrderSubAndDetails();
        },
      );

      _setLoading(false);
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
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

