import 'package:flutter/material.dart';
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
import '../products/products_screen.dart';
import '../../common_widgets/small_product_image.dart';

/// Order Details Screen for Storekeeper Role
/// Converted from KMP's OrderDetailsStorekeeper.kt
/// Handles order checking, notes, available quantities, out of stock flags, and suggestions
class OrderDetailsStorekeeperScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailsStorekeeperScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailsStorekeeperScreen> createState() =>
      _OrderDetailsStorekeeperScreenState();
}

class _OrderDetailsStorekeeperScreenState
    extends State<OrderDetailsStorekeeperScreen> {
  final Map<int, String> _noteMap = {};
  final Map<int, String> _availableQtyMap = {};
  // Stock selection per orderSubId:
  // - null  => not selected yet
  // - false => Available
  // - true  => Out Of Stock
  final Map<int, bool?> _stockSelectionMap = {};
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    
    // Load order details
    await ordersProvider.loadOrderDetails(widget.orderId);
    
    // Update process flag to mark order as viewed
    // Note: isProcessFinish is a database field, not in Order API model
    // We'll update it regardless - the repository method handles it
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
        // Handle notification trigger
        if (notificationManager.notificationTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ordersProvider.loadOrderDetails(widget.orderId);
            notificationManager.resetTrigger();
          });
        }

        // Handle storekeeper already checking trigger
        if (notificationManager.storekeeperAlreadyCheckingTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final order = ordersProvider.orderDetails;
            if (order != null &&
                notificationManager.orderId == order.order.orderId) {
              _showStorekeeperCheckingDialog(context, notificationManager);
            } else {
              notificationManager.resetStorekeeperAlreadyCheckingTrigger();
            }
          });
        }

        final order = ordersProvider.orderDetails;
        final isLoading = ordersProvider.orderDetailsLoading && !_didInit;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Order Details'),
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
            final bar = _buildBottomBar(context, ordersProvider, order);
            return bar != null ? SafeArea(top: false, child: bar) : null;
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              ordersProvider.orderDetailsError!,
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
                  order: order,
                  noteMap: _noteMap,
                  availableQtyMap: _availableQtyMap,
                  stockSelectionMap: _stockSelectionMap,
                  onNoteChanged: (orderSubId, note) {
                    setState(() {
                      _noteMap[orderSubId] = note;
                    });
                  },
                  onAvailableQtyChanged: (orderSubId, qty) {
                    setState(() {
                      _availableQtyMap[orderSubId] = qty;
                    });
                  },
                  onStockSelectionChanged: (orderSubId, isOutOfStock) {
                    setState(() {
                      _stockSelectionMap[orderSubId] = isOutOfStock;
                    });
                  },
                  onPackedChanged: (orderSubId, isPacked, quantity) {
                    final ordersProvider =
                        Provider.of<OrdersProvider>(context, listen: false);
                    if (isPacked) {
                       ordersProvider.addPackedSub(
                        orderSubId: orderSubId,
                        quantity: quantity,
                      );


                    } else {
                      ordersProvider.deletePackedSub(orderSubId);
                    }
                  },
                  onAddSuggestion: (orderSub) {
                    _selectProductForSuggestion(
                      context,
                      ordersProvider: ordersProvider,
                      orderSub: orderSub,
                    );
                  },
                ),
              );
            }),
          ],
          const SizedBox(height: 80), // Space for bottom bar
        ],
      ),
    );
  }

  Widget? _buildBottomBar(
    BuildContext context,
    OrdersProvider ordersProvider,
    OrderWithName? orderWithName,
  ) {
    if (orderWithName == null) return null;
    if (orderWithName.order.orderApproveFlag !=
        OrderApprovalFlag.sendToStorekeeper) {
      return null;
    }
    if (ordersProvider.orderDetailItems.isEmpty) return null;

    // Bottom bar should only be visible after storekeeper selects Available/Out of Stock
    // for every unchecked item.
    final List<OrderItemDetail> itemsToCheck = ordersProvider.orderDetailItems
        .where((item) => item.orderSub.orderSubIsCheckedFlag != 1)
        .toList();

    final bool allSelected = itemsToCheck.isEmpty
        ? true
        : itemsToCheck.every(
            (item) => _stockSelectionMap[item.orderSub.orderSubId] != null,
          );

    if (!allSelected) return null;

    // Convert selections into the provider's expected outOfStockList payload
    final List<int> outOfStockList = itemsToCheck
        .where((item) => _stockSelectionMap[item.orderSub.orderSubId] == true)
        .map((item) => item.orderSub.orderSubId)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () =>
                  _handleSaveAsDraft(context, ordersProvider, outOfStockList),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black),
              ),
              child: const Text(
                'Save as Draft',
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () =>
                  _handleInformUpdates(context, ordersProvider, outOfStockList),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: const Text(
                'Inform Updates',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveAsDraft(
    BuildContext context,
    OrdersProvider ordersProvider,
    List<int> outOfStockList,
  ) async {
    final success = await ordersProvider.saveAsDraftWithNotes(
      noteMap: _noteMap,
      availableQtyMap: _availableQtyMap,
      outOfStockList: outOfStockList,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ordersProvider.errorMessage ?? 'Failed to save draft'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleInformUpdates(
    BuildContext context,
    OrdersProvider ordersProvider,
    List<int> outOfStockList,
  ) async {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    await ordersProvider.informUpdates(
      noteMap: _noteMap,
      availableQtyMap: _availableQtyMap,
      outOfStockList: outOfStockList,
      onFailure: (error) {
        if (!mounted) return;
        Navigator.of(context).pop(); // Close progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      },
      onSuccess: () {
        if (!mounted) return;
        Navigator.of(context).pop(); // Close progress
        Navigator.of(context).pop(); // Close order details
      },
    );
  }

  void _showStorekeeperCheckingDialog(
    BuildContext context,
    NotificationManager notificationManager,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Storekeeper Already Checking'),
        content: const Text('Another storekeeper is checking this order.'),
        actions: [
          TextButton(
            onPressed: () {
              notificationManager.resetStorekeeperAlreadyCheckingTrigger();
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close order details
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  void _selectProductForSuggestion(
    BuildContext context, {
    required OrdersProvider ordersProvider,
    required OrderSub orderSub,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductsScreen(
          selectForSuggestion: true,
          onProductSelected: (product) async {
            // Validate: not same product
            if (product.productId == orderSub.orderSubPrdId) {
              ToastHelper.showInfo('Cannot suggest the same product');
              return;
            }
            // Validate: product not already in order
            final alreadyInOrder = ordersProvider.orderDetailItems.any(
              (item) => item.orderSub.orderSubPrdId == product.productId,
            );
            if (alreadyInOrder) {
              ToastHelper.showInfo('Product already exists in this order');
              return;
            }
            // Allow multiple suggestions for the same product
            final price = product.price;
            final success = await ordersProvider.addSuggestionToOrderSub(
              orderSubId: orderSub.orderSubId,
              productId: product.productId,
              price: price,
              note: '',
            );

            if (!context.mounted) return;

            if (success) {
              // Refresh order details to get updated suggestions list
              await ordersProvider.loadOrderDetails(widget.orderId);
              
              if (!context.mounted) return;
              
              ToastHelper.showInfo('Suggestion added successfully');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ordersProvider.errorMessage ?? 'Failed to add suggestion',
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  final Order order;
  final OrderWithName orderWithName;

  const _OrderHeader({
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

class _OrderItemCard extends StatefulWidget {
  final int index;
  final OrderItemDetail item;
  final Order order;
  final Map<int, String> noteMap;
  final Map<int, String> availableQtyMap;
  final Map<int, bool?> stockSelectionMap;
  final Function(int, String) onNoteChanged;
  final Function(int, String) onAvailableQtyChanged;
  final Function(int, bool) onStockSelectionChanged;
  final Function(int, bool, double) onPackedChanged;
  final Function(OrderSub) onAddSuggestion;

  const _OrderItemCard({
    required this.index,
    required this.item,
    required this.order,
    required this.noteMap,
    required this.availableQtyMap,
    required this.stockSelectionMap,
    required this.onNoteChanged,
    required this.onAvailableQtyChanged,
    required this.onStockSelectionChanged,
    required this.onPackedChanged,
    required this.onAddSuggestion,
  });

  @override
  State<_OrderItemCard> createState() => _OrderItemCardState();
}

class _OrderItemCardState extends State<_OrderItemCard> {
  late TextEditingController _noteController;
  late TextEditingController _availableQtyController;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    final orderSub = widget.item.orderSub;
    final orderSubId = orderSub.orderSubId;

    // Initialize note
    String initialNote = '';
    if (orderSub.orderSubNote != null &&
        orderSub.orderSubNote!.contains(ApiConfig.noteSplitDel)) {
      initialNote = orderSub.orderSubNote!.split(ApiConfig.noteSplitDel).first;
    } else if (orderSub.orderSubNote != null) {
      initialNote = orderSub.orderSubNote!;
    }
    _noteController = TextEditingController(text: initialNote);
    widget.noteMap[orderSubId] = initialNote;

    // Initialize available qty
    _availableQtyController = TextEditingController(
      text: orderSub.orderSubAvailableQty.toString(),
    );
    widget.availableQtyMap[orderSubId] =
        orderSub.orderSubAvailableQty.toString();
    // IMPORTANT: Do NOT pre-select Available/Out Of Stock.
    // Storekeeper must choose explicitly for each unchecked item.
  }

  @override
  void dispose() {
    _noteController.dispose();
    _availableQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderSub = widget.item.orderSub;
    final orderSubId = orderSub.orderSubId;
    final isCheckingOrCancelled = widget.order.orderApproveFlag ==
            OrderApprovalFlag.sendToStorekeeper ||
        widget.order.orderApproveFlag == OrderApprovalFlag.cancelled;
    final isChecked = orderSub.orderSubIsCheckedFlag == 1;
    final note = orderSub.orderSubNote ?? '';
    final hasStatus = note.contains(ApiConfig.noteSplitDel);
    final status = hasStatus
        ? note.split(ApiConfig.noteSplitDel).last
        : (orderSub.orderSubQty == 0 ? 'Order cancelled' : 'Checked');

    // Current selection for this item: null / false (Available) / true (Out Of Stock)
    final bool? selection = widget.stockSelectionMap[orderSubId];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image and name with SL number
            Row(
              children: [
                SmallProductImage(
                  imageUrl: widget.item.productPhoto,
                  size: 40,
                  borderRadius: 5,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${widget.index}  ${widget.item.productName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.item.productCode.isNotEmpty)
                        Text(
                          'Code: ${widget.item.productCode}',
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
            if (orderSub.orderSubNarration?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Narration: ',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  Expanded(
                    child: Text(
                      orderSub.orderSubNarration ?? '',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            // Brand, SubBrand, Qty row
            Row(
              children: [
                Expanded(
                  child: Text(
                    'brand: ${widget.item.productBrand}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
                Expanded(
                  child: Text(
                    'SubBrand: ${widget.item.productSubBrand}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
                Text(
                  'Qty',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
            // Unit, Rate, Qty row
            Row(
              children: [
                Expanded(
                  child: Text(
                    'unit: ${widget.item.unitDisplayName}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Rate: ${orderSub.orderSubUpdateRate}',
                    style: const TextStyle(fontSize: 13),
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
            // Note display (if checked)
            if (isChecked && _noteController.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Note : ',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  Expanded(
                    child: Text(
                      _noteController.text,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            // Suggestions or Status
            const SizedBox(height: 6),
            Row(
              children: [
                if (widget.item.suggestions.isNotEmpty)
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
                          _showSuggestions
                              ? 'Hide Suggestions'
                              : 'Show Suggestions',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 12,
                          ),
                        ),
                        Icon(
                          _showSuggestions
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                  )
                else if (isChecked) ...[
                  if (status == 'Checked')
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check,
                          size: 20,
                          color: Colors.green,
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
                // Stock status or Add Suggestion button
                if (isChecked)
                  _buildStockStatus(orderSub)
                else
                  TextButton.icon(
                    onPressed: () {
                      widget.onAddSuggestion(orderSub);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Add Suggestion',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
              ],
            ),
            // Suggestions list
            if (_showSuggestions && widget.item.suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: widget.item.suggestions.length > 3 ? 150 : null,
                child: widget.item.suggestions.length > 3
                    ? ListView.separated(
                        shrinkWrap: true,
                        itemCount: widget.item.suggestions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final suggestion = widget.item.suggestions[index];
                          return _buildSuggestionChip(suggestion, isChecked);
                        },
                      )
                    : Column(
                        children: widget.item.suggestions.map((suggestion) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: _buildSuggestionChip(suggestion, isChecked),
                          );
                        }).toList(),
                      ),
              ),
            ],
            // Note input and Out of Stock checkboxes (if not checked or has status)
            if (!isChecked || hasStatus) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (value) {
                  widget.onNoteChanged(orderSubId, value);
                },
              ),
              const SizedBox(height: 8),
              // Available / Out Of Stock selection (NO DEFAULT)
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Available',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                      value: false,
                      groupValue: selection,
                      onChanged: (value) {
                        if (value == null) return;
                        widget.onStockSelectionChanged(orderSubId, value);
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Out Of Stock',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                      value: true,
                      groupValue: selection,
                      onChanged: (value) {
                        if (value == null) return;
                        widget.onStockSelectionChanged(orderSubId, value);
                      },
                    ),
                  ),
                ],
              ),
              // Available Qty input (if out of stock)
              if (selection == true && orderSub.orderSubQty > 1) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _availableQtyController,
                    decoration: const InputDecoration(
                      labelText: 'Available Qty',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 14),
                    onChanged: (value) {
                      // Validate numeric input
                      if (value.isEmpty || value == '.') {
                        widget.onAvailableQtyChanged(orderSubId, value);
                        return;
                      }
                      final qty = double.tryParse(value);
                      if (qty != null) {
                        // Ensure available qty is less than ordered qty
                        if (qty >= orderSub.orderSubQty) {
                          _availableQtyController.text =
                              (orderSub.orderSubQty - 1).toString();
                          _availableQtyController.selection =
                              TextSelection.collapsed(
                            offset: _availableQtyController.text.length,
                          );
                          widget.onAvailableQtyChanged(
                            orderSubId,
                            _availableQtyController.text,
                          );
                        } else {
                          widget.onAvailableQtyChanged(orderSubId, value);
                        }
                      }
                    },
                  ),
                ),
              ],
            ],
            // Packed chip (if checked and not cancelled)
            if (isChecked &&
                !hasStatus &&
                !isCheckingOrCancelled &&
                _shouldShowPacking(orderSub)) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilterChip(
                    selected: widget.item.isPacked,
                    onSelected: (selected) {
                      widget.onPackedChanged(
                        orderSubId,
                        selected,
                        orderSub.orderSubQty,
                      );
                    },
                    label: Text(
                      widget.item.isPacked ? 'Packed' : 'Mark as Packed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.item.isPacked
                            ? Colors.white
                            : Theme.of(context).primaryColor,
                      ),
                    ),
                    avatar: widget.item.isPacked
                        ?  Icon(Icons.check, size: 16, color: Colors.white)
                        :  Icon(Icons.shopping_cart,
                            size: 16,
                            color: Colors.blue.shade700),
                                       selectedColor: Colors.green.shade600, // Bright green background when selected
                    checkmarkColor: Colors.white,  
                                        side: BorderSide(
                      color: widget.item.isPacked
                          ? Colors.green.shade700
                          : Colors.blue.shade300,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: widget.item.isPacked ? 2 : 0, //  
                         
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(OrderSubSuggestion suggestion, bool isChecked) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  suggestion.productName?.isNotEmpty == true
                      ? suggestion.productName!
                      : 'Product ${suggestion.prodId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Price: ${suggestion.price}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (suggestion.note?.isNotEmpty == true)
                  Text(
                    suggestion.note!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          if (!isChecked)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                final ordersProvider =
                    Provider.of<OrdersProvider>(context, listen: false);
                ordersProvider.removeSuggestion(suggestion.id);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildStockStatus(OrderSub orderSub) {
    if (orderSub.orderSubOrdrFlag >= OrderSubFlag.outOfStock) {
      final orderFlag = orderSub.orderSubOrdrFlag;
      String statusText;
      Color statusColor;

      if (orderFlag == OrderSubFlag.outOfStock ||
          orderFlag == OrderSubFlag.reported) {
        if (orderSub.orderSubAvailableQty > 0) {
          statusText =
              'Only ${orderSub.orderSubAvailableQty.toInt()} is left';
          statusColor = Colors.red;
        } else {
          statusText = 'Out of Stock';
          statusColor = Colors.red;
        }
        if (orderFlag == OrderSubFlag.reported) {
          statusText = '$statusText (Reported)';
        }
      } else {
        statusText = 'Not Available';
        statusColor = Colors.red;
      }

      return Text(
        statusText,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: statusColor,
        ),
      );
    } else {
      return const Text(
        'Available',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.green,
        ),
      );
    }
  }

  bool _shouldShowPacking(OrderSub orderSub) {
    if (orderSub.orderSubOrdrFlag >= OrderSubFlag.outOfStock) {
      final orderFlag = orderSub.orderSubOrdrFlag;
      if (orderFlag == OrderSubFlag.outOfStock ||
          orderFlag == OrderSubFlag.reported) {
        return orderSub.orderSubAvailableQty > 0;
      } else {
        return false;
      }
    }
    return true;
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
          ],
        ),
      ),
    );
  }
}

