import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/order_api.dart';
import '../../../utils/toast_helper.dart';
import '../../../models/order_item_detail.dart';
import '../../../models/order_with_name.dart';
import '../../../utils/config.dart';
import '../../../utils/order_flags.dart';
import '../../../utils/notification_manager.dart';
import '../../../utils/storage_helper.dart';
import '../../provider/orders_provider.dart';
import '../../common_widgets/small_product_image.dart';

class OrderDetailsScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  int _userType = 0;
  bool _didInit = false;

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
    
    final userType = await StorageHelper.getUserType();
    if (!mounted) return;
    setState(() {
      _userType = userType;
      _didInit = true;
    });
  }

  Future<void> _refresh() {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    return ordersProvider.loadOrderDetails(widget.orderId);
  }

  /// Shows confirmation dialog and cancels order if user confirms
  /// Matching KMP's OrderDetailsAdmin Cancel Order flow
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

  @override
  void dispose() {
    // Provider.of<OrdersProvider>(context, listen: false).clearOrderDetails();
    super.dispose();
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
        final order = ordersProvider.orderDetails;
        final isLoading = ordersProvider.orderDetailsLoading && !_didInit;

        final canCancel = _userType == 1 &&
            order != null &&
            order.order.orderApproveFlag != OrderApprovalFlag.sendToStorekeeper &&
            order.order.orderApproveFlag != OrderApprovalFlag.completed &&
            order.order.orderApproveFlag != OrderApprovalFlag.cancelled;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Order Details'),
            actions: [
              if (canCancel)
                TextButton.icon(
                  onPressed: () => _handleCancelOrder(
                    context,
                    order.order,
                    ordersProvider,
                  ),
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

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OrderHeader(order: order, orderWithName: orderWithName),
          const SizedBox(height: 12),
          if (order.orderApproveFlag == OrderApprovalFlag.cancelled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.red.withOpacity(0.1),
              ),
              child: const Text(
                'Status: Order Cancelled',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
            'Items',
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
            _OrderItemsList(
              userType: _userType,
              items: items,
              replacedIds: ordersProvider.replacedOrderSubIds,
              replacedItems: ordersProvider.replacedOrderItems,
              order: order,
            ),
          if (_shouldShowSummary())
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _BottomSummary(
                freightCharge: order.orderFreightCharge,
                total: _calculateInStockTotal(items),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  bool _shouldShowSummary() =>
      _userType == 1 || _userType == 3 || _userType == 5;

  /// Calculate total price for in-stock items only
  /// Excludes out-of-stock items (flag > OrderSubFlag.inStock)
  double _calculateInStockTotal(List<OrderItemDetail> items) {
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
        _InfoRow(
          label: 'Salesman',
          value: orderWithName.salesManName.isNotEmpty
              ? orderWithName.salesManName
              : (order.orderSalesmanId != -1
                    ? 'Salesman #${order.orderSalesmanId}'
                    : 'N/A'),
        ),
        if (order.orderStockKeeperId != -1)
          _InfoRow(
            label: 'Storekeeper',
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
        if (orderWithName.route.isNotEmpty)
          _InfoRow(label: 'Route', value: orderWithName.route),
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

class _OrderItemsList extends StatelessWidget {
  final int userType;
  final List<OrderItemDetail> items;
  final Map<int, int> replacedIds;
  final Map<int, OrderItemDetail> replacedItems;
  final Order order;

  const _OrderItemsList({
    required this.userType,
    required this.items,
    required this.replacedIds,
    required this.replacedItems,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    int index = 1;

    for (final item in items) {
      final note = item.orderSub.orderSubNote ?? '';
      if (note.contains(ApiConfig.replacedSubDelOrderSubId)) {
        continue;
      }
      if (!_shouldDisplayItem(item)) {
        continue;
      }

      OrderItemDetail? replacement;
      if (replacedIds.containsKey(item.orderSub.orderSubId)) {
        final replacementId = replacedIds[item.orderSub.orderSubId];
        if (replacementId != null) {
          replacement = replacedItems[replacementId];
        }
      }

      final primaryItem = (userType == 7 && replacement != null)
          ? replacement
          : item;

      // Show completed card if order is completed
      if (order.orderApproveFlag == OrderApprovalFlag.completed) {
        widgets.add(
          _CompletedOrderItemCard(
            index: index,
            item: primaryItem,
          ),
        );
        widgets.add(const SizedBox(height: 12));
        index++;
        continue;
      }

      widgets.add(
        _OrderItemCard(
          index: index,
          item: primaryItem,
          replacement: replacement,
          userType: userType,
        ),
      );
      widgets.add(const SizedBox(height: 12));
      index++;
    }

    return Column(children: widgets);
  }

  bool _shouldDisplayItem(OrderItemDetail item) {
    if (userType == 1 || userType == 3) {
      return true;
    }
    final flag = item.orderSub.orderSubFlag;
    if (flag <= OrderSubFlag.inStock) {
      return true;
    }
    if (flag == OrderSubFlag.replaced || flag == OrderSubFlag.cancelled) {
      return true;
    }
    if (flag >= OrderSubFlag.outOfStock &&
        item.orderSub.orderSubAvailableQty > 0) {
      return true;
    }
    return false;
  }
}

class _OrderItemCard extends StatelessWidget {
  final int index;
  final OrderItemDetail item;
  final OrderItemDetail? replacement;
  final int userType;

  const _OrderItemCard({
    required this.index,
    required this.item,
    required this.replacement,
    required this.userType,
  });

  @override
  Widget build(BuildContext context) {
    if (replacement != null) {
      return _ReplacedOrderItemCard(
        index: index,
        original: item,
        replacement: replacement!,
        showRate: userType == 5,
      );
    }

    final qty = _quantityDisplay(item);
    final note = _extractNote(item.orderSub.orderSubNote);
    final status = _extractStatus(item);

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
                        '#$index  ${item.productName}',
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
                if (item.isPacked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Packed',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (item.orderSub.orderSubNarration?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Narration: ',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    Expanded(
                      child: Text(
                        item.orderSub.orderSubNarration ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            _KeyValueRow(label: 'Brand', value: item.productBrand),
            _KeyValueRow(label: 'Sub Brand', value: item.productSubBrand),
            Row(
              children: [
                Expanded(
                  child: _KeyValueRow(
                    label: 'Unit',
                    value: item.unitDisplayName,
                  ),
                ),
                Text(
                  qty,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Note: ',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    Expanded(
                      child: Text(note, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            if (status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: status == 'Checked' ? Colors.green : Colors.red,
                  ),
                ),
              ),
            if (item.suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: item.suggestions
                    .map(
                      (suggestion) => InputChip(
                        label: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              suggestion.note?.isNotEmpty == true
                                  ? suggestion.productName!
                                  : 'Suggestion',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Price: ${suggestion.price}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        onSelected: (_) {},
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _quantityDisplay(OrderItemDetail detail) {
    final flag = detail.orderSub.orderSubFlag;
    final useAvailable = flag > OrderSubFlag.inStock;
    final qty = useAvailable
        ? detail.orderSub.orderSubAvailableQty
        : detail.orderSub.orderSubQty;
    return qty.toString();
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

  String _extractStatus(OrderItemDetail detail) {
    final note = detail.orderSub.orderSubNote ?? '';
    if (note.contains(ApiConfig.noteSplitDel)) {
      return note.split(ApiConfig.noteSplitDel).last;
    }
    if (detail.orderSub.orderSubQty == 0 ||
        detail.orderSub.orderSubFlag == OrderSubFlag.cancelled) {
      return 'This item is cancelled';
    }
    return '';
  }
}

class _ReplacedOrderItemCard extends StatelessWidget {
  final int index;
  final OrderItemDetail original;
  final OrderItemDetail replacement;
  final bool showRate;

  const _ReplacedOrderItemCard({
    required this.index,
    required this.original,
    required this.replacement,
    required this.showRate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _ReplacementSection(
              title: '#$index  ${original.productName}',
              item: original,
              borderColor: Colors.red,
              highlightText: 'Replaced this item with below item',
            ),
            const Icon(Icons.keyboard_arrow_down),
            _ReplacementSection(
              title: replacement.productName,
              item: replacement,
              borderColor: Colors.black,
              showRate: showRate,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplacementSection extends StatelessWidget {
  final String title;
  final OrderItemDetail item;
  final Color borderColor;
  final String? highlightText;
  final bool showRate;

  const _ReplacementSection({
    required this.title,
    required this.item,
    required this.borderColor,
    this.highlightText,
    this.showRate = false,
  });

  @override
  Widget build(BuildContext context) {
    final qty = item.orderSub.orderSubQty.toString();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      elevation: 1,
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
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (item.orderSub.orderSubNarration?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Text(
                      'Narration: ',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    Expanded(
                      child: Text(
                        item.orderSub.orderSubNarration ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            _KeyValueRow(label: 'Brand', value: item.productBrand),
            _KeyValueRow(label: 'Sub Brand', value: item.productSubBrand),
            Row(
              children: [
                Expanded(
                  child: _KeyValueRow(
                    label: 'Unit',
                    value: item.unitDisplayName,
                  ),
                ),
                if (showRate)
                  _KeyValueRow(
                    label: 'Rate',
                    value: item.orderSub.orderSubUpdateRate.toString(),
                  ),
                Text(
                  qty,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (highlightText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  highlightText!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomSummary extends StatelessWidget {
  final double freightCharge;
  final double total;

  const _BottomSummary({required this.freightCharge, required this.total});

  @override
  Widget build(BuildContext context) {
    final combined = freightCharge + total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Freight Charge',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Text(
                  freightCharge.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Text(
                  combined.toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
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
                  child: Text(
                    '#$index  ${item.productName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (item.orderSub.estimatedQty > 0 &&
                (item.orderSub.estimatedQty - item.orderSub.orderSubQty).abs() > 0.001)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
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
          ],
        ),
      ),
    );
  }
}
