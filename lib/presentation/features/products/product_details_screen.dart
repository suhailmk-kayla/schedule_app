import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/helpers/image_url_handler.dart';
import 'package:schedule_frontend_flutter/utils/storage_helper.dart';
import '../../provider/products_provider.dart';
import '../../../models/product_api.dart';
import '../../../models/master_data_api.dart';
import 'create_product_screen.dart';
import '../product_settings/cars/cars_list_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final int productId;
  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _userType = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<ProductsProvider>(context, listen: false);
      await provider.loadProductByIdWithDetails(widget.productId);
    });
  }

  void _showFullImageDialog(BuildContext context, String imageUrl) {
    developer.log('imageUrl: $imageUrl');
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _FullImageDialog(
        imageUrl: imageUrl,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<void> _loadUserData() async {
    final userType = await StorageHelper.getUserType();
    setState(() {
      _userType = userType;
    });
  }

  void _handleEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateProductScreen(productId: widget.productId),
      ),
    ).then((_) {
      // Reload product details after returning from edit
      if (mounted) {
        final provider = Provider.of<ProductsProvider>(context, listen: false);
        provider.loadProductByIdWithDetails(widget.productId);
      }
    });
  }

  void _handleAddCar() {
    // Navigate to cars list screen with productId
    // Matches KMP's addCarClick behavior (BaseScreen.kt line 610-611)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarsListScreen(productId: widget.productId),
      ),
    ).then((result) {
      // Reload product cars after returning
      if (mounted) {
        final provider = Provider.of<ProductsProvider>(context, listen: false);
        provider.loadProductCars(widget.productId);
      }
    });
  }

  Future<void> _handleAddUnit() async {
    final provider = Provider.of<ProductsProvider>(context, listen: false);
    final product = provider.currentProductWithDetails?.product;
    
    if (product == null || product.base_unit_id == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Base unit not set')),
      );
      return;
    }

    // Load derived units first
    await provider.loadDerivedUnits(product.base_unit_id);
    
    if (provider.unitList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No units available')),
      );
      return;
    }

    // Show unit selection dialog
    // Matches KMP's AddDerivedUnitDialog (ProductDetails.kt lines 528-613)
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => _AddDerivedUnitDialog(
          product: product,
          provider: provider,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if(didPop){
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Product Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Consumer<ProductsProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.currentProductWithDetails == null) {
              return const Center(child: CircularProgressIndicator());
            }
      
            final productWithDetails = provider.currentProductWithDetails;
            if (productWithDetails == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Product not found'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        provider.loadProductByIdWithDetails(widget.productId);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
      
            final product = productWithDetails.product;
      
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image on top (matches KMP lines 118-158)
                  Center(
                    child: GestureDetector(
                      onTap: product.photo.isNotEmpty
                          ? () {
                              developer.log('product.photo: ${product.photo}');
                              _showFullImageDialog(context, product.photo);
                            }
                          : null,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: product.photo.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  ImageUrlFixer.fix(product.photo),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Text('No Image', style: TextStyle(color: Colors.grey)),
                                    );
                                  },
                                ),
                              )
                            : const Center(
                                child: Text('No Image', style: TextStyle(color: Colors.grey)),
                              ),
                      ),
                    ),
                  ),
      
                  const SizedBox(height: 16),
      
                  // Product details card (matches KMP lines 159-356)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Item Name (centered, matches KMP lines 168-173)
                              Center(
                                child: Text(
                                  product.name.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Details list (label + value in single row)
                              _buildFieldRow('code:', product.code),
                              _buildFieldRow('Sub Name:', product.sub_name),
                              _buildFieldRow('Brand:', product.brand),
                              _buildFieldRow('Sub Brand:', product.sub_brand),
                              _buildFieldRow('Category:', productWithDetails.categoryName ?? ''),
                              _buildFieldRow('Sub-Category:', productWithDetails.subCategoryName ?? ''),
                              _buildFieldRow('Default supplier:', productWithDetails.supplierName ?? ''),
                              _buildFieldRow(
                                'Supplier Auto Send:',
                                product.auto_sendto_supplier_flag == 1 ? 'Enabled' : 'Disabled',
                                valueColor: product.auto_sendto_supplier_flag == 1
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                              _buildFieldRow('Base Unit:', productWithDetails.baseUnitName ?? ''),
                              _buildFieldRow('Price:', product.price.toStringAsFixed(2)),
                              _buildFieldRow('MRP:', product.mrp.toStringAsFixed(2)),
                              _buildFieldRow('Fitting Charge:', product.fitting_charge.toStringAsFixed(2)),
                              _buildFieldRow('Note:', product.note),
                            ],
                          ),
                          // Edit button (admin only, bottom right, matches KMP lines 342-353)
                          if (_userType == 1)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: _handleEdit,
                                tooltip: 'Edit',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
      
                  const SizedBox(height: 16),
      
                  // Compatible cars section (matches KMP lines 358-403)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Compatible cars',
                        style: TextStyle(fontSize: 14),
                      ),
                      if (_userType == 1)
                        TextButton.icon(
                          onPressed: _handleAddCar,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Car'),
                        ),
                    ],
                  ),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: provider.productCars.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'All Cars Compatible',
                                  style: TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildCarList(provider.productCars),
                            ),
                    ),
                  ),
      
                  const SizedBox(height: 16),
      
                  // Units section (matches KMP lines 404-480)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Units',
                        style: TextStyle(fontSize: 14),
                      ),
                      if (_userType == 1)
                        TextButton.icon(
                          onPressed: _handleAddUnit,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add unit'),
                        ),
                    ],
                  ),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: provider.productUnits.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'No derived units',
                                  style: TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                              ),
                            )
                          : Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: provider.productUnits.map((unit) {
                                return Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    unit.derivenName ?? 'Not found',
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),
      
                  const SizedBox(height: 36),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFieldRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCarList(Map<String, Map<String, Map<String, List<String>>>> cars) {
    final widgets = <Widget>[];
    cars.forEach((brand, nameMap) {
      nameMap.forEach((name, modelMap) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$brand $name',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...modelMap.entries.map((modelEntry) {
                  final model = modelEntry.key;
                  final versions = modelEntry.value;
                  final versionsText = versions.isEmpty
                      ? 'All Versions'
                      : versions.join(', ');
                  return Text(
                    '$model: $versionsText',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      });
    });
    return widgets;
  }
}

/// Add Derived Unit Dialog
/// Matches KMP's AddDerivedUnitDialog (ProductDetails.kt lines 528-613)
class _AddDerivedUnitDialog extends StatefulWidget {
  final Product product;
  final ProductsProvider provider;

  const _AddDerivedUnitDialog({
    required this.product,
    required this.provider,
  });

  @override
  State<_AddDerivedUnitDialog> createState() => _AddDerivedUnitDialogState();
}

class _AddDerivedUnitDialogState extends State<_AddDerivedUnitDialog> {
  int _selectedUnitId = -1;
  String _selectedUnitName = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Unit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Unit selection field
          InkWell(
            onTap: () {
              if (widget.provider.unitList.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No units available')),
                );
                return;
              }
              // Show unit selection dialog
              showDialog(
                context: context,
                builder: (context) => _UnitSelectionDialog(
                  units: widget.provider.unitList,
                  selectedUnitId: _selectedUnitId,
                  onUnitSelected: (unitId, unitName) {
                    setState(() {
                      _selectedUnitId = unitId;
                      _selectedUnitName = unitName;
                    });
                  },
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _selectedUnitName.isEmpty ? 'Select Unit' : _selectedUnitName,
                style: TextStyle(
                  color: _selectedUnitName.isEmpty ? Colors.grey : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isLoading ? null : () async {
            if (_selectedUnitId == -1) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Select unit')),
              );
              return;
            }

            setState(() {
              _isLoading = true;
            });

            final error = await widget.provider.addUnitToProduct(
              productId: widget.product.productId ?? -1,
              baseUnitId: widget.product.base_unit_id,
              derivedUnitId: _selectedUnitId,
            );

            if (mounted) {
              setState(() {
                _isLoading = false;
              });

              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unit added')),
                );
                Navigator.of(context).pop();
              }
            }
          },
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

/// Unit Selection Dialog
/// Shows list of units to select from
class _UnitSelectionDialog extends StatelessWidget {
  final List<Units> units;
  final int selectedUnitId;
  final Function(int unitId, String unitName) onUnitSelected;

  const _UnitSelectionDialog({
    required this.units,
    required this.selectedUnitId,
    required this.onUnitSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Unit'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: units.length,
          itemBuilder: (context, index) {
            final unit = units[index];
            final unitId = unit.id;
            final unitName = unit.name;

            return ListTile(
              title: Text(unitName),
              leading: Radio<int>(
                value: unitId,
                groupValue: selectedUnitId,
                onChanged: (value) {
                  if (value != null) {
                    onUnitSelected(value, unitName);
                    Navigator.of(context).pop();
                  }
                },
              ),
              onTap: () {
                onUnitSelected(unitId, unitName);
                Navigator.of(context).pop();
              },
            );
          },
        ),
      ),
    );
  }
}

/// Full Image Dialog
/// Shows full-size product image in a dialog
/// Matches KMP's FullImageDialog (FullImageDialog.kt lines 21-43)
class _FullImageDialog extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onDismiss;

  const _FullImageDialog({
    required this.imageUrl,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final fixedUrl = ImageUrlFixer.fix(imageUrl);
    developer.log('imageUrl: $fixedUrl');
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GestureDetector(
        onTap: onDismiss,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 400,
            maxHeight: 400,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Image.network(
              fixedUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
