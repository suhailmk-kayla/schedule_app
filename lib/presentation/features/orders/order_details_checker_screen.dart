import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/toast_helper.dart';

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
  final Map<int, String> _imageMap = {}; // orderSubId -> base64 data URI
  final Set<int> _checkedItems = {};
  final ImagePicker _imagePicker = ImagePicker();

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
    _imageMap.clear();
    _checkedItems.clear();

    for (final item in items) {
      final id = item.orderSub.orderSubId;
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

  Future<void> _handleSubmit(
    OrdersProvider provider,
    List<OrderItemDetail> items,
  ) async {
    if (!_isSubmissionEnabled(items) || _isSubmitting) {
      ToastHelper.showWarning('Please check all items before submitting');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final success = await provider.sendCheckedReport(
      updatedQtyMap: _qtyChanges,
      noteMap: _noteChanges,
      imageMap: _imageMap,
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      ToastHelper.showSuccess('Order submitted successfully');
      Navigator.pop(context);
    } else {
      ToastHelper.showError(provider.errorMessage ?? 'Failed to submit order');
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

  Future<void> _pickImage(int orderSubId) async {
    try {
      // Show dialog to choose source
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        // Determine image type from file extension
        final extension = image.path.split('.').last.toLowerCase();
        final mimeType = extension == 'png' 
            ? 'image/png' 
            : extension == 'jpg' || extension == 'jpeg'
                ? 'image/jpeg'
                : 'image/jpeg'; // default to jpeg
        
        // Convert to base64 with data URI format
        final base64String = base64Encode(bytes);
        final dataUri = 'data:$mimeType;base64,$base64String';
        
        setState(() {
          _imageMap[orderSubId] = dataUri;
        });
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError('Failed to pick image: $e');
      }
    }
  }

  void _removeImage(int orderSubId) {
    setState(() {
      _imageMap.remove(orderSubId);
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
            ordersProvider.orderDetailItems,
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
              final id = item.orderSub.orderSubId;
              
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
                  imageDataUri: _imageMap[id],
                  onImagePick: () => _pickImage(id),
                  onImageRemove: () => _removeImage(id),
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
    List<OrderItemDetail> items,
    bool isEnabled,
  ) {
    if (order == null) return null;

    final shouldShowButton = order.orderApproveFlag != OrderApprovalFlag.completed &&
        order.orderApproveFlag != OrderApprovalFlag.cancelled;

    // Calculate total price for in-stock items only (excludes out-of-stock items)
    final inStockTotal = _calculateInStockTotal(items);
    final finalTotal = inStockTotal + order.orderFreightCharge;

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
                    finalTotal.toString(),
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
  final String? imageDataUri;
  final VoidCallback onImagePick;
  final VoidCallback onImageRemove;

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
    this.imageDataUri,
    required this.onImagePick,
    required this.onImageRemove,
  });

  /// Calculate price for this item
  /// Uses updateRate * qty (or availableQty for out of stock items)
  double _calculateItemPrice(OrderSub orderSub) {
    final flag = orderSub.orderSubOrdrFlag;
    final qty = flag > OrderSubFlag.inStock
        ? orderSub.orderSubAvailableQty
        : orderSub.orderSubQty;
    return orderSub.orderSubUpdateRate * qty;
  }

  @override
  Widget build(BuildContext context) {
    final flag = item.orderSub.orderSubOrdrFlag;
    final isOutOfStock = flag > OrderSubFlag.inStock;
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
            const SizedBox(height: 4),
            // Price row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Price: ',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Text(
                  _calculateItemPrice(item.orderSub).toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
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
            if (!disableEditing) ...[
              const SizedBox(height: 8),
              // Image upload button - disabled for out-of-stock products
              OutlinedButton.icon(
                onPressed: isOutOfStock ? null : onImagePick,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Upload Image'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              // Image preview if image is selected
              if (imageDataUri != null) ...[
                const SizedBox(height: 8),
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(imageDataUri!.split(',').last),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.error, color: Colors.red),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          padding: const EdgeInsets.all(4),
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onImageRemove,
                      ),
                    ),
                  ],
                ),
              ],
            ],
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

