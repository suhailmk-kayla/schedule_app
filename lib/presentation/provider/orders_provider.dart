import 'package:flutter/foundation.dart';
import '../../repositories/orders/orders_repository.dart';
import '../../repositories/routes/routes_repository.dart';
import '../../repositories/packed_subs/packed_subs_repository.dart';
import '../../repositories/units/units_repository.dart';
import '../../repositories/users/users_repository.dart';
import '../../repositories/order_sub_suggestions/order_sub_suggestions_repository.dart';
import '../../models/order_api.dart';
import '../../models/order_sub_with_details.dart';
import '../../models/order_item_detail.dart';
import '../../models/order_with_name.dart';
import '../../models/master_data_api.dart';
import '../../utils/config.dart';
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
  final UsersRepository _usersRepository;
  final OrderSubSuggestionsRepository _orderSubSuggestionsRepository;

  OrdersProvider({
    required UsersRepository usersRepository,
    required OrdersRepository ordersRepository,
    required RoutesRepository routesRepository,
    required PackedSubsRepository packedSubsRepository,
    required OrderSubSuggestionsRepository orderSubSuggestionsRepository,
    UnitsRepository? unitsRepository,
  })  : _usersRepository = usersRepository,
        _ordersRepository = ordersRepository,
        _routesRepository = routesRepository,
        _packedSubsRepository = packedSubsRepository,
        _orderSubSuggestionsRepository = orderSubSuggestionsRepository,
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

  OrderWithName? _orderDetails;
  OrderWithName? get orderDetails => _orderDetails;

  List<OrderItemDetail> _orderDetailItems = [];
  List<OrderItemDetail> get orderDetailItems => _orderDetailItems;

  bool _orderDetailsLoading = false;
  bool get orderDetailsLoading => _orderDetailsLoading;

  String? _orderDetailsError;
  String? get orderDetailsError => _orderDetailsError;

  final Map<int, int> _replacedOrderSubIds = {};
  Map<int, int> get replacedOrderSubIds => _replacedOrderSubIds;

  final Map<int, OrderItemDetail> _replacedOrderItems = {};
  Map<int, OrderItemDetail> get replacedOrderItems => _replacedOrderItems;

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

    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
    final int? salesmanId = userType == 3 ? userId : null;
    final result = await _ordersRepository.getAllOrders(
      searchKey: _searchKey,
      routeId: _routeId == -1 ? -1 : _routeId,
      date: _date,
      salesmanId: salesmanId,
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

  /// Load order details with metadata (admin view)
  Future<void> loadOrderDetails(int orderId) async {
    _orderDetailsLoading = true;
    _orderDetailsError = null;
    notifyListeners();

    final orderResult = await _ordersRepository.getOrderWithNamesById(orderId);
    if (orderResult.isLeft) {
      _orderDetailsError = orderResult.left.message;
      _orderDetailsLoading = false;
      notifyListeners();
      return;
    }

    final orderWithName = orderResult.right;
    if (orderWithName == null) {
      _orderDetailsError = 'Order not found';
      _orderDetailsLoading = false;
      notifyListeners();
      return;
    }

    final itemsResult = await _ordersRepository.getAllOrderSubAndDetails(orderId);
    if (itemsResult.isLeft) {
      _orderDetailsError = itemsResult.left.message;
      _orderDetailsLoading = false;
      notifyListeners();
      return;
    }

    final details = itemsResult.right;
    final List<OrderItemDetail> builtItems = [];
    final Map<int, int> replacementIds = {};
    final Map<int, OrderItemDetail> replacementItems = {};

    for (final detail in details) {
      final suggestionsResult =
          await _orderSubSuggestionsRepository.getAllSuggestionsBySubId(detail.orderSub.id);
      final suggestions = suggestionsResult.fold(
        (_) => <OrderSubSuggestion>[],
        (value) => value,
      );

      final packedResult = await _packedSubsRepository.getPackedList(detail.orderSub.id);
      final isPacked = packedResult.fold(
        (_) => false,
        (packedList) => packedList.isNotEmpty,
      );

      final item = OrderItemDetail(
        details: detail,
        suggestions: suggestions,
        isPacked: isPacked,
      );
      builtItems.add(item);

      final replacedId = _extractReplacedOrderSubId(detail.orderSub.orderSubNote);
      if (replacedId != null) {
        replacementIds[replacedId] = detail.orderSub.id;
        replacementItems[detail.orderSub.id] = item;
      }
    }

    _orderDetails = orderWithName;
    _orderDetailItems = builtItems;
    _replacedOrderSubIds
      ..clear()
      ..addAll(replacementIds);
    _replacedOrderItems
      ..clear()
      ..addAll(replacementItems);
    _orderDetailsLoading = false;
    notifyListeners();
  }

  void clearOrderDetails() {
    _orderDetails = null;
    _orderDetailItems = [];
    _replacedOrderSubIds.clear();
    _replacedOrderItems.clear();
    _orderDetailsError = null;
    notifyListeners();
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
  /// Converted from KMP's sendOrder (OrderViewModel.kt lines 721-820)
  /// Matches exact functionality and conditionals from KMP
  Future<bool> sendOrder(
    double freightCharge,
    double total,
    int storekeeperId,
  ) async {
    if (_orderMaster == null) {
      _setError('Unknown error occurred');
      return false;
    }
    if (_orderMaster!.orderCustId == -1) {
      _setError('Please Select a customer!');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      // Get all order subs with details (matches KMP line 728)
      final subsResult = await _ordersRepository.getAllOrderSubAndDetails(_orderMaster!.id);
      if (subsResult.isLeft) {
        _setError(subsResult.left.message);
        _setLoading(false);
        return false;
      }
      final subList = subsResult.right;

      // Get admins and storekeepers for push notifications (matches KMP lines 729-736)
      final adminsResult = await _usersRepository.getUsersByCategory(1);
      final storekeepersResult = await _usersRepository.getUsersByCategory(2);
      
      final List<Map<String, dynamic>> userIds = [];
      
      adminsResult.fold(
        (_) {},
        (admins) {
          for (final admin in admins) {
            userIds.add({
              'user_id': admin.id,
              'silent_push': 1,
            });
          }
        },
      );
      
      storekeepersResult.fold(
        (_) {},
        (storekeepers) {
          for (final storekeeper in storekeepers) {
            userIds.add({
              'user_id': storekeeper.id,
              'silent_push': 0,
            });
          }
        },
      );

      // Build push notification payload (matches KMP's sentPushNotification - OrderViewModel.kt line 738-739)
      // KMP calls: sentPushNotification(arrayListOf(), userIds, "New Order Received")
      // This builds the notification JSON object structure
      final notificationJsonObject = <String, dynamic>{
        'ids': userIds,
        'data_message': 'New Order Received',
        'data': {
          'data_ids': <Map<String, dynamic>>[], // Empty array as per KMP line 738
          'show_notification': '0',
          'message': 'New Order Received',
        },
      };

      // Build order params (matches KMP line 740-747)
      final params = _createOrderParams(
        _orderMaster!,
        subList,
        total,
        freightCharge,
        storekeeperId,
        notificationJsonObject,
      );

      // Call API (matches KMP line 749-750)
      final apiResult = await _ordersRepository.sendOrder(params);
      
      if (apiResult.isLeft) {
        _setError(apiResult.left.message);
        _setLoading(false);
        return false;
      }

      final orderApi = apiResult.right;
      final order = orderApi.data;

      // Save order to local DB (matches KMP lines 758-778)
      // CRITICAL: Primary key 'id' is auto-generated by SQLite (set to NULL in repository)
      // The Order model's 'id' field maps to 'orderId' column (stores API response id)
      // KMP: id = 0 (primary key, auto-generated), orderId = API response id
      final newOrder = Order(
        id: order.id, // This maps to 'orderId' column, NOT the primary key - matches KMP line 760: orderId = id
        uuid: order.uuid,
        orderInvNo: order.orderInvNo,
        orderCustId: order.orderCustId,
        orderCustName: order.orderCustName,
        orderSalesmanId: order.orderSalesmanId,
        orderStockKeeperId: order.orderStockKeeperId,
        orderBillerId: order.orderBillerId,
        orderCheckerId: order.orderCheckerId,
        orderDateTime: order.orderDateTime,
        orderTotal: order.orderTotal,
        orderFreightCharge: order.orderFreightCharge,
        orderNote: order.orderNote,
        orderApproveFlag: order.orderApproveFlag,
        orderFlag: 1, // Normal order flag (matches KMP line 775)
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
      );

      final addOrderResult = await _ordersRepository.addOrder(newOrder);
      if (addOrderResult.isLeft) {
        _setError(addOrderResult.left.message);
        _setLoading(false);
        return false;
      }

      // Save order subs to local DB (matches KMP lines 781-815)
      if (order.items != null && order.items!.isNotEmpty) {
        for (int index = 0; index < order.items!.length; index++) {
          final sub = order.items![index];
          // CRITICAL: Primary key 'id' is auto-generated by SQLite (not included in repository INSERT)
          // The OrderSub model's 'id' field maps to 'orderSubId' column (stores API response id)
          // KMP: First param = 0 (primary key, auto-generated), second param = API response id
          final orderSub = OrderSub(
            id: sub.id, // This maps to 'orderSubId' column, NOT the primary key - matches KMP line 785: orderSubId = s.id
            orderSubOrdrInvId: sub.orderSubOrdrInvId,
            orderSubOrdrId: sub.orderSubOrdrId,
            orderSubCustId: sub.orderSubCustId,
            orderSubSalesmanId: sub.orderSubSalesmanId,
            orderSubStockKeeperId: sub.orderSubStockKeeperId,
            orderSubDateTime: sub.orderSubDateTime,
            orderSubPrdId: sub.orderSubPrdId,
            orderSubUnitId: sub.orderSubUnitId,
            orderSubCarId: sub.orderSubCarId,
            orderSubRate: sub.orderSubRate,
            orderSubUpdateRate: sub.orderSubUpdateRate,
            orderSubQty: sub.orderSubQty,
            orderSubAvailableQty: sub.orderSubAvailableQty,
            orderSubUnitBaseQty: sub.orderSubUnitBaseQty,
            orderSubIsCheckedFlag: sub.orderSubIsCheckedFlag,
            orderSubOrdrFlag: sub.orderSubOrdrFlag,
            orderSubNote: sub.orderSubNote,
            orderSubNarration: sub.orderSubNarration,
            orderSubFlag: sub.orderSubFlag,
            createdAt: sub.createdAt,
            updatedAt: sub.updatedAt,
          );

          final addSubResult = await _ordersRepository.addOrderSub(orderSub);
          if (addSubResult.isLeft) {
            _setError(addSubResult.left.message);
            _setLoading(false);
            return false;
          }
        }
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Create order params for API
  /// Converted from KMP's createOrderParams (OrderViewModel.kt lines 952-1002)
  /// Matches exact payload structure from KMP
  Map<String, dynamic> _createOrderParams(
    Order orderMaster,
    List<OrderSubWithDetails> subList,
    double total,
    double freight,
    int storekeeperId,
    Map<String, dynamic> notificationJsonObject,
  ) {
    final params = <String, dynamic>{
      'uuid': orderMaster.uuid,
      'order_cust_id': orderMaster.orderCustId,
      'order_cust_name': orderMaster.orderCustName,
      'order_salesman_id': orderMaster.orderSalesmanId,
      'order_stock_keeper_id': storekeeperId,
      'order_biller_id': orderMaster.orderBillerId,
      'order_checker_id': orderMaster.orderCheckerId,
      'order_date_time': orderMaster.orderDateTime,
      'order_total': total,
      'order_freight_charge': freight,
      'order_note': orderMaster.orderNote ?? '',
      'order_approve_flag': 1,
      'items': subList.map((item) {
        return {
          'order_sub_prd_id': item.orderSub.orderSubPrdId,
          'order_sub_unit_id': item.orderSub.orderSubUnitId,
          'order_sub_car_id': item.orderSub.orderSubCarId,
          'order_sub_rate': item.orderSub.orderSubRate,
          'order_sub_update_rate': item.orderSub.orderSubUpdateRate,
          'order_sub_qty': item.orderSub.orderSubQty,
          'order_sub_available_qty': item.orderSub.orderSubAvailableQty,
          'order_sub_unit_base_qty': item.orderSub.orderSubUnitBaseQty,
          'order_sub_ordr_flag': 1,
          'order_sub_is_checked_flag': 0,
          'order_sub_note': item.orderSub.orderSubNote ?? '',
          'order_sub_narration': item.orderSub.orderSubNarration ?? '',
        };
      }).toList(),
      'notification': notificationJsonObject,
    };

    return params;
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

  int? _extractReplacedOrderSubId(String? note) {
    if (note == null || note.isEmpty) {
      return null;
    }
    if (!note.contains(ApiConfig.replacedSubDelOrderSubId)) {
      return null;
    }
    final parts = note.split(ApiConfig.replacedSubDelOrderSubId);
    if (parts.isEmpty) {
      return null;
    }
    return int.tryParse(parts.last.trim());
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

