import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/storage_helper.dart';
import '../../provider/products_provider.dart';
// TODO: Import create_product_screen.dart and cars details screen when implemented

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

  Future<void> _loadUserData() async {
    final userType = await StorageHelper.getUserType();
    setState(() {
      _userType = userType;
    });
  }

  void _handleEdit() {
    // TODO: Navigate to edit product screen when implemented
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit product feature coming soon')),
    );
  }

  void _handleAddCar() {
    // TODO: Navigate to cars details screen for adding cars
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => CarsDetailsScreen(productId: widget.productId),
    //   ),
    // ).then((result) {
    //   if (result == true && mounted) {
    //     final provider = Provider.of<ProductsProvider>(context, listen: false);
    //     provider.loadProductCars(widget.productId);
    //   }
    // });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add Car feature coming soon')),
    );
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

    // Show unit selection dialog
    // TODO: Implement unit selection dialog similar to KMP's AddDerivedUnitDialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add unit dialog coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                            // TODO: Show full image dialog
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
                                product.photo,
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
