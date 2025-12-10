import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../provider/products_provider.dart';
import '../../../utils/toast_helper.dart';

/// Create/Edit Product Screen
/// Form for creating new products or editing existing ones
/// Converted from KMP's CreateProductScreen.kt and EditProductScreen.kt
class CreateProductScreen extends StatefulWidget {
  final int? productId; // If provided, this is edit mode

  const CreateProductScreen({
    super.key,
    this.productId,
  });

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoadingProduct = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<ProductsProvider>(context, listen: false);
      if (widget.productId != null) {
        // Edit mode: Load existing product data
        developer.log('CreateProductScreen: initState() - widget.productId: ${widget.productId}-Edit mode');
        await _loadProductData(widget.productId!);
      } else {
        // Create mode: Reset form
        developer.log('CreateProductScreen: initState() - Create mode');
        provider.resetForm();
      }
    });
  }

  Future<void> _loadProductData(int productId) async {
    developer.log('<--------------------CreateProductScreen: _loadProductData() of productId: $productId-------------------->');
    setState(() {
      _isLoadingProduct = true;
    });

    final provider = Provider.of<ProductsProvider>(context, listen: false);
    final productWithDetails = await provider.loadProductByIdWithDetails(productId);

    if (!mounted) return;

    if (productWithDetails == null) {
      ToastHelper.showError('Product not found');
      Navigator.pop(context);
      return;
    }

    // Populate form fields from product data
    provider.populateFormFromProduct(productWithDetails);

    setState(() {
      _isLoadingProduct = false;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final provider = Provider.of<ProductsProvider>(context, listen: false);
        provider.setImageBytes(Uint8List.fromList(bytes));
      }
    } catch (e) {
      ToastHelper.showError('Failed to pick image: $e');
    }
  }

  Future<bool> _onWillPop() async {
    final provider = Provider.of<ProductsProvider>(context, listen: false);
    if (provider.codeSt.isNotEmpty ||
        provider.nameSt.isNotEmpty ||
        provider.imageBytes != null ||
        (widget.productId != null && provider.photoUrl != null)) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Are you sure you want to discard your changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      return shouldDiscard ?? false;
    }
    return true;
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<ProductsProvider>(context, listen: false);
    
    if (widget.productId != null) {
      // Edit mode: Update product
      final error = await provider.updateProduct(widget.productId!);
      if (error != null) {
        ToastHelper.showError(error);
      } else {
        ToastHelper.showSuccess('Product updated successfully');
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } else {
      // Create mode: Create new product
      final error = await provider.createProduct();
      if (error != null) {
        ToastHelper.showError(error);
      } else {
        ToastHelper.showSuccess('Product created successfully');
        if (mounted) {
          // Navigate to product details if we have the product ID
          // For now, just pop back (KMP navigates to ProductDetails after create)
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
          
            Navigator.pop(context);
          }
        }else{
          final provider = Provider.of<ProductsProvider>(context, listen: false);
            provider.clearSelectedProduct();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.productId == null ? 'Create Product' : 'Edit Product'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: _isLoadingProduct
            ? const Center(child: CircularProgressIndicator())
            : Consumer<ProductsProvider>(
          builder: (context, provider, _) {
            return GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // Image Picker
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: provider.imageBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.memory(
                                      provider.imageBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : provider.photoUrl != null && provider.photoUrl!.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          provider.photoUrl!,
                                          fit: BoxFit.cover,
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
                                      )
                                    : const Center(
                                        child: Text(
                                          'Select Image',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Code Field
                      TextFormField(
                        textCapitalization: TextCapitalization.characters,
                        initialValue: provider.codeSt,
                        decoration: const InputDecoration(
                          labelText: 'Code*',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => provider.setCode(value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter Code';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Barcode Field
                      TextFormField(
                        initialValue: provider.barcodeSt,
                        decoration: const InputDecoration(
                          labelText: 'Barcode',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => provider.setBarcode(value),
                      ),
                      const SizedBox(height: 16),
                      // Name Field
                      TextFormField(
                        initialValue: provider.nameSt,
                        decoration: const InputDecoration(
                          labelText: 'Name*',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => provider.setName(value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter Name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Sub Name Field
                      TextFormField(
                        initialValue: provider.subNameSt,
                        decoration: const InputDecoration(
                          labelText: 'Sub Name',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => provider.setSubName(value),
                      ),
                      const SizedBox(height: 16),
                      // Brand Field
                      TextFormField(
                        initialValue: provider.brandSt,
                        decoration: const InputDecoration(
                          labelText: 'Brand',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => provider.setBrand(value),
                      ),
                      const SizedBox(height: 16),
                      // Sub Brand Field
                      TextFormField(
                        initialValue: provider.subBrandSt,
                        decoration: const InputDecoration(
                          labelText: 'Sub Brand',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => provider.setSubBrand(value),
                      ),
                      const SizedBox(height: 16),
                      // Category Selection
                      const Text(
                        'Category',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _showCategoryBottomSheet(context, provider),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  provider.formCategorySt,
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Sub-Category Selection
                      const Text(
                        'Sub-Category',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _showSubCategoryBottomSheet(context, provider),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  provider.formSubCategorySt,
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Base Unit Selection
                      const Text(
                        'Base Unit*',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _showBaseUnitBottomSheet(context, provider),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: provider.formBaseUnitId == -1
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  provider.formBaseUnitSt,
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Default Supplier Selection
                      const Text(
                        'Default Supplier',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _showSupplierBottomSheet(context, provider),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  provider.formSupplierSt,
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Auto Send Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: provider.formAutoSentEnable == 1,
                            onChanged: (value) {
                              if (provider.formSupplierId == -1) {
                                ToastHelper.showWarning('Select a supplier');
                                return;
                              }
                              provider.setFormAutoSentEnable(value == true ? 1 : 0);
                            },
                          ),
                          const Expanded(
                            child: Text('Out of stock auto send to Supplier'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Price Field
                      TextFormField(
                        initialValue: provider.priceSt,
                        decoration: const InputDecoration(
                          labelText: 'Price*',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) => provider.setPrice(value),
                        validator: (value) {
                          final price = double.tryParse(value ?? '0') ?? 0.0;
                          if (price <= 0.0) {
                            return 'Enter Price';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // MRP Field
                      TextFormField(
                        initialValue: provider.mrpSt,
                        decoration: const InputDecoration(
                          labelText: 'MRP',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) => provider.setMrp(value),
                      ),
                      const SizedBox(height: 16),
                      // Retail Price Field
                      TextFormField(
                        initialValue: provider.retailPriceSt,
                        decoration: const InputDecoration(
                          labelText: 'Retail Price',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) => provider.setRetailPrice(value),
                      ),
                      const SizedBox(height: 16),
                      // Fitting Charge Field
                      TextFormField(
                        initialValue: provider.fittingChargeSt,
                        decoration: const InputDecoration(
                          labelText: 'Fitting Charge',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) => provider.setFittingCharge(value),
                      ),
                      const SizedBox(height: 16),
                      // Note Field
                      TextFormField(
                        initialValue: provider.noteSt,
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        onChanged: (value) => provider.setNote(value),
                      ),
                      const SizedBox(height: 24),
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: provider.isLoading ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: provider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCategoryBottomSheet(BuildContext context, ProductsProvider provider) {
    if (provider.categoryList.isEmpty) {
      ToastHelper.showError('Category not found');
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) => _CategoryBottomSheet(
        categoryList: provider.categoryList,
        selectedCategoryId: provider.formCategoryId,
        onCategorySelected: (categoryId, categoryName) {
          provider.setFormCategory(categoryId, categoryName);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSubCategoryBottomSheet(BuildContext context, ProductsProvider provider) {
    if (provider.formCategoryId == -1) {
      ToastHelper.showWarning('Please select category first');
      return;
    }
    if (provider.subCategoryList.isEmpty) {
      ToastHelper.showError('Sub-Category not found');
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) => _SubCategoryBottomSheet(
        subCategoryList: provider.subCategoryList,
        selectedSubCategoryId: provider.formSubCategoryId,
        onSubCategorySelected: (subCategoryId, subCategoryName) {
          provider.setFormSubCategory(subCategoryId, subCategoryName);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showBaseUnitBottomSheet(BuildContext context, ProductsProvider provider) {
    if (provider.unitList.isEmpty) {
      ToastHelper.showError('Base unit not found');
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) => _BaseUnitBottomSheet(
        unitList: provider.unitList,
        selectedBaseUnitId: provider.formBaseUnitId,
        onBaseUnitSelected: (baseUnitId, baseUnitName) {
          provider.setFormBaseUnit(baseUnitId, baseUnitName);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSupplierBottomSheet(BuildContext context, ProductsProvider provider) {
    if (provider.supplierList.isEmpty) {
      ToastHelper.showError('Supplier not found');
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) => _SupplierBottomSheet(
        supplierList: provider.supplierList,
        selectedSupplierId: provider.formSupplierId,
        onSupplierSelected: (supplierId, supplierName) {
          provider.setFormSupplier(supplierId, supplierName);
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// Category Bottom Sheet
class _CategoryBottomSheet extends StatelessWidget {
  final List<dynamic> categoryList;
  final int selectedCategoryId;
  final Function(int, String) onCategorySelected;

  const _CategoryBottomSheet({
    required this.categoryList,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        itemCount: categoryList.length,
        itemBuilder: (context, index) {
          final category = categoryList[index];
          final isSelected = category.id == selectedCategoryId;
          return RadioListTile<int>(
            title: Text(category.name),
            value: category.id,
            groupValue: selectedCategoryId,
            onChanged: (value) {
              if (value != null) {
                onCategorySelected(value, category.name);
              }
            },
            selected: isSelected,
          );
        },
      ),
    );
  }
}

/// Sub-Category Bottom Sheet
class _SubCategoryBottomSheet extends StatelessWidget {
  final List<dynamic> subCategoryList;
  final int selectedSubCategoryId;
  final Function(int, String) onSubCategorySelected;

  const _SubCategoryBottomSheet({
    required this.subCategoryList,
    required this.selectedSubCategoryId,
    required this.onSubCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        itemCount: subCategoryList.length,
        itemBuilder: (context, index) {
          final subCategory = subCategoryList[index];
          final isSelected = subCategory.id == selectedSubCategoryId;
          return RadioListTile<int>(
            title: Text(subCategory.name),
            value: subCategory.id,
            groupValue: selectedSubCategoryId,
            onChanged: (value) {
              if (value != null) {
                onSubCategorySelected(value, subCategory.name);
              }
            },
            selected: isSelected,
          );
        },
      ),
    );
  }
}

/// Base Unit Bottom Sheet
class _BaseUnitBottomSheet extends StatelessWidget {
  final List<dynamic> unitList;
  final int selectedBaseUnitId;
  final Function(int, String) onBaseUnitSelected;

  const _BaseUnitBottomSheet({
    required this.unitList,
    required this.selectedBaseUnitId,
    required this.onBaseUnitSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        itemCount: unitList.length,
        itemBuilder: (context, index) {
          final unit = unitList[index];
          final isSelected = unit.id == selectedBaseUnitId;
          return RadioListTile<int>(
            title: Text(unit.name ?? ''),
            value: unit.id,
            groupValue: selectedBaseUnitId,
            onChanged: (value) {
              if (value != null) {
                onBaseUnitSelected(value, unit.name ?? '');
              }
            },
            selected: isSelected,
          );
        },
      ),
    );
  }
}

/// Supplier Bottom Sheet
class _SupplierBottomSheet extends StatelessWidget {
  final List<dynamic> supplierList;
  final int selectedSupplierId;
  final Function(int, String) onSupplierSelected;

  const _SupplierBottomSheet({
    required this.supplierList,
    required this.selectedSupplierId,
    required this.onSupplierSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        itemCount: supplierList.length,
        itemBuilder: (context, index) {
          final supplier = supplierList[index];
          // KMP uses supplier.userId for default_supp_id
          final isSelected = supplier.userId == selectedSupplierId;
          return RadioListTile<int>(
            title: Text(supplier.name),
            value: supplier.userId,
            groupValue: selectedSupplierId,
            onChanged: (value) {
              if (value != null) {
                onSupplierSelected(value, supplier.name);
              }
            },
            selected: isSelected,
          );
        },
      ),
    );
  }
}

