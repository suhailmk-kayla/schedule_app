import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import '../../repositories/orders/orders_repository.dart';
import '../../repositories/routes/routes_repository.dart';
import '../../repositories/packed_subs/packed_subs_repository.dart';
import '../../repositories/units/units_repository.dart';
import '../../repositories/users/users_repository.dart';
import '../../repositories/order_sub_suggestions/order_sub_suggestions_repository.dart';
import '../../repositories/products/products_repository.dart';
import '../../repositories/out_of_stock/out_of_stock_repository.dart';
import '../../models/order_api.dart';
import '../../models/order_sub_with_details.dart';
import '../../models/order_item_detail.dart';
import '../../models/order_with_name.dart';
import '../../models/master_data_api.dart';
import '../../utils/config.dart';
import '../../utils/storage_helper.dart';
import '../../utils/order_flags.dart';
import '../../utils/push_notification_builder.dart';
import '../../utils/push_notification_sender.dart';
import '../../models/push_data.dart';
import '../../utils/notification_id.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';

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
  final ProductsRepository? _productsRepository;
  final PushNotificationBuilder _pushNotificationBuilder;
  final OutOfStockRepository _outOfStockRepository;
  
  /// Get PushNotificationSender lazily to avoid circular dependency
  PushNotificationSender get _pushNotificationSender =>
      GetIt.instance<PushNotificationSender>();

  OrdersProvider({
    required UsersRepository usersRepository,
    required OrdersRepository ordersRepository,
    required RoutesRepository routesRepository,
    required PackedSubsRepository packedSubsRepository,
    required OrderSubSuggestionsRepository orderSubSuggestionsRepository,
    UnitsRepository? unitsRepository,
    ProductsRepository? productsRepository,
    required PushNotificationBuilder pushNotificationBuilder,
    required OutOfStockRepository outOfStockRepository,
  })  : _usersRepository = usersRepository,
        _ordersRepository = ordersRepository,
        _routesRepository = routesRepository,
        _packedSubsRepository = packedSubsRepository,
        _orderSubSuggestionsRepository = orderSubSuggestionsRepository,
        _unitsRepository = unitsRepository,
        _productsRepository = productsRepository,
        _pushNotificationBuilder = pushNotificationBuilder,
        _outOfStockRepository = outOfStockRepository {
    // Default to today's date so the "Today" filter actually filters today's orders
    _date = _getDBFormatDate();
  }

  // ============================================================================
  // State Variables
  // ============================================================================

  List<OrderWithName> _orderList = [];
  List<OrderWithName> get orderList => _orderList;

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

  int? _filterSalesmanId;
  int? get filterSalesmanId => _filterSalesmanId;

//2025-08-13 16:21:36
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
  /// Set salesman filter for order list
  /// When set, only orders for this salesman will be shown
  /// Matches KMP's SalesmanOrderListScreen behavior
  void setSalesmanFilter(int salesmanId) {
    _filterSalesmanId = salesmanId;
    notifyListeners();
  }

  /// Clear salesman filter
  void clearSalesmanFilter() {
    _filterSalesmanId = null;
    notifyListeners();
  }

  Future<void> loadOrders({bool toRefresh=false}) async {
    if(toRefresh){
      developer.log('loadOrders:loading orders from local database to refresh');
    }else{
      developer.log('loadOrders:loading orders from local databae');
    }
    _setLoading(true);
    _clearError();

    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
    
    // Use filterSalesmanId if set, otherwise use userId if userType == 3 (salesman)
    // Matches KMP's SalesmanOrderListScreen behavior
    final int? salesmanId = _filterSalesmanId ?? (userType == 3 ? userId : null);
    
    final result = await _ordersRepository.getAllOrdersWithNames(
      searchKey: _searchKey,
      routeId: _routeId == -1 ? -1 : _routeId,
      date: _date,
      salesmanId: salesmanId,
    );

    result.fold(
      (failure) => _setError(failure.message),
      (ordersWithNames) {
        _orderList = ordersWithNames;
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
          loadOrderSubs(order.orderId);
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
          await _orderSubSuggestionsRepository.getAllSuggestionsBySubId(detail.orderSub.orderSubId);
      final suggestions = suggestionsResult.fold(
        (_) => <OrderSubSuggestion>[],
        (value) => value,
      );

      final packedResult = await _packedSubsRepository.getPackedList(detail.orderSub.orderSubId);
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
        replacementIds[replacedId] = detail.orderSub.orderSubId;
        replacementItems[detail.orderSub.orderSubId] = item;
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
          loadOrderSubs(_currentOrder!.orderId);
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
          loadOrderSubs(_currentOrder!.orderId);
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
          loadOrderSubs(_currentOrder!.orderId);
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

  /// Remove suggestion by ID
  /// Converted from KMP's removeSuggestion
  Future<bool> removeSuggestion(int sugId) async {
    final result = await _orderSubSuggestionsRepository.removeSuggestion(sugId);

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (_) {
        success = true;
        // Reload order details to reflect changes
        if (_orderDetails != null) {
          loadOrderDetails(_orderDetails!.order.orderId);
        }
      },
    );

    return success;
  }

  /// Add suggestion for an order sub (local DB only; sent with inform updates)
  Future<bool> addSuggestionToOrderSub({
    required int orderSubId,
    required int productId,
    required double price,
    String? note,
  }) async {
    final suggestion = OrderSubSuggestion(
      id: -1, // autoincrement in DB
      orderSubId: orderSubId,
      prodId: productId,
      price: price,
      note: note ?? '',
      flag: 1,
    );

    final result = await _orderSubSuggestionsRepository.addSuggestion(suggestion);

    bool success = false;
    result.fold(
      (failure) {
        _setError(failure.message);
        success = false;
      },
      (_) {
        success = true;
      },
    );

    // Reload order details to reflect the new suggestion (fire and forget for now)
    if (success && _orderDetails != null) {
      loadOrderDetails(_orderDetails!.order.orderId);
    }

    return success;
  }

  /// Check if a suggestion already exists for a given order sub and product
  Future<bool> suggestionExistsForSub({
    required int orderSubId,
    required int productId,
  }) async {
    final result = await _orderSubSuggestionsRepository.getSuggestionExist(
      orderSubId: orderSubId,
      productId: productId,
    );
    return result.fold((_) => false, (list) => list.isNotEmpty);
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

    final orderId = _orderMaster!.orderId;
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
      (failure){
        developer.log('getTempOrder: ${failure.message}');
_setError(failure.message);
      } ,
      (orders) async {
        if (orders.isNotEmpty) {
          developer.log('Get Temp Order: temporary order found');
          _orderMaster = orders.first;
          _customerId = _orderMaster!.orderCustId;
          _customerName = _orderMaster!.orderCustName.isNotEmpty
              ? _orderMaster!.orderCustName
              : 'Select customer';
          
          // Load order subs with details
          final subsResult = await _ordersRepository.getTempOrderSubAndDetails(_orderMaster!.orderId);
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
          final subsResult = await _ordersRepository.getAllOrderSubAndDetails(_orderMaster!.orderId);
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
    developer.log('createTempOrder:no temporary order found, creating new one');
    _setLoading(true);
    _clearError();

    // Get last order entry to determine next orderId
    final lastEntryResult = await _ordersRepository.getLastOrderEntry();
    developer.log('createTempOrder:got last inserted order: ${lastEntryResult.fold((_) => 'null', (order) => order?.id.toString() ?? 'null')}');
    int nextOrderId = 1;
    lastEntryResult.fold(
      (_) {},
      (lastOrder) {
        if (lastOrder != null) {
          nextOrderId = lastOrder.orderId + 1;
        }
      },
    );

    final now = DateTime.now();
    final dateTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final userId = await StorageHelper.getUserId();
    final deviceToken = await StorageHelper.getDeviceToken();

    final tempOrder = Order(
      id:0,
      orderId: nextOrderId,
      // id: nextOrderId,
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

    final addResult = await _ordersRepository.addOrder(tempOrder,isTemp: true);
    addResult.fold(
      (failure) => _setError(failure.message),
      (_) {
        _orderMaster = tempOrder;
        _orderSubsWithDetails = [];
        developer.log('createTempOrder:temp order added: ${tempOrder.orderId}');
        notifyListeners();
      },
    );

    _setLoading(false);
  }

  /// Get all order subs with details for current order
  /// Converted from KMP's getAllOrderSubAndDetails
  Future<void> getAllOrderSubAndDetails() async {
    if (_orderMaster == null) return;

    final result = await _ordersRepository.getAllOrderSubAndDetails(_orderMaster!.orderId);
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
      orderId: _orderMaster!.orderId,
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
      orderId: _orderMaster!.orderId,
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
      orderId: _orderMaster!.orderId,
      flag: 3,
    );

    if (flagResult.isLeft) {
      _setError(flagResult.left.message);
      _setLoading(false);
      return false;
    }

    // Update freight and total
    final updateResult = await _ordersRepository.updateFreightAndTotal(
      orderId: _orderMaster!.orderId,
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
      orderId: _orderMaster!.orderId,
      updatedDateTime: dateTimeStr,
    );

    _setLoading(false);
    return true;
  }

  /// Save order as draft with note map, available qty map, and out of stock list
  /// Updates order subs locally and sets flag to 3 (draft)
  /// Converted from KMP's saveAsDraft(noteMap, availableQtyMap, outOfStockList, handler)
  Future<bool> saveAsDraftWithNotes({
    required Map<int, String> noteMap,
    required Map<int, String> availableQtyMap,
    required List<int> outOfStockList,
  }) async {
    if (_orderDetails == null || _orderDetailItems.isEmpty) {
      _setError('Order not loaded');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      // Update each order sub with notes, available qty, and out of stock flag
      for (final item in _orderDetailItems) {
        final orderSubId = item.orderSub.orderSubId;
        final orderSub = item.orderSub;

        // Get note from map or use existing
        String note = noteMap[orderSubId] ?? '';
        if (orderSub.orderSubNote != null && 
            orderSub.orderSubNote!.contains(ApiConfig.noteSplitDel)) {
          // If note contains split delimiter, keep the first part
          note = orderSub.orderSubNote!.split(ApiConfig.noteSplitDel).first;
        }

        // Get available qty from map or use existing
        double availableQty = orderSub.orderSubAvailableQty;
        if (availableQtyMap.containsKey(orderSubId)) {
          availableQty = double.tryParse(availableQtyMap[orderSubId] ?? '0') ?? 0.0;
        }

        // Determine order flag based on out of stock list
        int orderFlag = orderSub.orderSubOrdrFlag;
        if (outOfStockList.contains(orderSubId)) {
          orderFlag = OrderSubFlag.outOfStock;
        } else if (orderSub.orderSubIsCheckedFlag == 0) {
          // If not checked yet, set to inStock if not in out of stock list
          orderFlag = OrderSubFlag.inStock;
        }

        // Create updated order sub
        final updatedOrderSub = OrderSub(
          id: orderSub.id,
          orderSubOrdrInvId: orderSub.orderSubOrdrInvId,
          orderSubOrdrId: orderSub.orderSubOrdrId,
          orderSubCustId: orderSub.orderSubCustId,
          orderSubSalesmanId: orderSub.orderSubSalesmanId,
          orderSubStockKeeperId: orderSub.orderSubStockKeeperId,
          orderSubDateTime: orderSub.orderSubDateTime,
          orderSubPrdId: orderSub.orderSubPrdId,
          orderSubUnitId: orderSub.orderSubUnitId,
          orderSubCarId: orderSub.orderSubCarId,
          orderSubRate: orderSub.orderSubRate,
          orderSubUpdateRate: orderSub.orderSubUpdateRate,
          orderSubQty: orderSub.orderSubQty,
          orderSubAvailableQty: availableQty,
          orderSubUnitBaseQty: orderSub.orderSubUnitBaseQty,
          orderSubIsCheckedFlag: orderSub.orderSubIsCheckedFlag,
          orderSubOrdrFlag: orderFlag,
          orderSubNote: note,
          orderSubNarration: orderSub.orderSubNarration,
          orderSubFlag: orderSub.orderSubFlag,
          createdAt: orderSub.createdAt,
          updatedAt: orderSub.updatedAt,
        );

        // Update order sub in local DB
        final updateResult = await _ordersRepository.addOrderSub(updatedOrderSub);
        if (updateResult.isLeft) {
          _setError('Failed to update order sub: ${updateResult.left.message}');
          _setLoading(false);
          return false;
        }
      }

      // Update order flag to 3 (draft)
      final flagResult = await _ordersRepository.updateOrderFlag(
        orderId: _orderDetails!.order.orderId,
        flag: 3,
      );

      if (flagResult.isLeft) {
        _setError(flagResult.left.message);
        _setLoading(false);
        return false;
      }

      // Reload order details to reflect changes
      await loadOrderDetails(_orderDetails!.order.orderId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error saving draft: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Update process flag (isProcessFinish)
  /// Converted from KMP's updateProcessFlag
  Future<bool> updateProcessFlag({
    required int orderId,
    required int isProcessFinish,
  }) async {
    _setLoading(true);
    _clearError();

    final result = await _ordersRepository.updateProcessFlag(
      orderId: orderId,
      isProcessFinish: isProcessFinish,
    );

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (_) => success = true,
    );

    _setLoading(false);
    return success;
  }

  /// Inform updates to order (storekeeper updates)
  /// Sends order updates to API with notes, available quantities, and out of stock flags
  /// Converted from KMP's informUpdates
  Future<bool> informUpdates({
    required Map<int, String> noteMap,
    required Map<int, String> availableQtyMap,
    required List<int> outOfStockList,
    required Function(String) onFailure,
    required Function() onSuccess,
  }) async {
    if (_orderDetails == null || _orderDetailItems.isEmpty) {
      onFailure('Order not loaded');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      final order = _orderDetails!.order;
      final currentUserId = await StorageHelper.getUserId();

      // 1. Build push notification user list (matches KMP lines 598-615)
      final List<Map<String, dynamic>> userIds = [];

      // Get admins
      final adminsResult = await _usersRepository.getUsersByCategory(1);
      adminsResult.fold(
        (_) {},
        (admins) {
          for (final admin in admins) {
            userIds.add({
              'user_id': admin.userId,
              'silent_push': 1,
            });
          }
        },
      );

      // Get storekeepers (excluding current user)
      final storekeepersResult = await _usersRepository.getUsersByCategory(2);
      storekeepersResult.fold(
        (_) {},
        (storekeepers) {
          for (final storekeeper in storekeepers) {
            if (storekeeper.id != currentUserId) {
              userIds.add({
                'user_id': storekeeper.userId,
                'silent_push': 1,
              });
            }
          }
        },
      );

      // Get billers if order has biller
      if (order.orderBillerId != -1) {
        final billersResult = await _usersRepository.getUsersByCategory(5);
        billersResult.fold(
          (_) {},
          (billers) {
            for (final biller in billers) {
              userIds.add({
                'user_id': biller.userId,
                'silent_push': 1,
              });
            }
          },
        );
      }

      // Add salesman with silent_push = 0 (visible notification)
      if (order.orderSalesmanId != -1) {
        userIds.add({
          'user_id': order.orderSalesmanId,
          'silent_push': 1,
        });
      }

      // 2. Build push notification payload
      final notificationPayload = {
        'ids': userIds,
        'data_message': 'Updates from storekeeper',
        'data': {
          'data_ids': [
            {'table': 8, 'id': order.orderId} // Order table
          ],
          //0 means visible notification and 1 means silent notification
          'show_notification': '0',
          'message': 'Updates from storekeeper',
        },
      };

      // 3. Build items array with updated notes, available qty, and flags
      final List<Map<String, dynamic>> itemsArray = [];

      for (final item in _orderDetailItems) {
        final orderSub = item.orderSub;
        final orderSubId = orderSub.orderSubId;

        // Extract note (remove split delimiter if present)
        String note = noteMap[orderSubId] ?? '';
        if (orderSub.orderSubNote != null &&
            orderSub.orderSubNote!.contains(ApiConfig.noteSplitDel)) {
          note = orderSub.orderSubNote!.split(ApiConfig.noteSplitDel).first;
        }

        // Get available qty
        double availableQty = orderSub.orderSubAvailableQty;
        if (availableQtyMap.containsKey(orderSubId)) {
          availableQty = double.tryParse(availableQtyMap[orderSubId] ?? '0') ?? 0.0;
        } else if (outOfStockList.contains(orderSubId)) {
          availableQty = 0.0;
        }

        // Determine order flag
        int orderFlag = orderSub.orderSubOrdrFlag;
        if (orderSub.orderSubIsCheckedFlag == 0) {
          // If not checked yet, update based on out of stock list
          if (outOfStockList.contains(orderSubId)) {
            orderFlag = OrderSubFlag.outOfStock;
          } else {
            orderFlag = OrderSubFlag.inStock;
          }
        }

        // Build suggestions array
        final List<Map<String, dynamic>> suggestionsArray = [];
        if (item.suggestions.isNotEmpty) {
          for (final suggestion in item.suggestions) {
            suggestionsArray.add({
              'prod_id': suggestion.prodId,
              'price': suggestion.price,
              'note': suggestion.note ?? '',
            });
          }
        }

        // Build item payload
        itemsArray.add({
          'order_sub_id': orderSubId,
          'order_sub_prd_id': orderSub.orderSubPrdId,
          'order_sub_unit_id': orderSub.orderSubUnitId,
          'order_sub_car_id': orderSub.orderSubCarId,
          'order_sub_rate': orderSub.orderSubRate,
          'order_sub_date_time': orderSub.orderSubDateTime,
          'order_sub_update_rate': orderSub.orderSubUpdateRate,
          'order_sub_qty': orderSub.orderSubQty,
          'order_sub_available_qty': availableQty,
          'order_sub_unit_base_qty': orderSub.orderSubUnitBaseQty,
          'order_sub_ordr_flag': orderFlag,
          'order_sub_is_checked_flag': 1,
          'order_sub_note': note,
          'order_sub_narration': orderSub.orderSubNarration ?? '',
          'suggestions': suggestionsArray,
        });
      }

      // 4. Build order update payload
      final payload = {
        'order_id': order.orderId,
        'uuid': order.uuid,
        'order_cust_id': order.orderCustId,
        'order_cust_name': order.orderCustName,
        'order_salesman_id': order.orderSalesmanId,
        'order_stock_keeper_id': order.orderStockKeeperId,
        'order_biller_id': order.orderBillerId,
        'order_checker_id': order.orderCheckerId,
        'order_date_time': order.orderDateTime,
        'order_total': order.orderTotal,
        'order_freight_charge': order.orderFreightCharge,
        'order_note': order.orderNote ?? '',
        'order_approve_flag': OrderApprovalFlag.verifiedByStorekeeper,
        'items': itemsArray,
        'notification': notificationPayload,
      };

      // 5. Call API
      final result = await _ordersRepository.updateOrderWithCustomPayload(payload);

      result.fold(
        (failure) {
          _setError(failure.message);
          _setLoading(false);
          onFailure(failure.message);
        },
        (updatedOrder) {
          // Reload order details to reflect changes
          loadOrderDetails(order.orderId);
          loadOrders();
          _setLoading(false);
          onSuccess();
        },
      );

      return result.isRight;
    } catch (e) {
      final errorMsg = 'Error informing updates: $e';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
      return false;
    }
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
      final subsResult = await _ordersRepository.getAllOrderSubAndDetails(_orderMaster!.orderId);
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
              'user_id': admin.userId ?? -1,
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
              'user_id': storekeeper.userId ?? -1,
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
          'show_notification': '1',
          'message': 'New Order Received',
        },
      };

      // Generate a NEW UUID for this order send operation
      // This matches KMP's UUID generation pattern from createTempOrder (line 367-368)
      // and ensures server creates a new order instead of matching by UUID
      final now = DateTime.now();
      final userId = await StorageHelper.getUserId();
      final deviceToken = await StorageHelper.getDeviceToken();
      final newUuid = '${now.millisecondsSinceEpoch}$deviceToken$userId';

      // Build order params (matches KMP line 740-747)
      final params = _createOrderParams(
        _orderMaster!,
        subList,
        total,
        freightCharge,
        storekeeperId,
        notificationJsonObject,
        newUuid, // Pass new UUID instead of reusing temp order's UUID
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
      // The Order model's 'orderId' field stores the server ID from API response
      // KMP: id = 0 (primary key, auto-generated), orderId = API response id
      final newOrder = Order(
        orderId: order.orderId, // Server ID from API response
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
      }else{
        developer.log('sendOrder:order added: ${newOrder.orderId}');
        loadOrders();
      }

      // Save order subs to local DB (matches KMP lines 781-815)
      if (order.items != null && order.items!.isNotEmpty) {
        for (int index = 0; index < order.items!.length; index++) {
          final sub = order.items![index];
          // CRITICAL: Primary key 'id' is auto-generated by SQLite (not included in repository INSERT)
          // The OrderSub model's 'orderSubId' field stores the server ID from API response
          // KMP: First param = 0 (primary key, auto-generated), second param = API response id
          final orderSub = OrderSub(
            orderSubId: sub.orderSubId, // Server ID from API response
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
    String uuid, // Add this parameter - new UUID generated for each order send
  ) {
    final params = <String, dynamic>{
      'uuid': uuid, // Use passed UUID instead of orderMaster.uuid
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
      'order_approve_flag': OrderApprovalFlag.sendToStorekeeper,
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
            orderSubId = (lastOrderSub.orderSubId + 100000000) + 1;
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
        orderId: order.orderId,
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
            orderSubId = existList.first.orderSubId;
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
        noteSt = '***\$###\$***OrderSubId=${replaceOrderSub.orderSubId}';
        isChecked = 1;
      }

      // Create OrderSub
      final now = DateTime.now();
      final dateTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      final newOrderSub = OrderSub(
        orderSubId: orderSubId, // Server ID - must be set for repository to find existing records
        orderSubOrdrInvId: order.orderInvNo,
        orderSubOrdrId: order.orderId,
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

  // ============================================================================
  // Salesman Order Details Methods
  // ============================================================================

  /// Send order to biller or checker
  /// Converted from KMP's sendToBillerOrChecker
  Future<bool> sendToBillerOrChecker({
    required bool isBiller,
    required int userId,
    required Order order,
    int? approvalFlag,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Get users for notifications
      final adminsResult = await _usersRepository.getUsersByCategory(1);
      final List<Map<String, dynamic>> userIds = [];

      adminsResult.fold(
        (_) {},
        (admins) {
          for (final admin in admins) {
            userIds.add({
              'user_id': admin.userId ?? -1,
              'silent_push': 1,
            });
          }
        },
      );

      if (isBiller) {
        final billersResult = await _usersRepository.getUsersByCategory(5);
        billersResult.fold(
          (_) {},
          (billers) {
            for (final biller in billers) {
              // Exclude the claiming biller (matches pattern for checkers)
              if (userId != biller.userId) {
                userIds.add({
                  'user_id': biller.userId ?? -1,
                  'silent_push': 1, // Silent notification for billers
                });
              }
            }
          },
        );
      }

      if (approvalFlag != null) {
        userIds.add({
          'user_id': order.orderSalesmanId,
          'silent_push': 1,
        });
        final checkersResult = await _usersRepository.getUsersByCategory(6);
        checkersResult.fold(
          (_) {},
          (checkers) {
            for (final checker in checkers) {
              if (userId != checker.userId) {
            userIds.add({
              'user_id': checker.userId ?? -1,
              'silent_push': 1,
            });
              }
            }
          },
        );
      }

      // Build notification data
      final dataIds = [
        {'table': 8, 'id': order.id}
      ];

      final notificationJsonObject = {
        'ids': userIds,
        'data_message': 'Order received',
        'data': {
          'data_ids': dataIds,
          'show_notification': '0',
          'message': 'Order received',
        },
      };

      // Build API params
      final params = {
        'order_id': order.orderId,
        'is_biller': isBiller ? 1 : 0,
        'user_Id': userId,
        'order_approve_flag': approvalFlag ?? order.orderApproveFlag,
        'notification': notificationJsonObject,
      };

      // Call API
      final result = await _ordersRepository.updateBillerOrChecker(params);

      bool success = false;
      result.fold(
        (failure) => _setError(failure.message),
        (_) {
          success = true;
          // Update local DB for biller (matching KMP's updateBiller - line 2178)
          if (isBiller) {
            _ordersRepository.updateBillerLocal(
              orderId: order.orderId,
              billerId: userId,
            );
          }
          // Update local DB for checker (matching KMP's updateChecker - line 2180)
          if (!isBiller && approvalFlag != null) {
            _ordersRepository.updateCheckerLocal(
              orderId: order.orderId,
              checkerId: userId,
            );
            _ordersRepository.updateOrderApproveFlag(
              orderId: order.orderId,
              approveFlag: OrderApprovalFlag.checkerIsChecking,
              notification: null,
            );
          }
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

  /// Send order to checkers
  /// Converted from KMP's sendToCheckers
  Future<bool> sendToCheckers(Order order) async {
    _setLoading(true);
    _clearError();

    try {
      // Get users for notifications
      final adminsResult = await _usersRepository.getUsersByCategory(1);
      final checkersResult = await _usersRepository.getUsersByCategory(6);
      final List<Map<String, dynamic>> userIds = [];

      adminsResult.fold(
        (_) {},
        (admins) {
          for (final admin in admins) {
            userIds.add({
              'user_id': admin.userId ?? -1,
              'silent_push': 1,
            });
          }
        },
      );

      checkersResult.fold(
        (_) {},
        (checkers) {
          for (final checker in checkers) {
            userIds.add({
              'user_id': checker.userId ?? -1,
              'silent_push': 0,
            });
          }
        },
      );

      // Build notification data
      final dataIds = [
        {'table': 8, 'id': order.orderId}
      ];

      final notificationJsonObject = {
        'ids': userIds,
        'data_message': 'Order received',
        'data': {
          'data_ids': dataIds,
          'show_notification': '0',
          'message': 'Order received',
        },
      };

      // Call API
      final result = await _ordersRepository.updateOrderApproveFlag(
        orderId: order.orderId,
        approveFlag: OrderApprovalFlag.sendToChecker,
        notification: notificationJsonObject,
      );

      bool success = false;
      result.fold(
        (failure) => _setError(failure.message),
        (_) {
          success = true;
          // Local DB is already updated by the repository method
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

  /// Report single item to admin (creates out of stock entry)
  /// Converted from KMP's reportAdmin (lines 1683-1828)
  Future<bool> reportAdmin(
    OrderSub orderSub, {
    String uuid = '',
  }) async {
    _setLoading(true);
    _clearError();

    try {
      if (_productsRepository == null) {
        _setError('ProductsRepository not available');
        _setLoading(false);
        return false;
      }

      // 1. Get product info for defaultSupplierId and autoSend
      final productResult = await _productsRepository.getProductById(orderSub.orderSubPrdId);
      int defaultSupplierId = -1;
      int autoSendToSupplier = 0;
      
      productResult.fold(
        (_) {},
        (product) {
          if (product != null) {
            defaultSupplierId = product.default_supp_id;
            autoSendToSupplier = (defaultSupplierId != -1) ? product.auto_sendto_supplier_flag : 0;
          }
        },
      );

      final subFlag = (autoSendToSupplier == 1) ? 1 : 0;

      // 2. Generate UUID if not provided (matching KMP line 1533-1534)
      String finalUuid = uuid;
      if (finalUuid.isEmpty) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final deviceToken = await StorageHelper.getDeviceToken();
        final userId = await StorageHelper.getUserId();
        finalUuid = '$timestamp$deviceToken$userId${orderSub.orderSubId}';
      }

      // 3. Get current date/time in DB format
      final now = DateTime.now();
      final dateTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      // 4. Create OutOfStockMaster (matching KMP lines 1695-1717)
      final oospMaster = OutOfStock(
        id: 0,
        outosOrderSubId: orderSub.orderSubId,
        outosCustId: orderSub.orderSubCustId,
        outosSalesManId: orderSub.orderSubSalesmanId,
        outosStockKeeperId: orderSub.orderSubStockKeeperId,
        outosDateAndTime: orderSub.orderSubDateTime,
        outosProdId: orderSub.orderSubPrdId,
        outosUnitId: orderSub.orderSubUnitId,
        outosCarId: orderSub.orderSubCarId,
        outosQty: orderSub.orderSubQty - orderSub.orderSubAvailableQty,
        outosAvailableQty: orderSub.orderSubQty - orderSub.orderSubAvailableQty,
        outosUnitBaseQty: orderSub.orderSubUnitBaseQty,
        outosNote: orderSub.orderSubNote ?? '',
        outosNarration: orderSub.orderSubNarration ?? '',
        outosIsCompleatedFlag: 0,
        outosFlag: 1,
        uuid: finalUuid,
        createdAt: dateTimeStr,
        updatedAt: dateTimeStr,
      );

      // 5. Create OutOfStockProducts (matching KMP lines 1718-1745)
      final oosp = OutOfStockSub(
        id: 0,
        outosSubOutosId: 0,
        outosSubOrderSubId: orderSub.orderSubId,
        outosSubCustId: orderSub.orderSubCustId,
        outosSubSalesManId: orderSub.orderSubSalesmanId,
        outosSubStockKeeperId: orderSub.orderSubStockKeeperId,
        outosSubDateAndTime: orderSub.orderSubDateTime,
        outosSubSuppId: defaultSupplierId,
        outosSubProdId: orderSub.orderSubPrdId,
        outosSubUnitId: orderSub.orderSubUnitId,
        outosSubCarId: orderSub.orderSubCarId,
        outosSubRate: orderSub.orderSubRate,
        outosSubUpdatedRate: orderSub.orderSubUpdateRate,
        outosSubQty: orderSub.orderSubQty - orderSub.orderSubAvailableQty,
        outosSubAvailableQty: orderSub.orderSubQty - orderSub.orderSubAvailableQty,
        outosSubUnitBaseQty: orderSub.orderSubUnitBaseQty,
        outosSubNote: '',
        outosSubNarration: orderSub.orderSubNarration ?? '',
        outosSubStatusFlag: subFlag,
        outosSubIsCheckedFlag: 0,
        outosSubFlag: 1,
        uuid: finalUuid,
        createdAt: dateTimeStr,
        updatedAt: dateTimeStr,
      );

      // 6. Call API (matching KMP lines 1754-1827)
      // Note: Endpoint doesn't support notification payload, so we send it separately
      final result = await _outOfStockRepository.createOutOfStock(
        OutOfStock(
          id: 0,
          outosOrderSubId: oospMaster.outosOrderSubId,
          outosCustId: oospMaster.outosCustId,
          outosSalesManId: oospMaster.outosSalesManId,
          outosStockKeeperId: oospMaster.outosStockKeeperId,
          outosDateAndTime: oospMaster.outosDateAndTime,
          outosProdId: oospMaster.outosProdId,
          outosUnitId: oospMaster.outosUnitId,
          outosCarId: oospMaster.outosCarId,
          outosQty: oospMaster.outosQty,
          outosAvailableQty: oospMaster.outosAvailableQty,
          outosUnitBaseQty: oospMaster.outosUnitBaseQty,
          outosNote: '',
          outosNarration: oospMaster.outosNarration,
          outosIsCompleatedFlag: 0,
          outosFlag: 1,
          uuid: finalUuid,
          createdAt: dateTimeStr,
          updatedAt: dateTimeStr,
          items: [oosp],
        ),
      );

      return await result.fold(
        (failure) async {
          _setError(failure.message);
          _setLoading(false);
          return false;
        },
        (outOfStock) async {
          // 7. Store sub items in local DB with current DB format dates and isViewed=1
          // KMP uses getDBFormatDateTime() when storing from API response (lines 1780-1781, 1811-1812)
          // KMP sets isViewed=1 for reportAdmin (lines 1785, 1816)
          final now = DateTime.now();
          final dateTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

          // Update master with current DB format dates and isViewed=1 (matching KMP lines 1780-1781, 1785)
          final masterToStore = OutOfStock(
            id: outOfStock.id,
            outosOrderSubId: outOfStock.outosOrderSubId,
            outosCustId: outOfStock.outosCustId,
            outosSalesManId: outOfStock.outosSalesManId,
            outosStockKeeperId: outOfStock.outosStockKeeperId,
            outosDateAndTime: outOfStock.outosDateAndTime,
            outosProdId: outOfStock.outosProdId,
            outosUnitId: outOfStock.outosUnitId,
            outosCarId: outOfStock.outosCarId,
            outosQty: outOfStock.outosQty,
            outosAvailableQty: outOfStock.outosAvailableQty,
            outosUnitBaseQty: outOfStock.outosUnitBaseQty,
            outosNote: outOfStock.outosNote,
            outosNarration: outOfStock.outosNarration,
            outosIsCompleatedFlag: outOfStock.outosIsCompleatedFlag,
            outosFlag: outOfStock.outosFlag,
            uuid: outOfStock.uuid,
            createdAt: dateTimeStr, // Use current DB format (matching KMP line 1780)
            updatedAt: dateTimeStr, // Use current DB format (matching KMP line 1781)
            items: outOfStock.items,
          );

          // Re-store master with isViewed=1 (matching KMP line 1785)
          await _outOfStockRepository.addOutOfStockMaster(masterToStore, isViewed: 1);

          // Store sub items with API dates and isViewed=1 (matching KMP lines 1811-1812, 1816)
          // Note: KMP uses created_at and updated_at from API for sub items (not getDBFormatDateTime)
          if (outOfStock.items != null) {
            for (final sub in outOfStock.items!) {
              // Use API dates for sub items (matching KMP lines 1811-1812)
              await _outOfStockRepository.addOutOfStockProduct(sub, isViewed: 1);
            }
          }

          // 8. Send push notification separately (endpoint doesn't support notification payload)
          // Build user IDs list for admins (matching KMP lines 1746-1753)
          final adminsResult = await _usersRepository.getUsersByCategory(1);
          final List<Map<String, dynamic>> userIds = [];
          adminsResult.fold(
            (_){},
            (admins)async{
              for (final admin in admins){
                userIds.add({
                  'user_id': admin.userId,
                  'silent_push': 0, // Matching KMP: PushUserData(it.userId, 0)
                });
              }
            },
          );

          // Send notification with empty data_ids (matching KMP pattern)
          // Fire-and-forget: don't await, just trigger in background
          _pushNotificationSender.sendPushNotification(
            dataIds: [PushData(table: 12, id: outOfStock.items![0].outOfStockSubId)], // Empty array as per KMP pattern
            message: 'Product out of stock reported',
            customUserIds: userIds,
          ).catchError((e) {
            developer.log('OrdersProvider: Error sending push notification in reportAdmin: $e');
          });

          // 9. Optimistically update OrderSub flag to "reported" for immediate UI feedback
          // This matches the pattern in reportAllAdmin (line 2158-2161)
          // The server will also update the flag, but this provides immediate feedback
          await _ordersRepository.updateOrderSubFlag(
            orderSubId: orderSub.orderSubId,
            flag: OrderSubFlag.reported,
          );

          // Note: KMP's reportAdmin does NOT update order flag (only reportAllAdmin does)
          // However, we update it optimistically for better UX
          _setLoading(false);
          return true;
        },
      );
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Report all items to admin (batch creates out of stock entries)
  /// Converted from KMP's reportAllAdmin (lines 1516-1681)
  Future<bool> reportAllAdmin() async {
    _setLoading(true);
    _clearError();

    try {
      if (_productsRepository == null) {
        _setError('ProductsRepository not available');
        _setLoading(false);
        return false;
      }

      // 1. Build out of stock maps (matching KMP lines 1520-1590)
      final Map<OutOfStock, OutOfStockSub> outOfStocks = {};
      final stopwatch = Stopwatch()..start();

      for (final item in _orderDetailItems) {
        if (item.orderSub.orderSubOrdrFlag == OrderSubFlag.outOfStock) {
          final orderSub = item.orderSub;

          // Get product info
          final productResult = await _productsRepository.getProductById(orderSub.orderSubPrdId);
          int defaultSupplierId = -1;
          int autoSendToSupplier = 0;

          productResult.fold(
            (_) {},
            (product) {
              if (product != null) {
                defaultSupplierId = product.default_supp_id;
                autoSendToSupplier = (defaultSupplierId != -1) ? product.auto_sendto_supplier_flag : 0;
              }
            },
          );

          final subFlag = (autoSendToSupplier == 1) ? 1 : 0;

          // Generate UUID (matching KMP line 1533-1534)
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final deviceToken = await StorageHelper.getDeviceToken();
          final userId = await StorageHelper.getUserId();
          final finalUuid = '$timestamp$deviceToken$userId${orderSub.orderSubId}';

          // Get current date/time
          final now = DateTime.now();
          final dateTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

          // Create OutOfStockMaster (matching KMP lines 1535-1557)
          final oospMaster = OutOfStock(
            id: 0,
            outosOrderSubId: orderSub.orderSubId,
            outosCustId: orderSub.orderSubCustId,
            outosSalesManId: orderSub.orderSubSalesmanId,
            outosStockKeeperId: orderSub.orderSubStockKeeperId,
            outosDateAndTime: orderSub.orderSubDateTime,
            outosProdId: orderSub.orderSubPrdId,
            outosUnitId: orderSub.orderSubUnitId,
            outosCarId: orderSub.orderSubCarId,
            outosQty: orderSub.orderSubQty - orderSub.orderSubAvailableQty,
            outosAvailableQty: orderSub.orderSubQty - orderSub.orderSubAvailableQty,
            outosUnitBaseQty: orderSub.orderSubUnitBaseQty,
            outosNote: '',
            outosNarration: orderSub.orderSubNarration ?? '',
            outosIsCompleatedFlag: 0,
            outosFlag: 1,
            uuid: finalUuid,
            createdAt: dateTimeStr,
            updatedAt: dateTimeStr,
          );

          // Create OutOfStockProducts (matching KMP lines 1558-1585)
          final oosp = OutOfStockSub(
            id: 0,
            outosSubOutosId: 0,
            outosSubOrderSubId: orderSub.orderSubId,
            outosSubCustId: orderSub.orderSubCustId,
            outosSubSalesManId: orderSub.orderSubSalesmanId,
            outosSubStockKeeperId: orderSub.orderSubStockKeeperId,
            outosSubDateAndTime: orderSub.orderSubDateTime,
            outosSubSuppId: defaultSupplierId,
            outosSubProdId: orderSub.orderSubPrdId,
            outosSubUnitId: orderSub.orderSubUnitId,
            outosSubCarId: orderSub.orderSubCarId,
            outosSubRate: orderSub.orderSubRate,
            outosSubUpdatedRate: orderSub.orderSubUpdateRate,
            outosSubQty: orderSub.orderSubQty - orderSub.orderSubAvailableQty,
            outosSubAvailableQty: orderSub.orderSubQty - orderSub.orderSubAvailableQty,
            outosSubUnitBaseQty: orderSub.orderSubUnitBaseQty,
            outosSubNote: '',
            outosSubNarration: orderSub.orderSubNarration ?? '',
            outosSubStatusFlag: subFlag,
            outosSubIsCheckedFlag: 0,
            outosSubFlag: 1,
            uuid: finalUuid,
            createdAt: dateTimeStr,
            updatedAt: dateTimeStr,
          );

          outOfStocks[oospMaster] = oosp;
        }
      }

      // Delay matching time taken (matching KMP line 1592)
      stopwatch.stop();
      if (stopwatch.elapsedMilliseconds > 0) {
        await Future.delayed(Duration(milliseconds: stopwatch.elapsedMilliseconds));
      }

      // 2. Call API (matching KMP lines 1601-1679)
      // Note: Endpoint doesn't support notification payload, so we send it separately
      final mastersList = outOfStocks.keys.toList();
      final subsList = outOfStocks.values.toList();

      final result = await _outOfStockRepository.createOutOfStockAll(
        outOfStockMasters: mastersList,
        outOfStockSubs: subsList,
      );

      return await result.fold(
        (failure) async {
          _setError(failure.message);
          _setLoading(false);
          return false;
        },
        (outOfStockList) async {
          // 3. Update flags and reload order details (matching KMP lines 1610-1674)
          // Note: Records are already stored in createOutOfStockAll with correct dates and isViewed
          for (int index = 0; index < outOfStockList.length; index++) {
            final outOfStock = outOfStockList[index];

            // Update order sub flag to 4 (reported) - matching KMP line 1672
            await _ordersRepository.updateOrderSubFlag(
              orderSubId: outOfStock.outosOrderSubId,
              flag: 4, // Reported flag
            );

            // On last item, reload order details (matching KMP line 1675-1677)
            if (index == outOfStockList.length - 1) {
              if (_orderDetails != null) {
                await loadOrderDetails(_orderDetails!.order.orderId);
              }
            }
          }

          // 4. Send push notification separately (endpoint doesn't support notification payload)
          // Build user IDs list for admins (matching KMP lines 1593-1600)
          final adminsResult = await _usersRepository.getUsersByCategory(1);
          final List<Map<String, dynamic>> userIds = [];
          adminsResult.fold(
            (_) {},
            (admins)async{
              for (final admin in admins) {
                userIds.add({
                  'user_id': admin.userId,
                  'silent_push': 0, // Matching KMP: PushUserData(it.userId, 0)
                });
              }
            },
          );

          // Send notification with empty data_ids (matching KMP pattern)
          // Fire-and-forget: don't await, just trigger in background
          _pushNotificationSender.sendPushNotification(
            dataIds: [], // Empty array as per KMP pattern
            message: 'Product out of stock reported',
            customUserIds: userIds,
          ).catchError((e) {
            developer.log('OrdersProvider: Error sending push notification in reportAllAdmin: $e');
          });

          _setLoading(false);
          return true;
        },
      );
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ============================================================================
  // Checker Order Details Methods
  // ============================================================================

  /// Delete temp order subs (orderFlag = 0) for checker discard flow
  Future<bool> deleteTempOrderSubs(int orderId) async {
    final result = await _ordersRepository.deleteTempOrderSubs(orderId);
    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (_) => success = true,
    );
    return success;
  }

  /// Submit checked report (checker role)
  Future<bool> sendCheckedReport({
    required Map<int, double> updatedQtyMap,
    required Map<int, String> noteMap,
    Map<int, String> imageMap = const {}, // orderSubId -> base64 data URI
  }) async {
    if (_orderDetails == null) {
      _setError('Order not loaded');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      final order = _orderDetails!.order;

      final orderSubsResult = await _ordersRepository.getAllOrderSubAndDetails(order.orderId);
      if (orderSubsResult.isLeft) {
        _setError(orderSubsResult.left.message);
        _setLoading(false);
        return false;
      }

      final tempSubsResult = await _ordersRepository.getTempOrderSubAndDetails(order.orderId);
      if (tempSubsResult.isLeft) {
        _setError(tempSubsResult.left.message);
        _setLoading(false);
        return false;
      }

      final orderSubs = orderSubsResult.right;
      final tempSubs = tempSubsResult.right;

      final currentUserId = await StorageHelper.getUserId();
      final notificationIds = await _pushNotificationBuilder.buildOrderNotificationList(
        currentUserId: currentUserId,
        checkerId: order.orderCheckerId,
        billerId: order.orderBillerId,
        includeStorekeepers: true,
        includeCheckers: true,
        includeBillers: true,
      );

      if (order.orderSalesmanId != -1) {
        notificationIds.add({
          'user_id': order.orderSalesmanId,
          'silent_push': 0,
        });
      }

      final notificationPayload = {
        'ids': notificationIds,
        'data_message': 'Order checked and completed',
        'data': {
          'data_ids': [
            {'table': 8, 'id': order.orderId},
          ],
          'show_notification': '0',
          'message': 'Order checked and completed',
        },
      };

      final itemsPayload = <Map<String, dynamic>>[];

      for (final detail in orderSubs) {
        itemsPayload.add(
          _buildCheckerItemPayload(
            detail: detail,
            updatedQtyMap: updatedQtyMap,
            noteMap: noteMap,
            imageMap: imageMap,
            markAsReplaced: _replacedOrderSubIds.containsKey(detail.orderSub.orderSubId),
          ),
        );
      }

      for (final detail in tempSubs) {
        itemsPayload.add(
          _buildCheckerTempItemPayload(
            detail: detail,
            updatedQtyMap: updatedQtyMap,
            noteMap: noteMap,
            imageMap: imageMap,
          ),
        );
      }

      final payload = {
        'order_id': order.orderId,
        'uuid': order.uuid,
        'order_cust_id': order.orderCustId,
        'order_cust_name': order.orderCustName,
        'order_salesman_id': order.orderSalesmanId,
        'order_stock_keeper_id': order.orderStockKeeperId,
        'order_biller_id': order.orderBillerId == -1 ? 0 : order.orderBillerId,
        'order_checker_id': order.orderCheckerId,
        'order_date_time': order.orderDateTime,
        'order_total': order.orderTotal,
        'order_freight_charge': order.orderFreightCharge,
        'order_note': order.orderNote ?? '',
        'order_approve_flag': OrderApprovalFlag.completed,
        'items': itemsPayload,
        'notification': notificationPayload,
      };

      final result = await _ordersRepository.updateOrderWithCustomPayload(payload);

      bool success = false;
      result.fold(
        (failure) => _setError(failure.message),
        (_) => success = true,
      );

      _setLoading(false);
      if (success) {
        await loadOrderDetails(order.orderId);
        // Refresh order list to update status in the list view
        loadOrders();
      }
      return success;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Map<String, dynamic> _buildCheckerItemPayload({
    required OrderSubWithDetails detail,
    required Map<int, double> updatedQtyMap,
    required Map<int, String> noteMap,
    Map<int, String> imageMap = const {},
    bool markAsReplaced = false,
  }) {
    final sub = detail.orderSub;
    double qty = sub.orderSubQty;
    double availableQty = sub.orderSubAvailableQty;
    int orderFlag = sub.orderSubOrdrFlag;
    String note = noteMap[sub.orderSubId]?.trim().isNotEmpty == true ? noteMap[sub.orderSubId]!.trim() : (sub.orderSubNote ?? '');

    if (markAsReplaced) {
      orderFlag = OrderSubFlag.replaced;
    } else if (updatedQtyMap.containsKey(sub.orderSubId)) {
      final newQty = updatedQtyMap[sub.orderSubId] ?? 0.0;
      final message = newQty == 0
          ? 'Checker cancelled Item(qty : ${qty.toStringAsFixed(2)})'
          : 'Checker changed Item quantity (${qty.toStringAsFixed(2)} -> ${newQty.toStringAsFixed(2)})';
      note = _appendCheckerNote(note, message);
      qty = newQty;
      availableQty = 0.0;
      orderFlag = OrderSubFlag.inStock;
    }

    final payload = {
      'order_sub_id': sub.orderSubId,
      'order_sub_prd_id': sub.orderSubPrdId,
      'order_sub_unit_id': sub.orderSubUnitId,
      'order_sub_car_id': sub.orderSubCarId,
      'order_sub_rate': sub.orderSubRate,
      'order_sub_date_time': sub.orderSubDateTime,
      'order_sub_update_rate': sub.orderSubUpdateRate,
      'order_sub_qty': qty,
      'order_sub_available_qty': availableQty,
      'order_sub_unit_base_qty': sub.orderSubUnitBaseQty,
      'order_sub_ordr_flag': orderFlag,
      'order_sub_is_checked_flag': 1,
      'order_sub_note': note,
      'order_sub_narration': sub.orderSubNarration ?? '',
    };
    
    // Add checker_image if image is provided for this order sub
    if (imageMap.containsKey(sub.orderSubId) && imageMap[sub.orderSubId]!.isNotEmpty) {
      payload['checker_image'] = imageMap[sub.orderSubId]!;
    }
    
    return payload;
  }

  Map<String, dynamic> _buildCheckerTempItemPayload({
    required OrderSubWithDetails detail,
    required Map<int, double> updatedQtyMap,
    required Map<int, String> noteMap,
    Map<int, String> imageMap = const {},
  }) {
    final sub = detail.orderSub;
    double qty = sub.orderSubQty;
    double availableQty = sub.orderSubAvailableQty;
    int orderFlag = sub.orderSubOrdrFlag;
    String note = noteMap[sub.orderSubId]?.trim().isNotEmpty == true ? noteMap[sub.orderSubId]!.trim() : (sub.orderSubNote ?? '');

    if (updatedQtyMap.containsKey(sub.orderSubId)) {
      qty = updatedQtyMap[sub.orderSubId] ?? 0.0;
      availableQty = 0.0;
      orderFlag = OrderSubFlag.inStock;
    }

    final payload = {
      'order_sub_id': sub.orderSubId,
      'order_sub_prd_id': sub.orderSubPrdId,
      'order_sub_unit_id': sub.orderSubUnitId,
      'order_sub_car_id': sub.orderSubCarId,
      'order_sub_rate': sub.orderSubRate,
      'order_sub_date_time': sub.orderSubDateTime,
      'order_sub_update_rate': sub.orderSubUpdateRate,
      'order_sub_qty': qty,
      'order_sub_available_qty': availableQty,
      'order_sub_unit_base_qty': sub.orderSubUnitBaseQty,
      'order_sub_ordr_flag': orderFlag,
      'order_sub_is_checked_flag': 1,
      'order_sub_note': note,
      'order_sub_narration': sub.orderSubNarration ?? '',
    };
    
    // Add checker_image if image is provided for this order sub
    if (imageMap.containsKey(sub.orderSubId) && imageMap[sub.orderSubId]!.isNotEmpty) {
      payload['checker_image'] = imageMap[sub.orderSubId]!;
    }
    
    return payload;
  }

  String _appendCheckerNote(String existingNote, String message) {
    if (existingNote.isEmpty) {
      return message;
    }
    if (existingNote.contains(ApiConfig.noteSplitDel)) {
      return '$existingNote$message';
    }
    return '$existingNote${ApiConfig.noteSplitDel}$message';
  }

  /// Claim an order as storekeeper (when tapped in list)
  /// Matches KMP's OrderViewModel.updateStoreKeeper (lines 2137-2170)
  Future<bool> claimOrderAsStorekeeper({
    required int orderId,
    required int storekeeperId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // 1. Get admins (category 1) - matches KMP line 2141
      final adminsResult = await _usersRepository.getUsersByCategory(1);
      if (adminsResult.isLeft) {
        _setError('Failed to get admins: ${adminsResult.left.message}');
        _setLoading(false);
        return false;
      }

      // 2. Get storekeepers (category 2) - matches KMP line 2142
      final storekeepersResult = await _usersRepository.getUsersByCategory(2);
      if (storekeepersResult.isLeft) {
        _setError('Failed to get storekeepers: ${storekeepersResult.left.message}');
        _setLoading(false);
        return false;
      }

      // 3. Build user IDs list - matches KMP lines 2143-2151
      final List<Map<String, dynamic>> userIds = [];
      
      // Add all admins
      for (final admin in adminsResult.right) {
        userIds.add({
          'user_id': admin.userId ?? -1,
          'silent_push': 1,
        });
      }
      
      // Add all storekeepers except the current one (the one claiming)
      for (final storekeeper in storekeepersResult.right) {
        if (storekeeper.userId != storekeeperId) {
          userIds.add({
            'user_id': storekeeper.userId ?? -1,
            'silent_push': 1,
          });
        }
      }

      // 4. Build data IDs - matches KMP line 2153-2154
      // NotificationId.updateStoreKeeper = 21
      final dataIds = [
        PushData(table: NotificationId.updateStoreKeeper, id: orderId),
      ];

      // 5. Build notification JSON - matches KMP line 2155
      final notification = {
        'ids': userIds,
        'data_message': 'Store keeper opened',
        'data': {
          'data_ids': dataIds.map((pushData) => pushData.toJson()).toList(),
          'show_notification': 0, // Silent push
          'message': 'Store keeper opened',
        },
      };

      // 6. Call repository with notification - matches KMP lines 2156-2169
      final result = await _ordersRepository.updateOrderStoreKeeper(
        orderId: orderId,
        storekeeperId: storekeeperId,
        notification: notification,
      );

      return result.fold(
        (failure) {
          _setError(failure.message);
          _setLoading(false);
          return false;
        },
        (_) {
          // Refresh orders to reflect new storekeeper assignment
          loadOrders();
          _setLoading(false);
          return true;
        },
      );
    } catch (e) {
      _setError('Error claiming order: $e');
      _setLoading(false);
      return false;
    }
  }


  /// Claim an order as checker (when tapped in list)
  /// Matches KMP's OrderViewModel.changeToChecking (lines 2010-2050)
  Future<bool> claimOrderAsChecker({
    required int orderId,
    required int checkerId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Get the order first
      final orderResult = await _ordersRepository.getOrderById(orderId);
      if (orderResult.isLeft) {
        _setError('Failed to get order: ${orderResult.left.message}');
        _setLoading(false);
        return false;
      }

      final order = orderResult.right;
      if (order == null) {
        _setError('Order not found');
        _setLoading(false);
        return false;
      }

      // Use sendToBillerOrChecker with isBiller: false and approvalFlag
      // This matches KMP's changeToChecking which calls updateOrderApproveFlag
      final success = await sendToBillerOrChecker(
        isBiller: false,
        userId: checkerId,
        order: order,
        approvalFlag: OrderApprovalFlag.checkerIsChecking,
      );

      if (success) {
        // Refresh orders to reflect new checker assignment
        loadOrders();
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _setError('Error claiming order as checker: $e');
      _setLoading(false);
      return false;
    }
  }

}

