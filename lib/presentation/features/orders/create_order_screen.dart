import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/orders_provider.dart';
import '../../../models/order_sub_with_details.dart';
import '../customers/customers_screen.dart';
import '../products/products_screen.dart';

/// Create Order Screen
/// Allows creating new orders with customer selection, products, and notes
/// Converted from KMP's CreateOrderScreen.kt
class CreateOrderScreen extends StatefulWidget {
  final String? orderId; // If provided, loads draft order

  const CreateOrderScreen({
    super.key,
    this.orderId,
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
      // Load draft order
      await ordersProvider.getDraftOrder(int.parse(widget.orderId!));
      if (ordersProvider.orderMaster != null) {
        _noteController.text = ordersProvider.orderMaster!.orderNote ?? '';
        _freightChargeController.text = ordersProvider.orderMaster!.orderFreightCharge.toStringAsFixed(2);
      }
    } else {
      // Get or create temp order
      await ordersProvider.getTempOrder();
      if (ordersProvider.orderMaster != null) {
        _noteController.text = ordersProvider.orderMaster!.orderNote ?? '';
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
      total += item.orderSub.orderSubUpdateRate * (item.orderSub.orderSubUnitBaseQty * item.orderSub.orderSubQty);
    }
    final freight = double.tryParse(_freightChargeController.text) ?? 0.0;
    return total + freight;
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
      _showError('Unknown error occurred');
      return;
    }

    if (ordersProvider.orderMaster!.orderCustId == -1) {
      _showError('Please Select a customer!');
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
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      _showError(ordersProvider.errorMessage ?? 'Failed to send order');
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
      _showError('Order not loaded');
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
    ).then((_) {
      // Refresh order subs after customer selection
      if (mounted) {
        ordersProvider.getAllOrderSubAndDetails();
      }
    });
  }

  void _addProduct() {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    if (ordersProvider.orderMaster == null) {
      _showError('Order not loaded');
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Show discard confirmation dialog (matches KMP behavior)
        // Converted from KMP's showDiscardAlert (CreateOrderScreen.kt line 188-204)
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text('Are you sure you want to discard this order?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () async {
                  // Delete order and subs, then allow pop
                  final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
                  final success = await ordersProvider.deleteOrderAndSub();
                  if (mounted) {
                    Navigator.of(context).pop(success);
                  }
                },
                child: const Text('Yes'),
              ),
            ],
          ),
        );

        return shouldPop ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Order'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Consumer<OrdersProvider>(
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
                            child: Text(
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
                              slNo: index + 1,
                              item: item,
                              onDelete: () async {
                                final success = await ordersProvider.deleteOrderSub(item.orderSub.id);
                                if (success) {
                                  await ordersProvider.getAllOrderSubAndDetails();
                                }
                              },
                              onTap: () {
                                // TODO: Edit item - navigate to product selection with orderSubId
                                _addProduct();
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
                  Container(
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
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderItemCard extends StatelessWidget {
  final int slNo;
  final OrderSubWithDetails item;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _OrderItemCard({
    required this.slNo,
    required this.item,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text('$slNo'),
        title: Text(item.productName ?? 'Unknown Product'),
        subtitle: Text(
          '${item.orderSub.orderSubQty} ${item.unitDispName ?? item.unitName ?? ''} @ ${item.orderSub.orderSubUpdateRate}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}

