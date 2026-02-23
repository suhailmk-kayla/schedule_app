import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/presentation/provider/out_of_stock_provider.dart';
import 'package:schedule_frontend_flutter/utils/toast_helper.dart';

import '../../../helpers/image_url_handler.dart';
import '../../../models/order_api.dart';
import '../../../models/order_item_detail.dart';
import '../../../models/order_with_name.dart';
import '../../../utils/config.dart';
import '../../../utils/order_flags.dart';
import '../../../utils/notification_manager.dart';
import '../../provider/orders_provider.dart';
import '../../provider/products_provider.dart';
import '../products/products_screen.dart';
import 'add_product_to_order_dialog.dart';
import '../../common_widgets/small_product_image.dart';

/// Order Details Screen for Salesman
/// Displays order details with salesman-specific features
/// Converted from KMP's OrderDetailsSalesman.kt
class OrderDetailsSalesmanScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailsSalesmanScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailsSalesmanScreen> createState() =>
      _OrderDetailsSalesmanScreenState();
}

class _OrderDetailsSalesmanScreenState
    extends State<OrderDetailsSalesmanScreen> {
  bool _didInit = false;
  bool _showSendButton = true;
  bool _isHaveReportItem = false;
  /// True while "Send to Biller & Checker" is in progress; prevents double-tap.
  bool _isSendingToBillerChecker = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    await ordersProvider.loadOrderDetails(widget.orderId);
    
    // Update process flag to mark order as viewed
    // This ensures the badge count decreases when order is opened
    await ordersProvider.updateProcessFlag(
      orderId: widget.orderId,
      isProcessFinish: 1,
    );
    
    // Set button visibility based on order state (matching KMP lines 86-87, 107-108, 130-131)
    if (ordersProvider.orderDetails != null) {
      final order = ordersProvider.orderDetails!.order;
      setState(() {
        // Matching KMP: showSendToBiller = order!!.billerId==-1L
        // Matching KMP: showSendToChecker = (item.order.approveFlag != OrderApprovalFlag.SEND_TO_CHECKER && item.order.approveFlag != OrderApprovalFlag.CHECKER_IS_CHECKING)
        _showSendButton = order.orderBillerId == -1 &&
            order.orderApproveFlag != OrderApprovalFlag.sendToChecker &&
            order.orderApproveFlag != OrderApprovalFlag.checkerIsChecking;
      });
    }

    if (!mounted) return;
    setState(() {
      _didInit = true;
    });
  }

  Future<void> _refresh() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    // edited by ai on 29-jan-2026 to fix the issue of order details screen showing "Order not found" after Check Stock (use current orderId from provider when available, else widget.orderId)
    final orderIdToLoad = ordersProvider.orderDetails?.order.orderId ?? widget.orderId;
    await ordersProvider.loadOrderDetails(orderIdToLoad);

    // Update button visibility based on refreshed order state (matching KMP lines 86-87, 107-108, 130-131)
    final order = ordersProvider.orderDetails?.order;
    if (order != null && mounted) {
      setState(() {
        // Matching KMP: showSendToBiller = order!!.billerId==-1L
        // Matching KMP: showSendToChecker = (item.order.approveFlag != OrderApprovalFlag.SEND_TO_CHECKER && item.order.approveFlag != OrderApprovalFlag.CHECKER_IS_CHECKING)
        _showSendButton = order.orderBillerId == -1 &&
            order.orderApproveFlag != OrderApprovalFlag.sendToChecker &&
            order.orderApproveFlag != OrderApprovalFlag.checkerIsChecking;
      });
    }
  }

  // void _handleEdit() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) => CreateOrderScreen(orderId: widget.orderId.toString()),
  //     ),
  //   );
  // }

  /// Shows confirmation dialog and cancels order if user confirms
  /// Matching KMP's EditOrder/OrderDetailsSalesman Cancel Order flow
  Future<void> _handleCancelOrder(
    BuildContext context,
    Order order,
    OrdersProvider ordersProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Do you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await ordersProvider.cancelOrder(order);

    if (!mounted) return;

    if (success) {
      ToastHelper.showSuccess('Order cancelled');
      Navigator.pop(context);
    } else {
      ToastHelper.showError(
        ordersProvider.errorMessage ?? 'Failed to cancel order',
      );
    }
  }

  Future<void> _handleSendToBillerAndChecker() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final order = ordersProvider.orderDetails?.order;
    if (order == null) return;

    // Prevent double-tap: block if already sending
    if (_isSendingToBillerChecker) return;

    // Double‑check: block forwarding if ANY item is not in stock
    // (matches UI stock status logic in _getStockStatus)
    final items = ordersProvider.orderDetailItems;
    final hasAnyNotInStock = items.any(
      (item) => item.orderSub.orderSubOrdrFlag >= OrderSubFlag.outOfStock,
    );
    if (hasAnyNotInStock) {
      if (!mounted) return;
      ToastHelper.showInfo(
        'Order cannot be sent. Please ensure all items are in stock.',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSendingToBillerChecker = true);

    try {
      // Step 1: Send to biller first (just notifications, no flag change, no assignment)
      bool billerSuccess = true;
      if (order.orderBillerId == -1) {
        billerSuccess = await ordersProvider.sendToBiller(
          userId: 0,
          order: order,
        );

        if (!billerSuccess) {
          if (!mounted) return;
          ToastHelper.showError('failed to send to biller');
          return;
        }
      }

      // Step 2: Send to checker (sets approveFlag to 6)
      final checkerSuccess = await ordersProvider.sendToCheckers(order);

      if (!mounted) return;

      if (checkerSuccess) {
        await _refresh();

        final refreshedOrder = ordersProvider.orderDetails?.order;
        if (refreshedOrder != null && mounted) {
          setState(() {
            _showSendButton = refreshedOrder.orderBillerId == -1 &&
                refreshedOrder.orderApproveFlag !=
                    OrderApprovalFlag.sendToChecker &&
                refreshedOrder.orderApproveFlag !=
                    OrderApprovalFlag.checkerIsChecking;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order sent to biller and checker')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to send to checker: ${ordersProvider.errorMessage ?? "Unknown error"}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingToBillerChecker = false);
      }
    }
  }

  Future<void> _handleReportItem(OrderSub orderSub) async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final success = await ordersProvider.reportAdmin(orderSub);
    if (!mounted) return;
    if (success) {
      await _refresh();
    } else {
      ToastHelper.showError(ordersProvider.errorMessage ?? 'Failed to report item');
    }
  }

  Future<void> _handleReportAll() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final success = await ordersProvider.reportAllAdmin();

    if (!mounted) return;

    if (success) {
      setState(() {
        _isHaveReportItem = false;
      });
      await _refresh();
    } else {
      ToastHelper.showError(ordersProvider.errorMessage ?? 'Failed to report items');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(ordersProvider.errorMessage ?? 'Failed to report items'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
    }
  }

  /// Check if order has edits (any OrderSub with flag == 0)
  bool _hasEdits(List<OrderItemDetail> items) {
    return items.any((item) => item.orderSub.orderSubFlag == 0);
  }

  /// Handle adding any product to order (plus button)
  Future<void> _handleAddProduct(OrdersProvider ordersProvider) async {
    // Navigate to products screen for selection
    // The ProductsScreen will use addProductToExistingOrder for existing orders
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductsScreen(
          orderId: widget.orderId.toString(),
          orderSubId: '',
          isOutOfStock: false,
        ),
      ),
    ).then((_) {
      // Don't refresh from DB - edits are kept in memory
      // ProductsScreen already updated the in-memory state via addProductToExistingOrder
      // The notifyListeners() call in addProductToExistingOrder already updated the UI
    });
  }

  /// Handle adding suggested product to order (tapping on suggestion)
  Future<void> _handleAddSuggestionToOrder(OrderSubSuggestion suggestion) async {
    final productsProvider = Provider.of<ProductsProvider>(context, listen: false);
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    
    // Find the parent OrderSub that has this suggestion
    final items = ordersProvider.orderDetailItems;
    OrderSub? parentOrderSub;
    try {
      final parentItem = items.firstWhere(
        (item) => item.orderSub.orderSubId == suggestion.orderSubId,
      );
      parentOrderSub = parentItem.orderSub;
    } catch (e) {
      // Parent OrderSub not found
      if (!mounted) return;
      if (mounted) {
         
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Parent order item not found'),
        //     backgroundColor: Colors.red,
        //   ),
        // );
      }
      return;
    }
    
    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Fetch full product details by prodId
      final product = await productsProvider.loadProductByIdWithDetails(suggestion.prodId);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (product == null) {
        if (!mounted) return;
        if (mounted) {
           
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(
          //     content: Text('Product not found'),
          //     backgroundColor: Colors.red,
          //   ),
          // );
        }
        return;
      }

      // Show AddProductToOrderDialog bottom sheet with suggestion price pre-filled
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AddProductToOrderDialog(
          product: product.product,
          orderId: widget.orderId.toString(),
          initialRate: suggestion.price, // Pre-fill with suggestion price
          replaceOrderSub: parentOrderSub, // Pass parent OrderSub for replace option
          onSave: (rate, quantity, narration, unitId, {bool replace = false}) async {
            final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
            
            // Use the new dedicated function for existing orders
            final success = await ordersProvider.addProductToExistingOrder(
              orderId: widget.orderId,
              productId: suggestion.prodId,
              productPrice: suggestion.price, // Use suggestion price as base
              rate: rate,
              quantity: quantity,
              narration: narration,
              unitId: unitId,
              replaceOrderSub: replace ? parentOrderSub : null, // Pass if replace
            );

            if (!mounted) return;
            Navigator.pop(context); // Close dialog

            if (success) {
              // Don't refresh from DB - we're keeping edits in memory
              // The notifyListeners() in addProductToExistingOrder already updated the UI
              if (!mounted) return;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      replace 
                        ? 'Product replaced successfully' 
                        : 'Product added to order successfully',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else {
              if (!mounted) return;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ordersProvider.errorMessage ?? 'Failed to add product to order',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<OrdersProvider,NotificationManager,OutOfStockProvider>(
      builder: (context, ordersProvider, notificationManager, outOfStockProvider, _) {
        if (notificationManager.notificationTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            notificationManager.resetTrigger();
            await ordersProvider.loadOrderDetails(widget.orderId);        
            // Update button visibility after notification refresh (matching KMP lines 86-87)
            final refreshedOrder = ordersProvider.orderDetails?.order;
            if (refreshedOrder != null && mounted) {
              setState(() {
                // Matching KMP: showSendToBiller = order!!.billerId==-1L
                // Matching KMP: showSendToChecker = (item.order.approveFlag != OrderApprovalFlag.SEND_TO_CHECKER && item.order.approveFlag != OrderApprovalFlag.CHECKER_IS_CHECKING)
                _showSendButton = refreshedOrder.orderBillerId == -1 &&
                    refreshedOrder.orderApproveFlag != OrderApprovalFlag.sendToChecker &&
                    refreshedOrder.orderApproveFlag != OrderApprovalFlag.checkerIsChecking;
              });
            }
          });
        }

        final order = ordersProvider.orderDetails;
        final isLoading = ordersProvider.orderDetailsLoading && !_didInit;

        final canCancel = order != null &&
            order.order.orderApproveFlag != OrderApprovalFlag.sendToStorekeeper &&
            order.order.orderApproveFlag != OrderApprovalFlag.completed &&
            order.order.orderApproveFlag != OrderApprovalFlag.cancelled;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Order Details'),
            actions: [
              if (canCancel)
                TextButton.icon(
                  onPressed: () => _handleCancelOrder(context, order.order, ordersProvider),
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                  label: const Text(
                    'Cancel Order',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: _buildBody(
              context,
              ordersProvider: ordersProvider,
              orderWithName: order,
              isLoading: isLoading,
            ),
          ),
          bottomNavigationBar: () {
            if (order == null) return null;
            final bar = _buildBottomBar(
              order.order,
              ordersProvider,
              isSendLoading: _isSendingToBillerChecker || ordersProvider.isLoading,
            );
            return bar != null
                ? SafeArea(top: false, child: bar)
                : null;
          }(),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required OrdersProvider ordersProvider,
    required OrderWithName? orderWithName,
    required bool isLoading,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ordersProvider.orderDetailsError != null) {
      return _ErrorState(
        message: ordersProvider.orderDetailsError!,
        onRetry: _refresh,
      );
    }

    if (orderWithName == null) {
      return const Center(child: Text('Order not found'));
    }

    final order = orderWithName.order;
    final items = ordersProvider.orderDetailItems;

    // Check if any item has orderFlag == 3 (out of stock) and not already reported
    // Around line 452-455, update:
final hasReportItem = items.any(
  (item) => item.orderSub.orderSubOrdrFlag == OrderSubFlag.outOfStock ||
            item.orderSub.orderSubOrdrFlag == OrderSubFlag.notAvailable,
);

    if (hasReportItem != _isHaveReportItem) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isHaveReportItem = hasReportItem;
          });
        }
      });
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OrderHeader(order: order, orderWithName: orderWithName),
          const SizedBox(height: 12),
          
          // "You cannot edit" message
          if (order.orderApproveFlag == OrderApprovalFlag.sendToStorekeeper)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.red.withValues(alpha: 0.1),
              ),
              child: const Text(
                'You cannot edit this order until you receive a response from the storekeeper',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Status messages
          if (order.orderApproveFlag == OrderApprovalFlag.cancelled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.red.withValues(alpha: 0.1),
              ),
              child: const Text(
                'Status : Order Cancelled',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          if (order.orderApproveFlag == OrderApprovalFlag.completed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.green.withValues(alpha: 0.1),
              ),
              child: const Text(
                'Status : Order Completed',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Note
          if (order.orderNote?.isNotEmpty == true) ...[
            const Text(
              'Note',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              order.orderNote ?? '',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
          ],

          // Items section
          Row(
            children: [
              const Text(
                'Items',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              // Plus button to add any product to order
              Visibility(
                visible: order.orderApproveFlag != OrderApprovalFlag.sendToStorekeeper &&
                    order.orderApproveFlag != OrderApprovalFlag.completed &&
                    order.orderApproveFlag != OrderApprovalFlag.cancelled && 
                    order.orderApproveFlag != OrderApprovalFlag.checkerIsChecking
                    && order.orderApproveFlag != OrderApprovalFlag.sendToChecker,
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: Theme.of(context).primaryColor,
                  tooltip: 'Add Product',
                  onPressed: () => _handleAddProduct(ordersProvider),
                ),
              ),
              if (_isHaveReportItem) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleReportAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Report All',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'No items found for this order.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            _OrderItemsList(
              items: items,
              order: order,
              onReportItem: _handleReportItem,
              onAddSuggestion: _handleAddSuggestionToOrder,
              replacedIds: ordersProvider.replacedOrderSubIds,
              replacedItems: ordersProvider.replacedOrderItems,
            ),

          // Bottom padding for fixed bottom bar
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget? _buildBottomBar(
    Order order,
    OrdersProvider ordersProvider, {
    bool isSendLoading = false,
  }) {
    final items = ordersProvider.orderDetailItems;
    final hasEdits = _hasEdits(items);

    final shouldShowButton = order.orderApproveFlag !=
            OrderApprovalFlag.sendToStorekeeper &&
        order.orderApproveFlag != OrderApprovalFlag.completed &&
        order.orderApproveFlag != OrderApprovalFlag.cancelled &&
        _showSendButton;

    // Show "Check Stock" if there are edits, otherwise show "Send to Biller & Checker"
    final showCheckStock = hasEdits && shouldShowButton;
    final showSendToBillerChecker = !hasEdits && shouldShowButton;

    // Block send if ANY item is not in stock (outOfStock, reported, notAvailable, etc.)
    final hasAnyNotInStock = items.any(
      (item) => item.orderSub.orderSubOrdrFlag >= OrderSubFlag.outOfStock,
    );

    // DEBUG: Log bottom bar decision
    developer.log(
      'OrderDetailsSalesman._buildBottomBar: '
      'orderId=${order.orderId}, '
      'hasEdits=$hasEdits, '
      'shouldShowButton=$shouldShowButton, '
      'hasAnyNotInStock=$hasAnyNotInStock, '
      'flags=${items.map((i) => i.orderSub.orderSubOrdrFlag).toList()}, '
      'avail=${items.map((i) => i.orderSub.orderSubAvailableQty).toList()}',
      name: 'OrderDetailsSalesman',
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Freight Charge : ',
                    style: TextStyle(fontSize: 14, color: Colors.black),
                  ),
                  Text(
                    order.orderFreightCharge.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Total : ',
                    style: TextStyle(fontSize: 14, color: Colors.black),
                  ),
                  Text(
                    (order.orderTotal).toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (showCheckStock) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSendLoading ? null : _handleCheckStock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Check Stock',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          if (showSendToBillerChecker) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSendLoading
                    ? null
                    : hasAnyNotInStock
                        ? () {
                            ToastHelper.showInfo(
                              'Order cannot be sent. Please ensure all items are in stock.',
                            );
                          }
                        : _handleSendToBillerAndChecker,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSendLoading
                      ? Colors.grey
                      : hasAnyNotInStock
                          ? Colors.grey
                          : Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: isSendLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Sending...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Send to Biller & Checker',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Handle Check Stock button - Updates order with all items, resets flags, and sends notifications
  Future<void> _handleCheckStock() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final order = ordersProvider.orderDetails?.order;
    if (order == null) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Call checkStock method in OrdersProvider
      final success = await ordersProvider.checkStock(order.orderId);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (success) {
        // Refresh order details
        await _refresh();
        if (!mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (!mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ordersProvider.errorMessage ?? 'Failed to update order',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _OrderHeader extends StatelessWidget {
  final Order order;
  final OrderWithName orderWithName;

  const _OrderHeader({required this.order, required this.orderWithName});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Inv No: ${order.orderInvNo}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Created',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Text(
                  _formatDate(order.orderDateTime),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        _InfoRow(
          label: 'Customer',
          value: orderWithName.customerName.isNotEmpty
              ? orderWithName.customerName
              : order.orderCustName,
        ),
        if (order.orderStockKeeperId != -1)
          _InfoRow(
            label: 'Store keeper',
            value: orderWithName.storeKeeperName.isNotEmpty
                ? orderWithName.storeKeeperName
                : 'Storekeeper #${order.orderStockKeeperId}',
          ),
        if (order.orderBillerId != -1)
          _InfoRow(
            label: 'Biller',
            value: orderWithName.billerName.isNotEmpty&&order.orderBillerId!=-1
                ? orderWithName.billerName
                : 'Not assigned',
          ),
        if (order.orderCheckerId != -1)
          _InfoRow(
            label: 'Checker',
            value: orderWithName.checkerName.isNotEmpty
                ? orderWithName.checkerName
                : 'Checker #${order.orderCheckerId}',
          ),
        _InfoRow(
          label: 'Updated',
          value: _formatDate(order.updatedAt),
        ),
      ],
    );
  }

  static String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    final normalized = raw.replaceAll('T', ' ');
    final formats = [
      DateFormat('yyyy-MM-dd HH:mm:ss'),
      DateFormat('yyyy-MM-dd'),
    ];
    for (final format in formats) {
      try {
        final parsed = format.parse(normalized);
        return DateFormat('dd-MM-yyyy HH:mm').format(parsed);
      } catch (_) {
        // continue
      }
    }
    return raw;
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemsList extends StatelessWidget {
  final List<OrderItemDetail> items;
  final Order order;
  final Function(OrderSub) onReportItem;
  final Function(OrderSubSuggestion) onAddSuggestion;
  final Map<int, int> replacedIds;
  final Map<int, OrderItemDetail> replacedItems;

  const _OrderItemsList({
    required this.items,
    required this.order,
    required this.onReportItem,
    required this.onAddSuggestion,
    required this.replacedIds,
    required this.replacedItems,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    int index = 1;

    for (final item in items) {
      // Check if this item was replaced (for items loaded from DB that have replacements)
      // Note: For in-memory replacements, we replace in place, so no mapping needed
      OrderItemDetail? replacement;
      if (replacedIds.containsKey(item.orderSub.orderSubId)) {
        final replacementId = replacedIds[item.orderSub.orderSubId];
        if (replacementId != null) {
          replacement = replacedItems[replacementId];
        }
      }

      // Use replacement item if available, otherwise use original
      // If item has replacement note but no mapping, it means it was replaced in place - show it directly
      final displayItem = replacement ?? item;
      
      // Show completed card if order is completed
      if (order.orderApproveFlag == OrderApprovalFlag.completed) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CompletedOrderItemCard(
              index: index,
              item: displayItem,
            ),
          ),
        );
        index++;
        continue;
      }
      
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _OrderItemCard(
            index: index,
            item: displayItem,
            onReport: () => onReportItem(displayItem.orderSub),
            onAddSuggestion: onAddSuggestion,
          ),
        ),
      );
      index++;
    }

    return Column(children: widgets);
  }
}

class _OrderItemCard extends StatefulWidget {
  final int index;
  final OrderItemDetail item;
  final VoidCallback onReport;
  final Function(OrderSubSuggestion) onAddSuggestion;

  const _OrderItemCard({
    required this.index,
    required this.item,
    required this.onReport,
    required this.onAddSuggestion,
  });

  @override
  State<_OrderItemCard> createState() => _OrderItemCardState();
}

class _OrderItemCardState extends State<_OrderItemCard> {
  bool _showSuggestions = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final orderSub = item.orderSub;

    // Extract note and status
    final note = _extractNote(orderSub.orderSubNote);
    final status = _extractStatus(orderSub);

    // Stock status
    final stockStatus = _getStockStatus(orderSub);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image and name row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: SmallProductImage(
                    imageUrl: item.productPhoto,
                    size: 40,
                    borderRadius: 5,
                  ),
                ),
                const SizedBox(width: 12),
                // Product name + code
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${widget.index}  ${item.productName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.productCode.isNotEmpty)
                        Text(
                          'Code: ${item.productCode}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Narration
            if (orderSub.orderSubNarration?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(
                    'Narration: ',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Expanded(
                    child: Text(
                      orderSub.orderSubNarration ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],

            // Brand, SubBrand, Qty
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('brand: ', style: TextStyle(fontSize: 14, color: Colors.grey)),
                Expanded(
                  child: Text(
                    item.productBrand,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const Text('SubBrand: ', style: TextStyle(fontSize: 14, color: Colors.grey)),
                Expanded(
                  child: Text(
                    item.productSubBrand,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const Text('Qty', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),

            // Unit, Rate, Qty
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('unit: ', style: TextStyle(fontSize: 14, color: Colors.grey)),
                Expanded(
                  child: Text(
                    item.unitDisplayName,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const Text('Rate: ', style: TextStyle(fontSize: 14, color: Colors.grey)),
                Expanded(
                  child: Text(
                    orderSub.orderSubUpdateRate.toString(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Text(
                  orderSub.orderSubQty.toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // Note and status (if checked)
            if (orderSub.orderSubIsCheckedFlag == 1 && (note.isNotEmpty || status.isNotEmpty)) ...[
              const SizedBox(height: 4),
              if (note.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Note : ',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Expanded(
                      child: Text(
                        note,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              if (status.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status : ',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Expanded(
                      child: Text(
                        status,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ],

            // Suggestions toggle or Status
            const SizedBox(height: 4),
            Row(
              children: [
                if (item.suggestions.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showSuggestions = !_showSuggestions;
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _showSuggestions ? 'Hide Suggestions' : 'Show Suggestions',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                        Icon(
                          _showSuggestions
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Theme.of(context).primaryColor,
                          size: 18,
                        ),
                      ],
                    ),
                  )
                else if (orderSub.orderSubIsCheckedFlag == 1) ...[
                  if (status == 'Checked')
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Checked',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      status,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
                const Spacer(),
                // Stock status
                if (orderSub.orderSubIsCheckedFlag == 1 &&
                    !(orderSub.orderSubNote?.contains(ApiConfig.noteSplitDel) ?? false))
                  Text(
                    stockStatus.text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: stockStatus.color,
                    ),
                  ),
              ],
            ),

            // Suggestions list
            if (_showSuggestions && item.suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...item.suggestions.map((suggestion) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: InputChip(
                      label: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            suggestion.productName?.isNotEmpty == true
                                ? suggestion.productName!
                                : 'Suggestion',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Price : ${suggestion.price}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      onSelected: (_) {
                        // Handle adding suggestion to order
                        widget.onAddSuggestion(suggestion);
                      },
                      deleteIcon: const Icon(Icons.add_circle, size: 18),
                      onDeleted: () {
                        // Same action as onSelected - add to order
                        widget.onAddSuggestion(suggestion);
                      },
                    ),
                  )),
            ],

            // Status and Report button (if checked)
            if (orderSub.orderSubIsCheckedFlag == 1) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (item.suggestions.isNotEmpty) ...[
                    if (status == 'Checked')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Checked',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        status,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                  const Spacer(),
                  // Show "Reported" text if already reported, otherwise show Report button
                  // if (orderSub.orderSubOrdrFlag == OrderSubFlag.reported)
                    // Row(
                    //   mainAxisSize: MainAxisSize.min,
                    //   children: [
                    //     const Icon(
                    //       Icons.check_circle,
                    //       color: Colors.green,
                    //       size: 18,
                    //     ),
                    //     const SizedBox(width: 4),
                    //     const Text(
                    //       'Reported',
                    //       style: TextStyle(
                    //         color: Colors.green,
                    //         fontSize: 14,
                    //         fontWeight: FontWeight.w600,
                    //       ),
                    //     ),
                    //   ],
                    // )
                  // else if (orderSub.orderSubOrdrFlag == OrderSubFlag.outOfStock)
                  //   ElevatedButton(
                  //     onPressed: widget.onReport,
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Colors.red,
                  //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  //     ),
                  //     child: const Text(
                  //       'Report',
                  //       style: TextStyle(
                  //         color: Colors.white,
                  //         fontSize: 14,
                  //         fontWeight: FontWeight.w600,
                  //       ),
                  //     ),
                  //   ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _extractNote(String? note) {
    if (note == null || note.isEmpty) {
      return '';
    }
    if (!note.contains(ApiConfig.noteSplitDel)) {
      return note;
    }
    return note.split(ApiConfig.noteSplitDel).first;
  }

  String _extractStatus(OrderSub orderSub) {
    final note = orderSub.orderSubNote ?? '';
    if (note.contains(ApiConfig.noteSplitDel)) {
      return note.split(ApiConfig.noteSplitDel).last;
    }
    if (orderSub.orderSubQty == 0) {
      return 'Order cancelled';
    }
    return 'Checked';
  }
  
  ({String text, Color color}) _getStockStatus(OrderSub orderSub) {
  final orderFlag = orderSub.orderSubOrdrFlag;

  // DEBUG: Log stock status evaluation inputs
  developer.log(
    'OrderDetailsSalesman._getStockStatus: '
    'orderSubId=${orderSub.orderSubId}, '
    'flag=$orderFlag, '
    'availQty=${orderSub.orderSubAvailableQty}',
    name: 'OrderDetailsSalesman',
  );
  
  // Flag < 3 (inStock = 2, notChecked = 1, newItem = 0) = Available
  if (orderFlag < OrderSubFlag.outOfStock) {
    return (text: 'Available', color: Colors.green);
  }
  
  // Flag == 3 (outOfStock) or 4 (reported)
  if (orderFlag == OrderSubFlag.outOfStock || orderFlag == OrderSubFlag.reported) {
    String status;
    if (orderSub.orderSubAvailableQty > 0) {
      status = 'Only ${orderSub.orderSubAvailableQty.toInt()} is left';
    } else {
      status = 'Out of Stock';
    }
    // Add "(Reported)" suffix if flag is 4
    if (orderFlag == OrderSubFlag.reported) {
      status = '$status (Reported)';
    }
    return (text: status, color: Colors.red);
  }
  
  // Flag == 5 (notAvailable) or other flags
  // Not Available
  String status;
  if (orderSub.orderSubAvailableQty > 0) {
    status = '${orderSub.orderSubAvailableQty.toInt()} Not Available';
  } else {
    status = 'Not Available';
  }
  return (text: status, color: Colors.red);
}

  // ({String text, Color color}) _getStockStatus(OrderSub orderSub) {
  //   if (orderSub.orderSubOrdrFlag < OrderSubFlag.outOfStock) {
  //     return (text: 'Available', color: Colors.green);
  //   }

  //   final orderFlag = orderSub.orderSubOrdrFlag;
  //   if (orderFlag == OrderSubFlag.outOfStock || orderFlag == OrderSubFlag.reported) {
  //     String status;
  //     if (orderSub.orderSubAvailableQty > 0) {
  //       status = 'Only ${orderSub.orderSubAvailableQty.toInt()} is left';
  //     } else {
  //       status = 'Out of Stock';
  //     }
  //     if (orderFlag == OrderSubFlag.reported) {
  //       status = '$status (Reported)';
  //     }
  //     if (orderFlag == OrderSubFlag.inStock) {
  //       status = '$status (Available)';
  //     }
  //     return (text: status, color: Colors.red);
  //   } else {
  //     // Not Available
  //     String status;
  //     if (orderSub.orderSubAvailableQty > 0) {
  //       status = '${orderSub.orderSubAvailableQty.toInt()} Not Available';
  //     } else {
  //       status = 'Not Available';
  //     }
  //     return (text: status, color: Colors.red);
  //   }
  // }

}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                onRetry();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Completed Order Item Card
/// Shows minimal details for completed orders (read-only, no actions)
class _CompletedOrderItemCard extends StatelessWidget {
  final int index;
  final OrderItemDetail item;

  const _CompletedOrderItemCard({
    required this.index,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final flag = item.orderSub.orderSubOrdrFlag;
    final qtyLabel = flag > OrderSubFlag.inStock
        ? item.orderSub.orderSubAvailableQty.toString()
        : item.orderSub.orderSubQty.toString();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SmallProductImage(
                  imageUrl: item.productPhoto,
                  size: 40,
                  borderRadius: 5,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.productName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.productCode.isNotEmpty)
                        Text(
                          'Code: ${item.productCode}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Checker changed quantity (only for completed orders)
            if (item.orderSub.estimatedQty > 0 &&
                (item.orderSub.estimatedQty - item.orderSub.orderSubQty).abs() > 0.001) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(
                  'Checker changed the quantity from ${item.orderSub.estimatedQty.toStringAsFixed(2)} to ${item.orderSub.orderSubQty.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            // Header row with labels
            Row(
              children: [
                Expanded(
                  child: Text(
                    'brand',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(
                    'unit',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(
                    'qty',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Data row with values
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.productBrand,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(
                    item.unitDisplayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(
                    qtyLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Checker Images (only for completed orders)
            if (item.orderSub.checkerImages != null &&
                item.orderSub.checkerImages!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Checked Images',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),

              Row(
                children: [
                  ...item.orderSub.checkerImages!.map((imageUrl) => Padding(
                    padding: const EdgeInsets.only(bottom: 8, right: 8),
                    child: _buildCheckerImage(context, imageUrl),
                  )),
                ],
              ),
              
            ],
          ],
        ),
      ),
    );
  }

  /// Build checker image widget
  /// Handles base64 data URIs and URL paths (local vs production)
  Widget _buildCheckerImage(BuildContext context, String imageData) {
    // Check if it's a base64 data URI
    if (imageData.startsWith('data:image')) {
      try {
        final base64String = imageData.split(',').last;
        final imageBytes = base64Decode(base64String);
        return InkWell(
          onTap: () => _showCheckerImagePreview(context, imageData),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                imageBytes,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder();
                },
              ),
            ),
          ),
        );
      } catch (e) {
        return _buildPlaceholder();
      }
    }

    // It's a URL path - use ImageUrlFixer to clean up the URL
    // (removes /LaravelProject and /public for local dev URLs)
    final imageUrl = ImageUrlFixer.fix(imageData);

    return InkWell(
      onTap: () => _showCheckerImagePreview(context, imageData),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholder();
            },
          ),
        ),
      ),
    );
  }

  /// Show image preview dialog
  /// Handles both base64 data URIs and network URLs
  void _showCheckerImagePreview(BuildContext context, String imageData) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: _buildPreviewImage(imageData),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build preview image widget
  /// Handles both base64 data URIs and network URLs
  Widget _buildPreviewImage(String imageData) {
    // Check if it's a base64 data URI
    if (imageData.startsWith('data:image')) {
      try {
        final base64String = imageData.split(',').last;
        final imageBytes = base64Decode(base64String);
        return Image.memory(
          imageBytes,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.white70,
              size: 48,
            ),
          ),
        );
      } catch (e) {
        return const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.white70,
            size: 48,
          ),
        );
      }
    }

    // It's a URL path - use ImageUrlFixer to clean up the URL
    final imageUrl = ImageUrlFixer.fix(imageData);

    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.white70,
          size: 48,
        ),
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
            ),
          ),
        );
      },
    );
  }

  /// Show image preview dialog
  /// Build placeholder widget for missing images
  Widget _buildPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 50,
              color: Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              'No Image Available',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

