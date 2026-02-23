import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/toast_helper.dart';
import 'package:schedule_frontend_flutter/utils/order_flags.dart';
import '../../provider/orders_provider.dart';
import '../../provider/products_provider.dart';
import '../../../models/order_sub_with_details.dart';
import '../../../models/order_api.dart';
import '../customers/customers_screen.dart';
import '../products/products_screen.dart';
import 'add_product_to_order_dialog.dart';
import '../../common_widgets/small_product_image.dart';

/// Create Order Screen
/// Allows creating new orders with customer selection, products, and notes
/// Converted from KMP's CreateOrderScreen.kt
class CreateOrderScreen extends StatefulWidget {
  final String? orderId; // If provided, loads draft order
  final int? customerId; // If provided, automatically selects this customer
  final String? customerName; // Customer name (required if customerId is provided)

  const CreateOrderScreen({
    super.key,
    this.orderId,
    this.customerId,
    this.customerName,
  });

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _freightChargeController = TextEditingController(text: '0.00');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrder();
    });
  }

  Future<void> _loadOrder() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
       
      // Load draft order (only when explicitly editing a draft via orderId)
      await ordersProvider.getDraftOrder(int.parse(widget.orderId!));
      if (ordersProvider.orderMaster != null) {
        _noteController.text = ordersProvider.orderMaster!.orderNote ?? '';
        _freightChargeController.text = ordersProvider.orderMaster!.orderFreightCharge.toStringAsFixed(2);
      }
    } else {
      // Creating a NEW order - always start completely fresh
      // Skip loading any existing orders (temp or draft)
      // Just create a new temp order directly
      await ordersProvider.createTempOrder();
      
      if (ordersProvider.orderMaster != null) {
        _noteController.text = ordersProvider.orderMaster!.orderNote ?? '';
      }
    }
    
    // If customerId is provided, automatically set the customer AFTER order is loaded
    // This ensures _orderMaster is not null when updateCustomer is called
    // This matches KMP's behavior when clicking order icon from customers screen
    if (widget.customerId != null && widget.customerName != null) {
      // Only update customer if order doesn't already have a customer set
      // This prevents overwriting an existing customer selection
      if (ordersProvider.orderMaster?.orderCustId == -1) {
        await ordersProvider.updateCustomer(widget.customerId!, widget.customerName!);
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _freightChargeController.dispose();
    super.dispose();
  }

  double _calculateTotal(OrdersProvider ordersProvider) {
    double total = 0.0;
    for (final item in ordersProvider.orderSubsWithDetails) {
      // Formula matches KMP: updateRate * (unitBaseQty * quantity)
      total += item.orderSub.orderSubUpdateRate * (item.orderSub.orderSubQty);
    }
    final freight = double.tryParse(_freightChargeController.text) ?? 0.0;
    return total + freight;
  }

  /// Shows confirmation dialog and cancels order if user confirms
  /// Matching KMP's EditOrder Cancel Order flow
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

  Future<void> _saveAsDraft() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    if (ordersProvider.orderMaster == null) {
      _showError('Unknown error occurred');
      return;
    }

    // Update note first
    await ordersProvider.updateOrderNote(_noteController.text);

    final total = _calculateTotal(ordersProvider);
    final freight = double.tryParse(_freightChargeController.text) ?? 0.0;

    final success = await ordersProvider.saveAsDraft(freight, total);
    if (success) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      _showError(ordersProvider.errorMessage ?? 'Failed to save draft');
    }
  }

  Future<void> _sendOrder() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    if (ordersProvider.orderMaster == null) {
      ToastHelper.show('Unknown error occured');
      // _showError('Unknown error occurred');
      return;
    }

    if (ordersProvider.orderMaster!.orderCustId == -1) {
      ToastHelper.showWarning('Please Select a customer!');
      // _showError('Please Select a customer!');
      return;
    }

    // Update note first
    await ordersProvider.updateOrderNote(_noteController.text);

    final total = _calculateTotal(ordersProvider);
    final freight = double.tryParse(_freightChargeController.text) ?? 0.0;

    // Send order with -1 for storekeeperId (no specific storekeeper assigned)
    // All storekeepers get notified, any one can accept it later
    // Matches KMP's CreateOrderScreen.kt line 354: sendOrder(..., -1, ...)
    final success = await ordersProvider.sendOrder(freight, total, -1);
    if (success) {
      // Delete temp order and subs (matches KMP line 362)
      await ordersProvider.deleteOrderAndSub();
      ToastHelper.showSuccess('Order sent successfully');
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      ToastHelper.showError(ordersProvider.errorMessage ?? 'Failed to send order');
    }
  }
  
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _selectCustomer() {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    if (ordersProvider.orderMaster == null) {
      ToastHelper.showError('Order not loaded');
      // _showError('Order not loaded');
      return;
    }

    // Navigate to customer selection screen
    // Converted from KMP's selectCustomer callback (BaseScreen.kt line 439-441)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomersScreen(
          orderId: ordersProvider.orderMaster!.id.toString(),
        ),
      ),
    );
    // .then((_) {
    //   // Refresh order subs after customer selection
    //   if (mounted) {
    //     ordersProvider.getAllOrderSubAndDetails();
    //   }
    // });
  }

  void _addProduct() {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    if (ordersProvider.orderMaster == null) {
      ToastHelper.showError('Order not loaded');
      // _showError('Order not loaded');
      return;
    }

    // Navigate to product selection screen
    // Converted from KMP's addProduct callback (BaseScreen.kt line 444-446)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductsScreen(
          orderId: ordersProvider.orderMaster!.id.toString(),
          orderSubId: '',
          isOutOfStock: false,
        ),
      ),
    ).then((_) {
      // Refresh order subs after product is added
      if (mounted) {
        ordersProvider.getAllOrderSubAndDetails();
      }
    });
  }

  void _editProduct(OrderSubWithDetails item) async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final productsProvider = Provider.of<ProductsProvider>(context, listen: false);
    
    if (ordersProvider.orderMaster == null) {
      ToastHelper.showError('Order not loaded');
      return;
    }

    // Load the product by ID
    final product = await productsProvider.loadProductById(item.orderSub.orderSubPrdId);
    if (product == null) {
      ToastHelper.showError('Product not found');
      return;
    }

    // Show bottom sheet for editing
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => AddProductToOrderDialog(
          product: product,
          orderId: ordersProvider.orderMaster!.id.toString(),
          orderSub: item.orderSub, // Pass existing orderSub for edit mode
          onSave: (rate, quantity, narration, unitId, {bool replace = false}) async {
            // Update the order sub
            final updatedOrderSub = OrderSub(
              id: item.orderSub.id, // Keep local DB ID
              orderSubId: item.orderSub.orderSubId, // Keep server ID
              orderSubOrdrInvId: item.orderSub.orderSubOrdrInvId,
              orderSubOrdrId: item.orderSub.orderSubOrdrId,
              orderSubCustId: item.orderSub.orderSubCustId,
              orderSubSalesmanId: item.orderSub.orderSubSalesmanId,
              orderSubStockKeeperId: item.orderSub.orderSubStockKeeperId,
              orderSubDateTime: item.orderSub.orderSubDateTime,
              orderSubPrdId: item.orderSub.orderSubPrdId, // Keep product ID
              orderSubUnitId: unitId, // Updated unit
              orderSubCarId: item.orderSub.orderSubCarId,
              orderSubRate: item.orderSub.orderSubRate, // Keep original rate
              orderSubUpdateRate: rate, // Updated rate
              orderSubQty: quantity, // Updated quantity
              orderSubAvailableQty: item.orderSub.orderSubAvailableQty,
              orderSubUnitBaseQty: item.orderSub.orderSubUnitBaseQty,
              orderSubNote: item.orderSub.orderSubNote,
              orderSubNarration: narration, // Updated narration
              orderSubOrdrFlag: item.orderSub.orderSubOrdrFlag,
              orderSubIsCheckedFlag: item.orderSub.orderSubIsCheckedFlag,
              orderSubFlag: item.orderSub.orderSubFlag,
              createdAt: item.orderSub.createdAt,
              updatedAt: DateTime.now().toIso8601String(),
              checkerImages: item.orderSub.checkerImages,
              suggestions: item.orderSub.suggestions, // Preserve suggestions
            );

            // Update order sub in local DB only (no API call)
            // Server update happens when "Check Stock" is clicked
            final success = await ordersProvider.addOrderSub(updatedOrderSub);
            if (success) {
              Navigator.pop(context); // Close bottom sheet
              await ordersProvider.getAllOrderSubAndDetails(); // Refresh list
              if (mounted) {
                ToastHelper.showSuccess('Item updated successfully');
              }
            } else {
              if (mounted) {
                ToastHelper.showError(ordersProvider.errorMessage ?? 'Failed to update item');
              }
            }
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
        
        // Check if there are any changes (items added, customer selected, etc.)
        final hasChanges = ordersProvider.orderSubsWithDetails.isNotEmpty ||
            (ordersProvider.orderMaster?.orderCustId != -1) ||
            (_noteController.text.trim().isNotEmpty);
        
        // If no changes, allow back navigation without dialog
        if (!hasChanges) {
          return true;
        }
        
        // Show dialog with Save/Discard options
        final result = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Save Order?'),
            content: const Text('You have unsaved changes. What would you like to do?'),
            actions: [
              // Cancel - stay on screen
              TextButton(
                onPressed: () => Navigator.of(context).pop('cancel'),
                child: const Text('Cancel'),
              ),
              // Discard - delete order and go back
              TextButton(
                onPressed: () async {
                  final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
                  final success = await ordersProvider.deleteOrderAndSub();
                  if (context.mounted && success) {
                    Navigator.of(context).pop('discard');
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Discard'),
              ),
              // Save as Draft - save and go back
              ElevatedButton(
                onPressed: () async {
                  final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
                  
                  // Update note first
                  await ordersProvider.updateOrderNote(_noteController.text);
                  
                  final total = _calculateTotal(ordersProvider);
                  final freight = double.tryParse(_freightChargeController.text) ?? 0.0;
                  
                  final success = await ordersProvider.saveAsDraft(freight, total);
                  if (context.mounted && success) {
                    Navigator.of(context).pop('save');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save as Draft'),
              ),
            ],
          ),
        );

        // Return true to allow navigation if user chose save or discard
        return result == 'save' || result == 'discard';
      },
      child: Consumer<OrdersProvider>(
        builder: (context, ordersProvider, _) {
          final orderMaster = ordersProvider.orderMaster;
          final canCancel = widget.orderId != null &&
              widget.orderId!.isNotEmpty &&
              orderMaster != null &&
              orderMaster.orderApproveFlag != OrderApprovalFlag.sendToStorekeeper &&
              orderMaster.orderApproveFlag != OrderApprovalFlag.completed &&
              orderMaster.orderApproveFlag != OrderApprovalFlag.cancelled;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Create Order'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              actions: [
                if (canCancel)
                  TextButton.icon(
                    onPressed: () => _handleCancelOrder(context, orderMaster, ordersProvider),
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                    label: const Text(
                      'Cancel Order',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            body: _buildCreateOrderBody(context, ordersProvider),
          );
        },
      ),
    );
  }

  Widget _buildCreateOrderBody(BuildContext context, OrdersProvider ordersProvider) {
    return Consumer<OrdersProvider>(
          builder: (context, ordersProvider, child) {
            if (ordersProvider.isLoading && ordersProvider.orderMaster == null) {
              return const Center(child: CircularProgressIndicator());
            }
      
            final orderMaster = ordersProvider.orderMaster;
            if (orderMaster == null) {
              return const Center(child: Text('Failed to load order'));
            }
      
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        // Customer Selection
                        const Text(
                          'Customer',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: _selectCustomer,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: 
                            widget.customerName != null ? Text(
                              ordersProvider.customerName,
                              style: const TextStyle(fontSize: 16),
                            ):Text(
                              ordersProvider.customerName,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Note Field
                        const Text(
                          'Note',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _noteController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(color: Colors.blue),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
      
                        // Add Items Button
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: _addProduct,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Add Items'),
                          ),
                        ),
                        const SizedBox(height: 16),
      
                        // Items List
                        if (ordersProvider.orderSubsWithDetails.isNotEmpty) ...[
                          const Text(
                            'Items',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...ordersProvider.orderSubsWithDetails.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return _OrderItemCard(
                              key: ValueKey('${item.orderSub.orderSubId}_$index'),
                              slNo: index + 1,
                              item: item,
                              onDelete: () {
                                final orderSubId = item.orderSub.orderSubId;
                                ordersProvider.removeOrderSubOptimistically(orderSubId);
                                ordersProvider.deleteOrderSub(orderSubId).then((success) {
                                  if (success) {
                                    ordersProvider.getAllOrderSubAndDetails();
                                  }
                                });
                              },
                              onTap: () {
                                // Show edit bottom sheet instead of navigating to products page
                                _editProduct(item);
                              },
                            );
                          }),
                        ],
                        // Spacer for bottom bar
                        if (ordersProvider.orderSubsWithDetails.isNotEmpty)
                          const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
      
                // Bottom Bar with Total and Actions (only shown if items exist)
                if (ordersProvider.orderSubsWithDetails.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: Container(
                    // height: 140,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _freightChargeController,
                                decoration: const InputDecoration(
                                  labelText: 'Freight Charge',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                onChanged: (value) {
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text('Total: '),
                            Text(
                              _calculateTotal(ordersProvider).toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saveAsDraft,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Save as Draft'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: ordersProvider.isLoading ? null : _sendOrder,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: ordersProvider.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Check Stock'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
  }
}

/// Order Item Card with Swipe-to-Delete
/// Matches KMP's CreateOrderScreen item display layout
/// Converted from KMP's OrderItemCard composable
class _OrderItemCard extends StatelessWidget {
  final int slNo;
  final OrderSubWithDetails item;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _OrderItemCard({
    super.key,
    required this.slNo,
    required this.item,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 32),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 24,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image and item number with product name
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
                            '#$slNo  ${item.productName ?? 'Unknown Product'}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          if (item.productCode?.isNotEmpty == true)
                            Text(
                              'Code: ${item.productCode!}',
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
                // Narration (if not empty)
                if (item.orderSub.orderSubNarration != null &&
                    item.orderSub.orderSubNarration!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        'Narration: ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        item.orderSub.orderSubNarration!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                // Row 1: brand, SubBrand, Qty label
                Row(
                  children: [
                    const Text(
                      'brand: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.productBrand ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const Text(
                      'SubBrand: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.productSubBrand ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const Text(
                      'Qty',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Row 2: unit, Rate, quantity (bold)
                Row(
                  children: [
                    const Text(
                      'unit: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.unitDispName ?? item.unitName ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const Text(
                      'Rate: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.orderSub.orderSubUpdateRate.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Text(
                      item.orderSub.orderSubQty.toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

