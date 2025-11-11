import 'package:flutter/foundation.dart' hide Category;
import '../../repositories/products/products_repository.dart';
import '../../repositories/categories/categories_repository.dart';
import '../../repositories/sub_categories/sub_categories_repository.dart';
import '../../repositories/units/units_repository.dart';
import '../../models/product_api.dart';
import '../../models/master_data_api.dart';

/// Products Provider
/// Manages product-related state and operations
/// Converted from KMP's ProductViewModel.kt
class ProductsProvider extends ChangeNotifier {
  final ProductsRepository _productsRepository;
  final CategoriesRepository _categoriesRepository;
  final SubCategoriesRepository _subCategoriesRepository;
  final UnitsRepository _unitsRepository;

  ProductsProvider({
    required ProductsRepository productsRepository,
    required CategoriesRepository categoriesRepository,
    required SubCategoriesRepository subCategoriesRepository,
    required UnitsRepository unitsRepository,
  })  : _productsRepository = productsRepository,
        _categoriesRepository = categoriesRepository,
        _subCategoriesRepository = subCategoriesRepository,
        _unitsRepository = unitsRepository {
    // Initialize with categories and base units
    loadCategories();
    loadBaseUnits();
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

  /// Create product via API and update local DB
  Future<bool> createProduct(Product product) async {
    _setLoading(true);
    _clearError();

    final result = await _productsRepository.createProduct(product);

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (createdProduct) {
        success = true;
        // Optionally reload products list
        loadProducts();
      },
    );

    _setLoading(false);
    return success;
  }

  /// Update product via API and update local DB
  Future<bool> updateProduct(Product product) async {
    _setLoading(true);
    _clearError();

    final result = await _productsRepository.updateProduct(product);

    bool success = false;
    result.fold(
      (failure) => _setError(failure.message),
      (updatedProduct) {
        success = true;
        // Optionally reload products list
        loadProducts();
      },
    );

    _setLoading(false);
    return success;
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

