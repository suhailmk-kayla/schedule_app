import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/order_api.dart';
import '../../../models/order_item_detail.dart';
import '../../../models/order_with_name.dart';
import '../../../utils/order_flags.dart';
import '../../../utils/notification_manager.dart';
import '../../../utils/storage_helper.dart';
import '../../provider/orders_provider.dart';

/// Order Details Screen for Biller
/// Displays order details with two tabs: Estimated Bill and Final Bill
class OrderDetailsBillerScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailsBillerScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailsBillerScreen> createState() =>
      _OrderDetailsBillerScreenState();
}

class _OrderDetailsBillerScreenState extends State<OrderDetailsBillerScreen>
    with SingleTickerProviderStateMixin {
  bool _didInit = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Always initialize with 2 tabs
    // Final Bill tab will show a message if order is not completed
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    await ordersProvider.loadOrderDetails(widget.orderId);

    // Update process flag to mark order as viewed
    await ordersProvider.updateProcessFlag(
      orderId: widget.orderId,
      isProcessFinish: 1,
    );

    if (!mounted) return;
    setState(() {
      _didInit = true;
    });
  }

  Future<void> _refresh() {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    return ordersProvider.loadOrderDetails(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<OrdersProvider, NotificationManager>(
      builder: (context, ordersProvider, notificationManager, _) {
        if (notificationManager.notificationTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ordersProvider.loadOrderDetails(widget.orderId);
            notificationManager.resetTrigger();
          });
        }
        final orderWithName = ordersProvider.orderDetails;
        final order = orderWithName?.order;
        final isLoading = ordersProvider.orderDetailsLoading && !_didInit;
        final isCompleted = order?.orderApproveFlag == OrderApprovalFlag.completed;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Order Details'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Estimated Bill'),
                Tab(text: 'Final Bill'),
              ],
            ),
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: _buildBody(
              context,
              ordersProvider: ordersProvider,
              orderWithName: orderWithName,
              isLoading: isLoading,
              isCompleted: isCompleted,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required OrdersProvider ordersProvider,
    required OrderWithName? orderWithName,
    required bool isLoading,
    required bool isCompleted,
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

    // Always show both tabs
    // Final Bill tab will show a message if order is not completed
    return TabBarView(
      controller: _tabController,
      children: [
        // Estimated Bill Tab
        _EstimatedBillTab(
          order: order,
          orderWithName: orderWithName,
          items: items,
        ),
        // Final Bill Tab (shows message if not completed, actual bill if completed)
        _FinalBillTab(
          order: order,
          orderWithName: orderWithName,
          items: items,
        ),
      ],
    );
  }
}

/// Estimated Bill Tab
/// Shows order state when sent to checker/biller (after storekeeper verification)
class _EstimatedBillTab extends StatelessWidget {
  final Order order;
  final OrderWithName orderWithName;
  final List<OrderItemDetail> items;

  const _EstimatedBillTab({
    required this.order,
    required this.orderWithName,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OrderHeader(order: order, orderWithName: orderWithName),
          const SizedBox(height: 12),
          if (order.orderNote?.isNotEmpty == true) ...[
            const Text(
              'Note',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(order.orderNote ?? '', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
          ],
          const Text(
            'Items (Estimated)',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
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
            _EstimatedItemsList(items: items),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _EstimatedSummary(
              freightCharge: order.orderFreightCharge,
              total: _calculateEstimatedTotal(items),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Calculate total price using estimated fields
  double _calculateEstimatedTotal(List<OrderItemDetail> items) {
    double total = 0.0;
    for (final item in items) {
      // Use estimatedTotal if available, otherwise calculate from estimatedQty
      if (item.orderSub.estimatedTotal > 0) {
        total += item.orderSub.estimatedTotal;
      } else if (item.orderSub.estimatedQty > 0) {
        total += item.orderSub.orderSubUpdateRate * item.orderSub.estimatedQty;
      }
    }
    return total;
  }
}

/// Final Bill Tab
/// Shows order state after checker completes (with possible quantity modifications)
/// Only visible when order is completed (flag = 3)
class _FinalBillTab extends StatefulWidget {
  final Order order;
  final OrderWithName orderWithName;
  final List<OrderItemDetail> items;

  const _FinalBillTab({
    required this.order,
    required this.orderWithName,
    required this.items,
  });

  @override
  State<_FinalBillTab> createState() => _FinalBillTabState();
}

class _FinalBillTabState extends State<_FinalBillTab> {
  bool _isMarkingAsBilled = false;

  Future<void> _handleMarkAsBilled(bool? value) async {
    if (value == null || !value) return; // Only handle when checking (not unchecking)
    if (_isMarkingAsBilled) return; // Prevent multiple calls

    setState(() {
      _isMarkingAsBilled = true;
    });

    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final billerId = await StorageHelper.getUserId();

    final success = await ordersProvider.markOrderAsBilled(
      orderId: widget.order.orderId,
      billerId: billerId,
    );

    if (!mounted) return;

    setState(() {
      _isMarkingAsBilled = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ordersProvider.errorMessage ?? 'Failed to mark order as billed',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order marked as billed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if order is completed (flag = 3)
    final isCompleted = widget.order.orderApproveFlag == OrderApprovalFlag.completed;

    if (!isCompleted) {
      // Show message that final bill is not available yet
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OrderHeader(order: widget.order, orderWithName: widget.orderWithName),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 48,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Final Bill Not Available Yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The checker is currently checking the order. The final bill will be available once the order is completed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Order is completed - show final bill
    return Consumer<OrdersProvider>(
      builder: (context, ordersProvider, _) {
        // Get updated order from provider to reflect billed status
        final updatedOrder = ordersProvider.orderDetails?.order ?? widget.order;
        final isBilled = updatedOrder.orderIsBilled == 1;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OrderHeader(order: updatedOrder, orderWithName: widget.orderWithName),
              const SizedBox(height: 12),
              if (updatedOrder.orderNote?.isNotEmpty == true) ...[
                const Text(
                  'Note',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  updatedOrder.orderNote ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
              ],
              // Mark as Billed checkbox
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isBilled
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isBilled ? Colors.green.shade300 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isBilled,
                      onChanged: _isMarkingAsBilled
                          ? null
                          : (value) {
                              if (value == true && !isBilled) {
                                _handleMarkAsBilled(value);
                              }
                            },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mark as Billed',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isBilled ? Colors.green.shade700 : Colors.black87,
                            ),
                          ),
                          if (isBilled)
                            Text(
                              'This order has been marked as billed',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_isMarkingAsBilled)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Items (Final)',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.items.isEmpty)
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
                _FinalItemsList(items: widget.items),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _FinalSummary(
                  freightCharge: updatedOrder.orderFreightCharge,
                  total: _calculateFinalTotal(widget.items),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  /// Calculate total price using final quantities
  double _calculateFinalTotal(List<OrderItemDetail> items) {
    double total = 0.0;
    for (final item in items) {
      final flag = item.orderSub.orderSubOrdrFlag;
      // Only include items that are in stock (flag <= OrderSubFlag.inStock)
      if (flag <= OrderSubFlag.inStock) {
        // Formula: updateRate * quantity
        total += item.orderSub.orderSubUpdateRate * item.orderSub.orderSubQty;
      }
    }
    return total;
  }
}

/// Order Header Widget (shared between tabs)
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
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoRow(
          label: 'Customer',
          value: orderWithName.customerName.isNotEmpty
              ? orderWithName.customerName
              : order.orderCustName,
        ),
        if (order.orderStockKeeperId != -1)
          _InfoRow(
            label: 'Storekeeper',
            value: orderWithName.storeKeeperName.isNotEmpty
                ? orderWithName.storeKeeperName
                : 'Storekeeper #${order.orderStockKeeperId}',
          ),
        if (order.orderCheckerId != -1)
          _InfoRow(
            label: 'Checker',
            value: orderWithName.checkerName.isNotEmpty
                ? orderWithName.checkerName
                : 'Checker #${order.orderCheckerId}',
          ),
        _InfoRow(label: 'Updated', value: _formatDate(order.updatedAt)),
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

/// Estimated Items List
/// Shows items with estimated quantities and totals
class _EstimatedItemsList extends StatelessWidget {
  final List<OrderItemDetail> items;

  const _EstimatedItemsList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _EstimatedItemCard(
            index: index + 1,
            item: item,
          ),
        );
      }).toList(),
    );
  }
}

/// Estimated Item Card
class _EstimatedItemCard extends StatelessWidget {
  final int index;
  final OrderItemDetail item;

  const _EstimatedItemCard({
    required this.index,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final orderSub = item.orderSub;
    // Use estimatedQty, fallback to orderSubQty if estimated is 0
    final qty = orderSub.estimatedQty > 0
        ? orderSub.estimatedQty
        : orderSub.orderSubQty;
    // Use estimatedTotal, fallback to calculation if 0
    final total = orderSub.estimatedTotal > 0
        ? orderSub.estimatedTotal
        : orderSub.orderSubUpdateRate * qty;

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
            _InfoRow(label: 'Unit', value: item.unitDisplayName),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    label: 'Rate',
                    value: orderSub.orderSubUpdateRate.toStringAsFixed(2),
                  ),
                ),
                Text(
                  'Qty: ${qty.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  total.toStringAsFixed(2),
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
      ),
    );
  }
}

/// Final Items List
/// Shows items with final quantities and totals
class _FinalItemsList extends StatelessWidget {
  final List<OrderItemDetail> items;

  const _FinalItemsList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        // Only show items that are in stock or have available quantity
        final flag = item.orderSub.orderSubOrdrFlag;
        if (flag > OrderSubFlag.inStock &&
            item.orderSub.orderSubAvailableQty <= 0) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _FinalItemCard(
            index: index + 1,
            item: item,
          ),
        );
      }).toList(),
    );
  }
}

/// Final Item Card
class _FinalItemCard extends StatelessWidget {
  final int index;
  final OrderItemDetail item;

  const _FinalItemCard({
    required this.index,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final orderSub = item.orderSub;
    final flag = orderSub.orderSubOrdrFlag;
    // Use availableQty if out of stock, otherwise use qty
    final qty = flag > OrderSubFlag.inStock
        ? orderSub.orderSubAvailableQty
        : orderSub.orderSubQty;
    final total = orderSub.orderSubUpdateRate * qty;

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
            _InfoRow(label: 'Unit', value: item.unitDisplayName),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    label: 'Rate',
                    value: orderSub.orderSubUpdateRate.toStringAsFixed(2),
                  ),
                ),
                Text(
                  'Qty: ${qty.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  total.toStringAsFixed(2),
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
      ),
    );
  }
}

/// Estimated Summary Widget
class _EstimatedSummary extends StatelessWidget {
  final double freightCharge;
  final double total;

  const _EstimatedSummary({
    required this.freightCharge,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final grandTotal = total + freightCharge;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal:',
                style: TextStyle(fontSize: 14),
              ),
              Text(
                total.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Freight Charge:',
                style: TextStyle(fontSize: 14),
              ),
              Text(
                freightCharge.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estimated Total:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                grandTotal.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Final Summary Widget
class _FinalSummary extends StatelessWidget {
  final double freightCharge;
  final double total;

  const _FinalSummary({
    required this.freightCharge,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final grandTotal = total + freightCharge;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal:',
                style: TextStyle(fontSize: 14),
              ),
              Text(
                total.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Freight Charge:',
                style: TextStyle(fontSize: 14),
              ),
              Text(
                freightCharge.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Final Total:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                grandTotal.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

