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

class OrderDetailsCheckerScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailsCheckerScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailsCheckerScreen> createState() =>
      _OrderDetailsCheckerScreenState();
}

class _OrderDetailsCheckerScreenState
    extends State<OrderDetailsCheckerScreen> {
  final Map<int, TextEditingController> _qtyControllers = {};
  final Map<int, TextEditingController> _noteControllers = {};
  final Map<int, double> _qtyChanges = {};
  final Map<int, String> _noteChanges = {};
  final Set<int> _checkedItems = {};

  bool _didInit = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  @override
  void dispose() {
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    await ordersProvider.loadOrderDetails(widget.orderId);
    await ordersProvider.updateProcessFlag(
      orderId: widget.orderId,
      isProcessFinish: 1,
    );

    _initializeControllers(ordersProvider.orderDetailItems);

    if (!mounted) return;
    setState(() {
      _didInit = true;
    });
  }

  Future<void> _refresh() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    await ordersProvider.loadOrderDetails(widget.orderId);
    _initializeControllers(ordersProvider.orderDetailItems);
  }

  void _initializeControllers(List<OrderItemDetail> items) {
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    _qtyControllers.clear();
    _noteControllers.clear();
    _qtyChanges.clear();
    _noteChanges.clear();
    _checkedItems.clear();

    for (final item in items) {
      final id = item.orderSub.id;
      final baseQty = _baseQuantity(item);
      _qtyControllers[id] = TextEditingController(
        text: NumberFormat('##0.###').format(baseQty),
      );
      final note = _baseNote(item.orderSub.orderSubNote);
      _noteControllers[id] = TextEditingController(text: note);
    }
  }

  double _baseQuantity(OrderItemDetail detail) {
    final flag = detail.orderSub.orderSubOrdrFlag;
    if (flag > OrderSubFlag.inStock) {
      return detail.orderSub.orderSubAvailableQty;
    }
    return detail.orderSub.orderSubQty;
  }

  String _baseNote(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (!raw.contains(ApiConfig.noteSplitDel)) {
      return raw;
    }
    return raw.split(ApiConfig.noteSplitDel).first;
  }

  bool _isItemCountable(OrderItemDetail detail) {
    final flag = detail.orderSub.orderSubOrdrFlag;
    if (flag <= OrderSubFlag.inStock) {
      return true;
    }
    return flag >= OrderSubFlag.outOfStock &&
        detail.orderSub.orderSubAvailableQty > 0;
  }

  int _availableItemCount(List<OrderItemDetail> items) {
    return items.where(_isItemCountable).length;
  }

  bool _isSubmissionEnabled(List<OrderItemDetail> items) {
    final totalCount = _availableItemCount(items);
    if (totalCount == 0) {
      return false;
    }
    return _checkedItems.length == totalCount;
  }

  Future<void> _handleSubmit(
    OrdersProvider provider,
    List<OrderItemDetail> items,
  ) async {
    if (!_isSubmissionEnabled(items) || _isSubmitting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please check all items before submitting')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final success = await provider.sendCheckedReport(
      updatedQtyMap: _qtyChanges,
      noteMap: _noteChanges,
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order submitted successfully')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to submit order'),
        ),
      );
    }
  }

  void _handleQtyChanged(int orderSubId, String value, OrderItemDetail detail) {
    final parsed = double.tryParse(value);
    final baseQty = _baseQuantity(detail);
    setState(() {
      if (parsed == null || (parsed - baseQty).abs() < 0.0001) {
        _qtyChanges.remove(orderSubId);
      } else {
        _qtyChanges[orderSubId] = parsed;
      }
    });
  }

  void _handleNoteChanged(int orderSubId, String value, OrderItemDetail detail) {
    final note = value.trim();
    final base = _baseNote(detail.orderSub.orderSubNote);
    setState(() {
      if (note.isEmpty || note == base) {
        _noteChanges.remove(orderSubId);
      } else {
        _noteChanges[orderSubId] = note;
      }
    });
  }

  void _handleCheckedChanged(int orderSubId, bool isChecked) {
    setState(() {
      if (isChecked) {
        _checkedItems.add(orderSubId);
      } else {
        _checkedItems.remove(orderSubId);
      }
    });
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
        final isLoading = ordersProvider.orderDetailsLoading && !_didInit;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Order Details'),
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: _buildBody(
              ordersProvider,
              orderWithName,
              isLoading,
            ),
          ),
          bottomNavigationBar: _buildBottomBar(
            ordersProvider,
            orderWithName?.order,
            _isSubmissionEnabled(ordersProvider.orderDetailItems),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    OrdersProvider provider,
    OrderWithName? orderWithName,
    bool isLoading,
  ) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.orderDetailsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              provider.orderDetailsError!,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (orderWithName == null) {
      return const Center(child: Text('Order not found'));
    }

    final order = orderWithName.order;
    final items = provider.orderDetailItems;
    final replacedMap = provider.replacedOrderSubIds;
    final replacedItems = provider.replacedOrderItems;
    final disableEditing = order.orderApproveFlag == OrderApprovalFlag.completed ||
        order.orderApproveFlag == OrderApprovalFlag.cancelled;

    if (!_didInit) {
      _initializeControllers(items);
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CheckerOrderHeader(order: order, orderWithName: orderWithName),
          const SizedBox(height: 12),
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
          if (order.orderNote?.isNotEmpty == true) ...[
            const Text(
              'Note',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(order.orderNote ?? '', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
          ],
          if (items.isNotEmpty) ...[
            const Text(
              'Items',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final id = item.orderSub.id;
              final qtyController =
                  _qtyControllers[id] ?? TextEditingController(text: _baseQuantity(item).toString());
              _qtyControllers[id] = qtyController;
              final noteController =
                  _noteControllers[id] ?? TextEditingController(text: _baseNote(item.orderSub.orderSubNote));
              _noteControllers[id] = noteController;
              final isReplacement = provider.replacedOrderItems.containsKey(id);
              final isOriginalReplaced = replacedMap.containsKey(id);
              final canCheck = _isItemCountable(item) && !disableEditing;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CheckerOrderItemCard(
                  index: index + 1,
                  item: item,
                  qtyController: qtyController,
                  noteController: noteController,
                  isChecked: _checkedItems.contains(id),
                  disableEditing: disableEditing,
                  isReplacement: isReplacement,
                  isOriginalReplaced: isOriginalReplaced,
                  canCheck: canCheck,
                  onCheckedChanged: (value) => _handleCheckedChanged(id, value),
                  onQtyChanged: (value) => _handleQtyChanged(id, value, item),
                  onNoteChanged: (value) => _handleNoteChanged(id, value, item),
                  replacementItem: replacedItems[id],
                ),
              );
            }),
            const SizedBox(height: 80),
          ] else
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
            ),
        ],
      ),
    );
  }

  Widget? _buildBottomBar(
    OrdersProvider provider,
    Order? order,
    bool isEnabled,
  ) {
    if (order == null) return null;

    final shouldShowButton = order.orderApproveFlag != OrderApprovalFlag.completed &&
        order.orderApproveFlag != OrderApprovalFlag.cancelled;

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
                onPressed: isEnabled && !_isSubmitting
                    ? () => _handleSubmit(provider, provider.orderDetailItems)
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.green,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Submit Checked',
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

class _CheckerOrderHeader extends StatelessWidget {
  final Order order;
  final OrderWithName orderWithName;

  const _CheckerOrderHeader({
    required this.order,
    required this.orderWithName,
  });

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

  const _InfoRow({
    required this.label,
    required this.value,
  });

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

class _CheckerOrderItemCard extends StatelessWidget {
  final int index;
  final OrderItemDetail item;
  final TextEditingController qtyController;
  final TextEditingController noteController;
  final bool isChecked;
  final bool disableEditing;
  final bool isReplacement;
  final bool isOriginalReplaced;
  final bool canCheck;
  final ValueChanged<bool> onCheckedChanged;
  final ValueChanged<String> onQtyChanged;
  final ValueChanged<String> onNoteChanged;
  final OrderItemDetail? replacementItem;

  const _CheckerOrderItemCard({
    required this.index,
    required this.item,
    required this.qtyController,
    required this.noteController,
    required this.isChecked,
    required this.disableEditing,
    required this.isReplacement,
    required this.isOriginalReplaced,
    required this.canCheck,
    required this.onCheckedChanged,
    required this.onQtyChanged,
    required this.onNoteChanged,
    this.replacementItem,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: isChecked,
                  onChanged: canCheck ? (value) => onCheckedChanged(value ?? false) : null,
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
                      if (isReplacement)
                        const Text(
                          'Replacement Item',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else if (isOriginalReplaced)
                        const Text(
                          'Original item replaced',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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
                  qtyLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!disableEditing)
              TextField(
                controller: qtyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: onQtyChanged,
              )
            else
              _KeyValueRow(
                label: 'Quantity',
                value: qtyController.text,
              ),
            const SizedBox(height: 8),
            TextField(
              controller: noteController,
              enabled: !disableEditing,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              minLines: 2,
              maxLines: 3,
              onChanged: onNoteChanged,
            ),
            if (replacementItem != null) ...[
              const SizedBox(height: 12),
              _ReplacementPreview(replacement: replacementItem!),
            ],
          ],
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValueRow({
    required this.label,
    required this.value,
  });

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

class _ReplacementPreview extends StatelessWidget {
  final OrderItemDetail replacement;

  const _ReplacementPreview({required this.replacement});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.orange.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Replacement Item',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
          ),
          Text(
            replacement.productName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          _KeyValueRow(label: 'Brand', value: replacement.productBrand),
          _KeyValueRow(label: 'Sub Brand', value: replacement.productSubBrand),
        ],
      ),
    );
  }
}

