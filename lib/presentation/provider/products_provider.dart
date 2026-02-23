import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../../repositories/products/products_repository.dart';
import '../../repositories/categories/categories_repository.dart';
import '../../repositories/sub_categories/sub_categories_repository.dart';
import '../../repositories/units/units_repository.dart';
import '../../repositories/suppliers/suppliers_repository.dart';
import '../../models/product_api.dart';
import '../../models/master_data_api.dart';
import '../../models/supplier_model.dart';

/// Products Provider
/// Manages product-related state and operations
/// Converted from KMP's ProductViewModel.kt
class ProductsProvider extends ChangeNotifier {
  final ProductsRepository _productsRepository;
  final CategoriesRepository _categoriesRepository;
  final SubCategoriesRepository _subCategoriesRepository;
  final UnitsRepository _unitsRepository;
  final SuppliersRepository _suppliersRepository;

  ProductsProvider({
    required ProductsRepository productsRepository,
    required CategoriesRepository categoriesRepository,
    required SubCategoriesRepository subCategoriesRepository,
    required UnitsRepository unitsRepository,
    required SuppliersRepository suppliersRepository,
  })  : _productsRepository = productsRepository,
        _categoriesRepository = categoriesRepository,
        _subCategoriesRepository = subCategoriesRepository,
        _unitsRepository = unitsRepository,
        _suppliersRepository = suppliersRepository {
    // Initialize with categories and base units
    loadCategories();
    loadBaseUnits();
    loadSuppliers();
  }

  // ============================================================================
  // State Variables
  // ============================================================================

  List<Product> _productList = [];
  List<Product> get productList => _productList;

  List<Category> _categoryList = [];
  List<Category> get categoryList => _categoryList;

  List<SubCategory> _subCategoryList = [];
  List<SubCategory> get subCategoryList => _subCategoryList;

  List<Units> _unitList = [];
  List<Units> get unitList => _unitList;

  int _filterCategoryId = -1;
  int get filterCategoryId => _filterCategoryId;
  String _filterCategorySt = 'All Category';
  String get filterCategorySt => _filterCategorySt;

  int _filterSubCategoryId = -1;
  int get filterSubCategoryId => _filterSubCategoryId;
  String _filterSubCategorySt = 'Sub Category';
  String get filterSubCategorySt => _filterSubCategorySt;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ============================================================================
  // Form State Variables (for Create/Edit Product)
  // ============================================================================

  Uint8List? _imageBytes;
  Uint8List? get imageBytes => _imageBytes;
  String? _photoUrl; // For edit mode - stores URL of existing photo
  String? get photoUrl => _photoUrl;
  String _codeSt = '';
  String get codeSt => _codeSt;
  String _barcodeSt = '';
  String get barcodeSt => _barcodeSt;
  String _nameSt = '';
  String get nameSt => _nameSt;
  String _subNameSt = '';
  String get subNameSt => _subNameSt;
  String _brandSt = '';
  String get brandSt => _brandSt;
  String _subBrandSt = '';
  String get subBrandSt => _subBrandSt;
  String _priceSt = '0.00';
  String get priceSt => _priceSt;
  String _mrpSt = '0.00';
  String get mrpSt => _mrpSt;
  String _retailPriceSt = '0.00';
  String get retailPriceSt => _retailPriceSt;
  String _fittingChargeSt = '0.00';
  String get fittingChargeSt => _fittingChargeSt;
  String _minimumPriceSt = '';
  String get minimumPriceSt => _minimumPriceSt;
  String _noteSt = '';
  String get noteSt => _noteSt;
  int _formCategoryId = -1;
  int get formCategoryId => _formCategoryId;
  String _formCategorySt = 'Select Category';
  String get formCategorySt => _formCategorySt;
  int _formSubCategoryId = -1;
  int get formSubCategoryId => _formSubCategoryId;
  String _formSubCategorySt = 'Select Sub-Category';
  String get formSubCategorySt => _formSubCategorySt;
  int _formSupplierId = -1;
  int get formSupplierId => _formSupplierId;
  String _formSupplierSt = 'Select Supplier';
  String get formSupplierSt => _formSupplierSt;
  int _formAutoSentEnable = 0;
  int get formAutoSentEnable => _formAutoSentEnable;
  int _formBaseUnitId = -1;
  int get formBaseUnitId => _formBaseUnitId;
  String _formBaseUnitSt = 'Select Base unit';
  String get formBaseUnitSt => _formBaseUnitSt;

  List<Supplier> _supplierList = [];
  List<Supplier> get supplierList => _supplierList;

  // Product Details State (for ProductDetailsScreen)
  ProductWithDetails? _currentProductWithDetails;
  ProductWithDetails? get currentProductWithDetails => _currentProductWithDetails;

  Map<String, Map<String, Map<String, List<String>>>> _productCars = {};
  Map<String, Map<String, Map<String, List<String>>>> get productCars => _productCars;

  List<ProductUnitWithDetails> _productUnits = [];
  List<ProductUnitWithDetails> get productUnits => _productUnits;

  // ============================================================================
  // Public Methods
  // ============================================================================

  /// Load all products with optional search and filters
  Future<void> loadProducts({String searchKey = ''}) async {
    _setLoading(true);
    _clearError();

    final result = _filterCategoryId == -1
        ? await _productsRepository.getAllProducts(searchKey: searchKey)
        : _filterSubCategoryId == -1
            ? await _productsRepository.getAllProductsByCategory(
                categoryId: _filterCategoryId,
                searchKey: searchKey,
              )
            : await _productsRepository.getAllProductsBySubCategory(
                categoryId: _filterCategoryId,
                subCategoryId: _filterSubCategoryId,
                searchKey: searchKey,
              );

    result.fold(
      (failure) => _setError(failure.message),
      (products) {
        _productList = products;
        notifyListeners();
      },
    );

    _setLoading(false);
  }

  /// Load product by ID
  Future<Product?> loadProductById(int productId) async {
    _setLoading(true);
    _clearError();

    final result = await _productsRepository.getProductById(productId);

    Product? product;
    result.fold(
      (failure) => _setError(failure.message),
      (p) => product = p,
    );

    _setLoading(false);
    return product;
  }

  /// Load all categories
  Future<void> loadCategories() async {
    final result = await _categoriesRepository.getAllCategories();

    result.fold(
      (failure) => _setError(failure.message),
      (categories) {
        _categoryList = categories;
        notifyListeners();
      },
    );
  }

  /// Load sub-categories by category ID
  Future<void> loadSubCategories(int categoryId) async {
    if (categoryId == -1) {
      _subCategoryList = [];
      notifyListeners();
      return;
    }

    final result = await _subCategoriesRepository.getSubCategoriesByCategoryId(
      categoryId,
    );

    result.fold(
      (failure) => _setError(failure.message),
      (subCategories) {
        _subCategoryList = subCategories;
        notifyListeners();
      },
    );
  }

  /// Load base units
  Future<void> loadBaseUnits() async {
    final result = await _unitsRepository.getAllBaseUnits();

    result.fold(
      (failure) => _setError(failure.message),
      (units) {
        _unitList = units;
        notifyListeners();
      },
    );
  }

  /// Load derived units by base unit ID
  Future<void> loadDerivedUnits(int baseUnitId) async {
    final result = await _unitsRepository.getAllDerivedUnitsByBaseId(baseUnitId);

    result.fold(
      (failure) => _setError(failure.message),
      (units) {
        _unitList = units;
        notifyListeners();
      },
    );
  }

  /// Set category filter
  void setCategoryFilter(int categoryId, String categoryName) {
    _filterCategoryId = categoryId;
    _filterCategorySt = categoryName;
    _filterSubCategoryId = -1;
    _filterSubCategorySt = 'Sub Category';
    _subCategoryList = [];
    notifyListeners();
  }

  /// Set sub-category filter
  void setSubCategoryFilter(int subCategoryId, String subCategoryName) {
    _filterSubCategoryId = subCategoryId;
    _filterSubCategorySt = subCategoryName;
    notifyListeners();
  }

  /// Clear filters
  void clearFilters() {
    _filterCategoryId = -1;
    _filterCategorySt = 'All Category';
    _filterSubCategoryId = -1;
    _filterSubCategorySt = 'Sub Category';
    _subCategoryList = [];
    notifyListeners();
  }

  /// Clear product list
  void clearProductList() {
    _productList = [];
    notifyListeners();
  }

  /// Load all suppliers
  Future<void> loadSuppliers() async {
    final result = await _suppliersRepository.getAllSuppliers();

    result.fold(
      (failure) => _setError(failure.message),
      (suppliers) {
        _supplierList = suppliers;
        notifyListeners();
      },
    );
  }

  void clearSelectedProduct() {
    _currentProductWithDetails = null;
    notifyListeners();
  }

  /// Load product by ID with details (includes joined names)
  /// Matches KMP's getProductsById and getProductByProductId
  Future<ProductWithDetails?> loadProductByIdWithDetails(int productId) async {
    _setLoading(true);
    _clearError();

    final result = await _productsRepository.getProductByIdWithDetails(productId);

    ProductWithDetails? product;
    result.fold(
      (failure) {
        _setError(failure.message);
        developer.log(
          'ProductsProvider: loadProductByIdWithDetails() - Failed to load product: ${failure.message}',
        );
      },
      (p) {
        if (p == null) {
          _setError('Product not found');
          developer.log(
            'ProductsProvider: loadProductByIdWithDetails() - Product not found for productId: $productId',
          );
        } else {
          product = p;
          _currentProductWithDetails = p;
          notifyListeners();
          // Load derived units if base unit exists (matches KMP line 92-94)
          if (p.product.base_unit_id != -1) {
            loadDerivedUnits(p.product.base_unit_id);
          }
          // Load product cars and units (matches KMP lines 96-97)
          loadProductCars(productId);
          loadProductUnits(productId);

        }
      },
    );

    _setLoading(false);
    return product;
  }

  /// Load product cars by product ID
  /// Matches KMP's getProductByProductId
  Future<void> loadProductCars(int productId) async {
    final result = await _productsRepository.getProductCarsByProductId(productId);
    result.fold(
      (_) {},
      (cars) {
        _productCars = cars;
        notifyListeners();
      },
    );
  }

  /// Load product units by product ID
  /// Matches KMP's getProductUnitsByProductId
  Future<void> loadProductUnits(int productId) async {
    final result = await _productsRepository.getProductUnitsByProductId(productId);
    result.fold(
      (_) {},
      (units) {
        _productUnits = units;
        notifyListeners();
      },
    );
  }

  /// Add car to product
  /// Matches KMP's addCarToProduct
  Future<String?> addCarToProduct({
    required int productId,
    required int brandId,
    required int nameId,
    required Map<String, Map<int, List<int>>> selectedMap,
  }) async {
    _setLoading(true);
    _clearError();

    final result = await _productsRepository.addProductCar(
      productId: productId,
      brandId: brandId,
      nameId: nameId,
      selectedMap: selectedMap,
    );

    String? error;
    result.fold(
      (failure) => error = failure.message,
      (_) {
        // Reload product cars (matches KMP pattern)
        loadProductCars(productId);
      },
    );

    _setLoading(false);
    return error;
  }

  /// Add unit to product
  /// Matches KMP's addUnitToProduct
  Future<String?> addUnitToProduct({
    required int productId,
    required int baseUnitId,
    required int derivedUnitId,
  }) async {
    _setLoading(true);
    _clearError();

    final result = await _productsRepository.addProductUnit(
      productId: productId,
      baseUnitId: baseUnitId,
      derivedUnitId: derivedUnitId,
    );

    String? error;
    result.fold(
      (failure) => error = failure.message,
      (_) {
        // Reload product units (matches KMP pattern)
        loadProductUnits(productId);
      },
    );

    _setLoading(false);
    return error;
  }

  // ============================================================================
  // Form State Management Methods
  // ============================================================================

  /// Set image bytes
  void setImageBytes(Uint8List? bytes) {
    _imageBytes = bytes;
    notifyListeners();
  }

  /// Set code
  void setCode(String code) {
    _codeSt = code;
    notifyListeners();
  }

  /// Set barcode
  void setBarcode(String barcode) {
    _barcodeSt = barcode;
    notifyListeners();
  }

  /// Set name
  void setName(String name) {
    _nameSt = name;
    notifyListeners();
  }

  /// Set sub name
  void setSubName(String subName) {
    _subNameSt = subName;
    notifyListeners();
  }

  /// Set brand
  void setBrand(String brand) {
    _brandSt = brand;
    notifyListeners();
  }

  /// Set sub brand
  void setSubBrand(String subBrand) {
    _subBrandSt = subBrand;
    notifyListeners();
  }

  /// Set price
  void setPrice(String price) {
    // Only allow numeric input with decimal
    if (RegExp(r'^\d*\.?\d*$').hasMatch(price)) {
      _priceSt = price;
      notifyListeners();
    }
  }

  /// Set MRP
  void setMrp(String mrp) {
    if (RegExp(r'^\d*\.?\d*$').hasMatch(mrp)) {
      _mrpSt = mrp;
      notifyListeners();
    }
  }

  /// Set retail price
  void setRetailPrice(String retailPrice) {
    if (RegExp(r'^\d*\.?\d*$').hasMatch(retailPrice)) {
      _retailPriceSt = retailPrice;
      notifyListeners();
    }
  }

  /// Set fitting charge
  void setFittingCharge(String fittingCharge) {
    if (RegExp(r'^\d*\.?\d*$').hasMatch(fittingCharge)) {
      _fittingChargeSt = fittingCharge;
      notifyListeners();
    }
  }

  /// Set minimum price
  void setMinimumPrice(String minimumPrice) {
    if (RegExp(r'^\d*\.?\d*$').hasMatch(minimumPrice)) {
      _minimumPriceSt = minimumPrice;
      notifyListeners();
    }
  }

  /// Set note
  void setNote(String note) {
    _noteSt = note;
    notifyListeners();
  }

  /// Set category
  void setFormCategory(int categoryId, String categoryName) {
    _formCategoryId = categoryId;
    _formCategorySt = categoryName;
    // Reset sub-category when category changes
    _formSubCategoryId = -1;
    _formSubCategorySt = 'Select Sub-Category';
    _subCategoryList = [];
    if (categoryId != -1) {
      loadSubCategories(categoryId);
    }
    notifyListeners();
  }

  /// Set sub-category
  void setFormSubCategory(int subCategoryId, String subCategoryName) {
    _formSubCategoryId = subCategoryId;
    _formSubCategorySt = subCategoryName;
    notifyListeners();
  }

  /// Set supplier
  void setFormSupplier(int supplierId, String supplierName) {
    _formSupplierId = supplierId;
    _formSupplierSt = supplierName;
    notifyListeners();
  }

  /// Set auto sent enable
  void setFormAutoSentEnable(int value) {
    if (_formSupplierId == -1) {
      return; // Can't enable without supplier
    }
    _formAutoSentEnable = value;
    notifyListeners();
  }

  /// Set base unit
  void setFormBaseUnit(int baseUnitId, String baseUnitName) {
    _formBaseUnitId = baseUnitId;
    _formBaseUnitSt = baseUnitName;
    notifyListeners();
  }

  /// Reset form to initial state
  void resetForm() {
    _imageBytes = null;
    _photoUrl = null;
    _codeSt = '';
    _barcodeSt = '';
    _nameSt = '';
    _subNameSt = '';
    _brandSt = '';
    _subBrandSt = '';
    _priceSt = '0.00';
    _mrpSt = '0.00';
    _retailPriceSt = '0.00';
    _fittingChargeSt = '0.00';
    _minimumPriceSt = '';
    _noteSt = '';
    _formCategoryId = -1;
    _formCategorySt = 'Select Category';
    _formSubCategoryId = -1;
    _formSubCategorySt = 'Select Sub-Category';
    _formSupplierId = -1;
    _formSupplierSt = 'Select Supplier';
    _formAutoSentEnable = 0;
    _formBaseUnitId = -1;
    _formBaseUnitSt = 'Select Base unit';
    _subCategoryList = [];
    notifyListeners();
  }

  /// Populate form fields from ProductWithDetails (for edit mode)
  /// Matches KMP's EditProductScreen.kt lines 105-127
  void populateFormFromProduct(ProductWithDetails productWithDetails) {
    final product = productWithDetails.product;
    
    // Set photo URL (will be loaded as image if needed)
    _photoUrl = product.photo.isNotEmpty ? product.photo : null;
    _imageBytes = null; // Clear any existing image bytes
    
    // Populate text fields
    _codeSt = product.code;
    _barcodeSt = product.barcode;
    _nameSt = product.name;
    _subNameSt = product.sub_name;
    _brandSt = product.brand;
    _subBrandSt = product.sub_brand;
    _priceSt = product.price.toString();
    _mrpSt = product.mrp.toString();
    _retailPriceSt = product.retail_price.toString();
    _fittingChargeSt = product.fitting_charge.toString();
    _minimumPriceSt = product.minimumPrice != null 
        ? product.minimumPrice!.toStringAsFixed(2) 
        : '';
    _noteSt = product.note;
    
    // Populate category
    _formCategoryId = product.category_id;
    _formCategorySt = productWithDetails.categoryName ?? 'Select Category';
    if (product.category_id != -1) {
      loadSubCategories(product.category_id);
    }
    
    // Populate sub-category
    _formSubCategoryId = product.sub_category_id;
    _formSubCategorySt = productWithDetails.subCategoryName ?? 'Select Sub-Category';
    
    // Populate supplier
    _formSupplierId = product.default_supp_id;
    _formSupplierSt = productWithDetails.supplierName ?? 'Select Supplier';
    _formAutoSentEnable = product.auto_sendto_supplier_flag;
    
    // Populate base unit
    _formBaseUnitId = product.base_unit_id;
    _formBaseUnitSt = productWithDetails.baseUnitName ?? 'Select Base unit';
    
    notifyListeners();
  }

  // ============================================================================
  // Duplicate Checking Methods
  // ============================================================================

  /// Check if code already exists
  Future<bool> checkCodeExists(String code) async {
    final result = await _productsRepository.getProductsByCode(code);
    return result.fold(
      (failure) => false,
      (products) => products.isNotEmpty,
    );
  }

  /// Check if name already exists
  Future<bool> checkNameExists(String name) async {
    final result = await _productsRepository.getProductsByName(name);
    return result.fold(
      (failure) => false,
      (products) => products.isNotEmpty,
    );
  }

  /// Check if barcode already exists
  Future<bool> checkBarcodeExists(String barcode) async {
    if (barcode.isEmpty) return false;
    final result = await _productsRepository.getProductsByBarcode(barcode);
    return result.fold(
      (failure) => false,
      (products) => products.isNotEmpty,
    );
  }

  /// Check if code already exists (excluding specific product ID)
  /// Used for update operations to allow keeping the same code
  Future<bool> checkCodeExistsWithId(String code, int productId) async {
    final result = await _productsRepository.getProductsByCodeWithId(
      code: code,
      productId: productId,
    );
    return result.fold(
      (failure) => false,
      (products) => products.isNotEmpty,
    );
  }

  /// Check if name already exists (excluding specific product ID)
  /// Used for update operations to allow keeping the same name
  Future<bool> checkNameExistsWithId(String name, int productId) async {
    final result = await _productsRepository.getProductsByNameWithId(
      name: name,
      productId: productId,
    );
    return result.fold(
      (failure) => false,
      (products) => products.isNotEmpty,
    );
  }

  /// Check if barcode already exists (excluding specific product ID)
  /// Used for update operations to allow keeping the same barcode
  Future<bool> checkBarcodeExistsWithId(String barcode, int productId) async {
    if (barcode.isEmpty) return false;
    final result = await _productsRepository.getProductsByBarcodeWithId(
      barcode: barcode,
      productId: productId,
    );
    return result.fold(
      (failure) => false,
      (products) => products.isNotEmpty,
    );
  }

  /// Create product via API and update local DB
  /// Validates duplicates before creating
  Future<String?> createProduct() async {
    // Validate required fields
    if (_codeSt.isEmpty) {
      return 'Enter Code';
    }
    if (_nameSt.isEmpty) {
      return 'Enter Name';
    }
    if (_formBaseUnitId == -1) {
      return 'Select Base Unit';
    }
    final priceValue = double.tryParse(_priceSt) ?? 0.0;
    if (priceValue <= 0.0) {
      return 'Enter Price';
    }

    // Check duplicates
    final codeExists = await checkCodeExists(_codeSt);
    if (codeExists) {
      return 'Code already Exist';
    }

    final nameExists = await checkNameExists(_nameSt);
    if (nameExists) {
      return 'Name already Exist';
    }

    if (_barcodeSt.isNotEmpty) {
      final barcodeExists = await checkBarcodeExists(_barcodeSt);
      if (barcodeExists) {
        return 'Barcode already Exist';
      }
    }
    // Create product object
    final photoBase64 = _imageBytes != null
        ? 'data:image/jpeg;base64,${base64Encode(_imageBytes!)}'
        : '';
        
    final product = Product(
      name: _nameSt,
      code: _codeSt,
      barcode: _barcodeSt,
      sub_name: _subNameSt,
      brand: _brandSt,
      sub_brand: _subBrandSt,
      category_id: _formCategoryId,
      sub_category_id: _formSubCategoryId,
      default_supp_id: _formSupplierId,
      auto_sendto_supplier_flag: _formAutoSentEnable,
      base_unit_id: _formBaseUnitId,
      default_unit_id: _formBaseUnitId, // Use base unit as default
      price: priceValue,
      mrp: double.tryParse(_mrpSt) ?? 0.0,
      retail_price: double.tryParse(_retailPriceSt) ?? 0.0,
      fitting_charge: double.tryParse(_fittingChargeSt) ?? 0.0,
      minimumPrice: _minimumPriceSt.isNotEmpty 
          ? double.tryParse(_minimumPriceSt) 
          : null,
      note: _noteSt,
      photo: photoBase64,
    );

    _setLoading(true);
    _clearError();

    final result = await _productsRepository.createProduct(product);

    String? error;
    result.fold(
      (failure) => error = failure.message,
      (createdProduct) {
        // Success - reset form and reload products
        resetForm();
        loadProducts();
      },
    );

    _setLoading(false);
    return error;
  }

  /// Update product via API and update local DB
  /// Matches KMP's EditProductScreen updateProduct (lines 635-646)
  Future<String?> updateProduct(int productId) async {
    // Validate required fields
    if (_codeSt.isEmpty) {
      return 'Enter Code';
    }
    if (_nameSt.isEmpty) {
      return 'Enter Name';
    }
    if (_formBaseUnitId == -1) {
      return 'Select Base Unit';
    }
    final priceValue = double.tryParse(_priceSt) ?? 0.0;
    if (priceValue <= 0.0) {
      return 'Enter Price';
    }

    // Check duplicates (excluding current product) - matches KMP lines 223-239
    final codeExists = await checkCodeExistsWithId(_codeSt, productId);
    if (codeExists) {
      return 'Code already Exist';
    }

    final nameExists = await checkNameExistsWithId(_nameSt, productId);
    if (nameExists) {
      return 'Name already Exist';
    }

    if (_barcodeSt.isNotEmpty) {
      final barcodeExists = await checkBarcodeExistsWithId(_barcodeSt, productId);
      if (barcodeExists) {
        return 'Barcode already Exist';
      }
    }

    // Handle photo: Send base64 if new image selected, empty string otherwise
    // Matches KMP's updateProductParams line 306
    // Backend expects: base64 string (to update) OR empty string (to preserve)
    // DO NOT send photo URL - backend will try to process it as base64 and fail
    final photoBase64 = _imageBytes != null
        ? 'data:image/jpeg;base64,${base64Encode(_imageBytes!)}'
        : ''; // Empty string = preserve existing photo

    final product = Product(
      productId: productId,
      name: _nameSt,
      code: _codeSt,
      barcode: _barcodeSt,
      sub_name: _subNameSt,
      brand: _brandSt,
      sub_brand: _subBrandSt,
      category_id: _formCategoryId,
      sub_category_id: _formSubCategoryId,
      default_supp_id: _formSupplierId,
      auto_sendto_supplier_flag: _formAutoSentEnable,
      base_unit_id: _formBaseUnitId,
      default_unit_id: _formBaseUnitId, // Use base unit as default
      price: priceValue,
      mrp: double.tryParse(_mrpSt) ?? 0.0,
      retail_price: double.tryParse(_retailPriceSt) ?? 0.0,
      fitting_charge: double.tryParse(_fittingChargeSt) ?? 0.0,
      minimumPrice: _minimumPriceSt.isNotEmpty 
          ? double.tryParse(_minimumPriceSt) 
          : null,
      note: _noteSt,
      photo: photoBase64,
    );

    _setLoading(true);
    _clearError();

    final result = await _productsRepository.updateProduct(product);

    String? error;
    result.fold(
      (failure) => error = failure.message,
      (updatedProduct) {
        // Success - reload products
        loadProducts();
      },
    );

    _setLoading(false);
    return error;
  }

  // ============================================================================
  // Private Helper Methods
  // ============================================================================

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}

