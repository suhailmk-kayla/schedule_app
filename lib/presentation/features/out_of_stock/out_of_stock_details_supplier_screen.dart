import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../provider/out_of_stock_provider.dart';
import '../../provider/products_provider.dart';
import '../../../models/master_data_api.dart';
import '../../../models/product_api.dart';
import '../../../utils/toast_helper.dart';
import '../../../utils/notification_manager.dart';

/// OutOfStock Details Supplier Screen
/// Shows product details and allows supplier to mark availability
/// Converted from KMP's OutOfStockDetailsSupplierScreen.kt
class OutOfStockDetailsSupplierScreen extends StatefulWidget {
  final int oospId;

  const OutOfStockDetailsSupplierScreen({
    super.key,
    required this.oospId,
  });

  @override
  State<OutOfStockDetailsSupplierScreen> createState() =>
      _OutOfStockDetailsSupplierScreenState();
}

class _OutOfStockDetailsSupplierScreenState
    extends State<OutOfStockDetailsSupplierScreen> {
  OutOfStockSubWithDetails? _subWithDetails;
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _availableQtyController = TextEditingController();
  bool _isAvailable = true; // true = Available, false = Out of Stock

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _availableQtyController.dispose();
    super.dispose();
  }

  void _loadData() async {
    final provider = Provider.of<OutOfStockProvider>(context, listen: false);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Get sub details
    final sub = await provider.getOopsSubBySub(widget.oospId);
    if (sub == null) {
      setState(() {
        _errorMessage = 'Out of stock item not found';
        _isLoading = false;
      });
      return;
    }

    // Mark as viewed if not already
    if (sub.isViewed == 0) {
      await provider.updateIsSubViewedFlag(
        oospId: widget.oospId,
        isViewed: 1,
      );
    }

    // Load product details
    final productsProvider =
        Provider.of<ProductsProvider>(context, listen: false);
    await productsProvider.loadProductByIdWithDetails(sub.productId);
    await productsProvider.loadProductCars(sub.productId);

    // Initialize controllers
    _noteController.text = sub.note;
    // Initialize available qty with existing value if present, otherwise 0
    _availableQtyController.text = sub.availQty > 0 ? sub.availQty.toString() : '0';
    // Initialize isAvailable based on current flag (2 = Available, 3 = Out of Stock)
    _isAvailable = sub.oospFlag == 2;

    setState(() {
      _subWithDetails = sub;
      _isLoading = false;
    });
  }

  void _handleInform() {
    if (_subWithDetails == null) return;

    final provider = Provider.of<OutOfStockProvider>(context, listen: false);
    setState(() => _isLoading = true);

    // Calculate available qty and flag
    double availQty = 0.0;
    int oospFlag = 2; // Default: Available

    if (!_isAvailable) {
      // Out of Stock
      oospFlag = 3;
      final qtyText = _availableQtyController.text.trim();
      if (qtyText.isNotEmpty && qtyText != '.') {
        availQty = double.tryParse(qtyText) ?? 0.0;
        // Ensure qty doesn't exceed requested qty
        if (availQty >= _subWithDetails!.qty) {
          availQty = _subWithDetails!.qty - 1;
          _availableQtyController.text = availQty.toString();
        }
      }
    }

    provider.informAdminFromSupplier(
      subItem: _subWithDetails!,
      availQty: availQty,
      note: _noteController.text.trim(),
      oospFlag: oospFlag,
      onFailure: (error) {
        setState(() => _isLoading = false);
        ToastHelper.showError(error);
      },
      onSuccess: () {
        setState(() => _isLoading = false);
        ToastHelper.showInfo('Admin informed');
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<OutOfStockProvider, ProductsProvider, NotificationManager>(
      builder: (context, oospProvider, productsProvider, notificationManager, _) {
        // Listen to notification triggers
        if (notificationManager.notificationTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadData();
            notificationManager.resetTrigger();
          });
        }

        if (_isLoading && _subWithDetails == null) {
          return  Scaffold(
            appBar: AppBar(title: Text('Out of stock')),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_errorMessage != null && _subWithDetails == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Out of stock')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (_subWithDetails == null) {
          return  Scaffold(
            appBar: AppBar(title: Text('Out of stock')),
            body: Center(child: Text('Not found')),
          );
        }

        final productWithDetails = productsProvider.currentProductWithDetails;
        final canEdit = _subWithDetails!.isCheckedflag == 0 && _subWithDetails!.oospFlag != 5;
        final canShowInformButton = _subWithDetails!.oospFlag == 1 && canEdit;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Out of stock'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image
                      _buildProductImage(productWithDetails),
                      const SizedBox(height: 16),

                      // Product Details Card
                      _buildProductDetailsCard(productWithDetails, _subWithDetails!),
                      const SizedBox(height: 16),

                      // Compatible Cars
                      // _buildCompatibleCars(productsProvider),
                      // const SizedBox(height: 16),

                      // Sub Item Card
                      _SubItemCard(
                        subItem: _subWithDetails!,
                        noteController: _noteController,
                        availableQtyController: _availableQtyController,
                        isAvailable: _isAvailable,
                        onAvailableChanged: (value) {
                          setState(() => _isAvailable = value);
                        },
                        canEdit: canEdit,
                        canShowInformButton: canShowInformButton,
                        onInform: _handleInform,
                      ),
                      const SizedBox(height: 80), // Space for bottom button
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildProductImage(ProductWithDetails? productWithDetails) {
    final imageUrl = productWithDetails?.product.photo ?? '';
    return Center(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: imageUrl.isEmpty
            ? const Center(child: Text('No Image', style: TextStyle(color: Colors.grey)))
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Text('No Image', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProductDetailsCard(
    ProductWithDetails? productWithDetails,
    OutOfStockSubWithDetails subItem,
  ) {
    if (productWithDetails == null) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Loading product...')));
    }

    final product = productWithDetails.product;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                product.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            if (subItem.supplierId != -1)
              _buildDetailRow('Supplier:', subItem.supplierName),
          
            if (product.sub_name.isNotEmpty) _buildDetailRow('Sub Name:', product.sub_name),
            if (product.brand.isNotEmpty) _buildDetailRow('Brand:', product.brand),
            if (product.sub_brand.isNotEmpty) _buildDetailRow('Sub Brand:', product.sub_brand),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildCompatibleCars(ProductsProvider productsProvider) {
  //   final productCars = productsProvider.productCars;
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       const Text('Compatible cars', style: TextStyle(fontSize: 14)),
  //       const SizedBox(height: 8),
  //       Card(
  //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //         elevation: 4,
  //         child: Padding(
  //           padding: const EdgeInsets.all(12),
  //           child: productCars.isEmpty
  //               ? const Center(
  //                   child: Padding(
  //                     padding: EdgeInsets.all(8),
  //                     child: Text('All Cars Compatible', style: TextStyle(color: Colors.grey)),
  //                   ),
  //                 )
  //               : Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: _buildCarList(productCars),
  //                 ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // List<Widget> _buildCarList(Map<String, Map<String, Map<String, List<String>>>> cars) {
  //   final widgets = <Widget>[];
  //   cars.forEach((brand, nameMap) {
  //     nameMap.forEach((name, modelMap) {
  //       widgets.add(
  //         Padding(
  //           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 '$brand $name',
  //                 style: const TextStyle(
  //                   fontSize: 14,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //               ...modelMap.entries.map((modelEntry) {
  //                 final model = modelEntry.key;
  //                 final versions = modelEntry.value;
  //                 final versionsText = versions.isEmpty
  //                     ? 'All Versions'
  //                     : versions.join(', ');
  //                 return Text(
  //                   '$model: $versionsText',
  //                   style: const TextStyle(
  //                     fontSize: 14,
  //                     fontWeight: FontWeight.normal,
  //                   ),
  //                 );
  //               }),
  //             ],
  //           ),
  //         ),
  //       );
  //     });
  //   });
  //   return widgets;
  // }
}

class _SubItemCard extends StatelessWidget {
  final OutOfStockSubWithDetails subItem;
  final TextEditingController noteController;
  final TextEditingController availableQtyController;
  final bool isAvailable;
  final ValueChanged<bool> onAvailableChanged;
  final bool canEdit;
  final bool canShowInformButton;
  final VoidCallback onInform;

  const _SubItemCard({
    required this.subItem,
    required this.noteController,
    required this.availableQtyController,
    required this.isAvailable,
    required this.onAvailableChanged,
    required this.canEdit,
    required this.canShowInformButton,
    required this.onInform,
  });

  String _getStatusText() {
    switch (subItem.oospFlag) {
      case 0:
        return 'Pending';
      case 1:
        return 'Pending';
      case 2:
        return 'Order Confirmed';
      case 3:
        return subItem.availQty > 0
            ? 'Only ${subItem.availQty.toInt()} is left (Waiting for response)'
            : 'Order Cancelled';
      case 5:
        return 'Order Cancelled';
      default:
        return 'Order Cancelled';
    }
  }

  Color _getStatusColor() {
    switch (subItem.oospFlag) {
      case 0:
      case 1:
      case 3:
      case 5:
        return Colors.red;
      case 2:
        return Colors.green.shade700;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quantity and Unit
            Row(
              children: [
                const Text('Quantity:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                Text(
                  subItem.qty.toString(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(width: 16),
                const Text('Unit:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                Text(
                  subItem.unitDispName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            // Note (if checked)
            if (subItem.note.isNotEmpty && subItem.isCheckedflag == 1) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Note:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subItem.note,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                    ),
                  ),
                ],
              ),
            ],

            // Status
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Status:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusText(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(),
                    ),
                  ),
                ),
              ],
            ),

            // Editable fields (if not checked and not cancelled)
            if (canEdit) ...[
              const SizedBox(height: 16),
              // Note input
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Available/Out of Stock checkboxes
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: isAvailable, // true when Available is selected
                              onChanged: (value) {
                                // When Available is checked, set isAvailable to true
                                onAvailableChanged(true);
                              },
                              activeColor: Colors.green,
                            ),
                            const Text('Available', style: TextStyle(color: Colors.green)),
                          ],
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: !isAvailable, // true when Out of Stock is selected
                              onChanged: (value) {
                                // When Out of Stock is checked, set isAvailable to false
                                onAvailableChanged(false);
                              },
                              activeColor: Colors.red,
                            ),
                            const Text('Out Of Stock', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Available Qty input (only if Out of Stock is selected)
                  if (!isAvailable)
                    SizedBox(
                      width: 150,
                      child: TextField(
                        controller: availableQtyController,
                        decoration: const InputDecoration(
                          labelText: 'Available Qty',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          // Validate: only numbers and decimal point
                          if (!RegExp(r'^\d*\.?\d*$').hasMatch(value)) {
                            availableQtyController.text = value.replaceAll(RegExp(r'[^\d.]'), '');
                            availableQtyController.selection = TextSelection.fromPosition(
                              TextPosition(offset: availableQtyController.text.length),
                            );
                          }
                          // Ensure qty doesn't exceed requested qty
                          final qty = double.tryParse(value) ?? 0.0;
                          if (qty >= subItem.qty) {
                            availableQtyController.text = (subItem.qty - 1).toString();
                            availableQtyController.selection = TextSelection.fromPosition(
                              TextPosition(offset: availableQtyController.text.length),
                            );
                          }
                        },
                      ),
                    ),
                ],
              ),
            ],

            // Checked indicator
            if (subItem.isCheckedflag == 1) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.check, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Checked',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            // Inform button
            if (canShowInformButton) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onInform,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Inform',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

