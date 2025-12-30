import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/toast_helper.dart';

import '../../../helpers/image_url_handler.dart';
import '../../../models/order_api.dart';
import '../../../models/order_item_detail.dart';
import '../../../models/order_with_name.dart';
import '../../../utils/config.dart';
import '../../../utils/order_flags.dart';
import '../../../utils/notification_manager.dart';
import '../../provider/orders_provider.dart';
import 'create_order_screen.dart';

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
    await ordersProvider.loadOrderDetails(widget.orderId);
    
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

  void _handleEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateOrderScreen(orderId: widget.orderId.toString()),
      ),
    );
  }

  Future<void> _handleSendToBillerAndChecker() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final order = ordersProvider.orderDetails?.order;
    if (order == null) return;

    // Step 1: Send to biller first (just notifications, no flag change, no assignment)
    // This is essentially a "no-op" for local DB - just sends notifications
    bool billerSuccess = true;
    if (order.orderBillerId == -1) {
      billerSuccess = await ordersProvider.sendToBillerOrChecker(
        isBiller: true,
        userId: 0, // 0 means notify all billers, don't assign anyone
        order: order,
      );
      
      if (!billerSuccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send to biller: ${ordersProvider.errorMessage ?? "Unknown error"}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return; // Stop here if biller notification failed
      }
    }

    // Step 2: Send to checker (sets approveFlag to 6)
    // Run sequentially to avoid race conditions and ensure correct flag update
    final checkerSuccess = await ordersProvider.sendToCheckers(order);

    if (!mounted) return;

    if (checkerSuccess) {
      // Refresh order details to get updated state (flag should now be 6)
      await _refresh();
      
      // Update button visibility based on refreshed order state (matching KMP lines 86-87, 107-108, 130-131)
      final refreshedOrder = ordersProvider.orderDetails?.order;
      if (refreshedOrder != null && mounted) {
        setState(() {
          // Hide button if biller is assigned OR order is sent to checker/checker is checking
          // Matching KMP: showSendToBiller = order!!.billerId==-1L
          // Matching KMP: showSendToChecker = (item.order.approveFlag != OrderApprovalFlag.SEND_TO_CHECKER && item.order.approveFlag != OrderApprovalFlag.CHECKER_IS_CHECKING)
          _showSendButton = refreshedOrder.orderBillerId == -1 &&
              refreshedOrder.orderApproveFlag != OrderApprovalFlag.sendToChecker &&
              refreshedOrder.orderApproveFlag != OrderApprovalFlag.checkerIsChecking;
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order sent to biller and checker')),
        );
      }
    } else {
      // Show error if checker assignment failed
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
  }

  Future<void> _handleReportItem(OrderSub orderSub) async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final success = await ordersProvider.reportAdmin(orderSub);

    if (!mounted) return;

    if (success) {
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ordersProvider.errorMessage ?? 'Failed to report item'),
          backgroundColor: Colors.red,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Consumer<OrdersProvider>(
      builder: (context, ordersProvider, _) {
        final notificationManager = NotificationManager();
        if (notificationManager.notificationTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await ordersProvider.loadOrderDetails(widget.orderId);
            notificationManager.resetTrigger();
            
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

        return Scaffold(
          appBar: AppBar(
            title: const Text('Order Details'),
            actions: [
              if (order != null &&
                  order.order.orderApproveFlag !=
                      OrderApprovalFlag.sendToStorekeeper &&
                  order.order.orderApproveFlag != OrderApprovalFlag.completed &&
                  order.order.orderApproveFlag != OrderApprovalFlag.cancelled)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _handleEdit,
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
          bottomNavigationBar: order != null
              ? _buildBottomBar(
                  order.order,
                  ordersProvider,
                )
              : null,
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
    final hasReportItem = items.any(
      (item) => item.orderSub.orderSubOrdrFlag == OrderSubFlag.outOfStock,
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
              if (_isHaveReportItem) ...[
                const Spacer(),
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
            ),

          // Bottom padding for fixed bottom bar
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget? _buildBottomBar(Order order, OrdersProvider ordersProvider) {
    final shouldShowButton = order.orderApproveFlag !=
            OrderApprovalFlag.sendToStorekeeper &&
        order.orderApproveFlag != OrderApprovalFlag.completed &&
        order.orderApproveFlag != OrderApprovalFlag.cancelled &&
        _showSendButton;

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
          if (shouldShowButton) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSendToBillerAndChecker,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
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
            value: orderWithName.billerName.isNotEmpty
                ? orderWithName.billerName
                : 'Biller #${order.orderBillerId}',
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

  const _OrderItemsList({
    required this.items,
    required this.order,
    required this.onReportItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        
        // Show completed card if order is completed
        if (order.orderApproveFlag == OrderApprovalFlag.completed) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CompletedOrderItemCard(
              index: index + 1,
              item: item,
            ),
          );
        }
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _OrderItemCard(
            index: index + 1,
            item: item,
            onReport: () => onReportItem(item.orderSub),
          ),
        );
      }).toList(),
    );
  }
}

class _OrderItemCard extends StatefulWidget {
  final int index;
  final OrderItemDetail item;
  final VoidCallback onReport;

  const _OrderItemCard({
    required this.index,
    required this.item,
    required this.onReport,
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
                  child: item.productPhoto.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.productPhoto,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.image,
                              size: 30,
                              color: Colors.grey,
                            ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.image,
                          size: 30,
                          color: Colors.grey,
                        ),
                ),
                const SizedBox(width: 12),
                // Product name
                Expanded(
                  child: Text(
                    '#${widget.index}  ${item.productName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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

            // Note (if checked)
            if (orderSub.orderSubIsCheckedFlag == 1 && note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
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
                            color: Theme.of(context).primaryColor,
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
                            suggestion.note?.isNotEmpty == true
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
                      onSelected: (_) {},
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
                  if (orderSub.orderSubOrdrFlag == OrderSubFlag.reported)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Reported',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else if (orderSub.orderSubOrdrFlag == OrderSubFlag.outOfStock)
                    ElevatedButton(
                      onPressed: widget.onReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        'Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
    if (orderSub.orderSubOrdrFlag < OrderSubFlag.outOfStock) {
      return (text: 'Available', color: Colors.green);
    }

    final orderFlag = orderSub.orderSubOrdrFlag;
    if (orderFlag == OrderSubFlag.outOfStock || orderFlag == OrderSubFlag.reported) {
      String status;
      if (orderSub.orderSubAvailableQty > 0) {
        status = 'Only ${orderSub.orderSubAvailableQty.toInt()} is left';
      } else {
        status = 'Out of Stock';
      }
      if (orderFlag == OrderSubFlag.reported) {
        status = '$status (Reported)';
      }
      return (text: status, color: Colors.red);
    } else {
      // Not Available
      String status;
      if (orderSub.orderSubAvailableQty > 0) {
        status = '${orderSub.orderSubAvailableQty.toInt()} Not Available';
      } else {
        status = 'Not Available';
      }
      return (text: status, color: Colors.red);
    }
  }
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
            Text(
              '#$index  ${item.productName}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            _InfoRow(label: 'Brand', value: item.productBrand),
            _InfoRow(label: 'Sub Brand', value: item.productSubBrand),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    label: 'Unit',
                    value: item.unitDisplayName,
                  ),
                ),
                Text(
                  qtyLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            // Checker Image (only for completed orders)
            if (item.orderSub.checkerImage != null &&
                item.orderSub.checkerImage!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Checked Image',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              _buildCheckerImage(item.orderSub.checkerImage!),
            ],
          ],
        ),
      ),
    );
  }

  /// Build checker image widget
  /// Handles base64 data URIs and URL paths (local vs production)
  Widget _buildCheckerImage(String imageData) {
    // Check if it's a base64 data URI
    if (imageData.startsWith('data:image')) {
      try {
        final base64String = imageData.split(',').last;
        final imageBytes = base64Decode(base64String);
        return Container(
          width: double.infinity,
          height: 200,
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
        );
      } catch (e) {
        return _buildPlaceholder();
      }
    }

    // It's a URL path - use ImageUrlFixer to clean up the URL
    // (removes /LaravelProject and /public for local dev URLs)
    final imageUrl = ImageUrlFixer.fix(imageData);

    return Container(
      width: double.infinity,
      height: 200,
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
    );
  }

  /// Build placeholder widget for missing images
  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
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
              size: 48,
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

