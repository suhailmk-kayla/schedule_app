import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
    
    // Set button visibility
    if (ordersProvider.orderDetails != null) {
      final order = ordersProvider.orderDetails!.order;
      setState(() {
        // Show button if order hasn't been sent to biller or checker yet
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

  Future<void> _refresh() {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    return ordersProvider.loadOrderDetails(widget.orderId);
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

    // Run both operations in parallel since they are independent
    final results = await Future.wait([
      // Send to biller (if not already sent)
      order.orderBillerId == -1
          ? ordersProvider.sendToBillerOrChecker(
              isBiller: true,
              userId: 0, // 0L in KMP means no specific user
              order: order,
            )
          : Future.value(true), // Already sent to biller
      // Send to checker
      ordersProvider.sendToCheckers(order),
    ]);

    if (!mounted) return;

    final billerSuccess = results[0];
    final checkerSuccess = results[1];

    if (billerSuccess && checkerSuccess) {
      setState(() {
        _showSendButton = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order sent to biller and checker')),
      );
      await _refresh();
    } else {
      // Show error message for failed operations
      final errorMessages = <String>[];
      if (!billerSuccess) {
        errorMessages.add('Failed to send to biller');
      }
      if (!checkerSuccess) {
        errorMessages.add('Failed to send to checker');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessages.join(' and ') +
                (ordersProvider.errorMessage != null
                    ? ': ${ordersProvider.errorMessage}'
                    : ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ordersProvider.errorMessage ?? 'Failed to report items'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrdersProvider>(
      builder: (context, ordersProvider, _) {
        final notificationManager = NotificationManager();
        if (notificationManager.notificationTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ordersProvider.loadOrderDetails(widget.orderId);
            notificationManager.resetTrigger();
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

    // Check if any item has orderFlag == 3 (out of stock)
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
                    (order.orderTotal + order.orderFreightCharge).toString(),
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
  final Function(OrderSub) onReportItem;

  const _OrderItemsList({
    required this.items,
    required this.onReportItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
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
            // Product name
            Text(
              '#${widget.index}  ${item.productName}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
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
                                ? suggestion.note!
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
                  if (orderSub.orderSubOrdrFlag == OrderSubFlag.outOfStock)
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

