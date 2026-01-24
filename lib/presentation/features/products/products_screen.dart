import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/helpers/image_url_handler.dart';
import 'package:schedule_frontend_flutter/utils/storage_helper.dart';
import 'package:schedule_frontend_flutter/utils/notification_manager.dart';
import 'package:schedule_frontend_flutter/utils/toast_helper.dart';
import '../../provider/products_provider.dart';
import '../../provider/orders_provider.dart';
import '../../../models/product_api.dart';
import 'product_details_screen.dart';
import 'create_product_screen.dart';
import '../orders/add_product_to_order_dialog.dart';

class ProductsScreen extends StatefulWidget {
  final String? orderId; // If provided, this is selection mode for order
  final String? orderSubId; // If provided, this is for replacing order sub
  final bool isOutOfStock; // If true, shows out of stock products
  final bool selectForSuggestion; // If true, select product for suggestion list
  final ValueChanged<Product>? onProductSelected;

  const ProductsScreen({
    super.key,
    this.orderId,
    this.orderSubId,
    this.isOutOfStock = false,
    this.selectForSuggestion = false,
    this.onProductSelected,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSearchBar = false;
  static const bool isShowAddOrder = true; // Show FAB for admin

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ProductsProvider>(context, listen: false);
      // If orderId is provided, only load products if search key is long enough (matches KMP)
      // Simplify: load products on init; search filtering handled in provider calls
      provider.loadProducts();
      provider.loadCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        // Clear search when closing
        _searchController.clear();
        final provider = Provider.of<ProductsProvider>(context, listen: false);
        _handleSearch(provider, '');
      }
    });
    // Focus search field when opened
    if (_showSearchBar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationManager>(
      builder: (context, notificationManager, _) {
        // Listen to notification trigger and refresh data
        if (notificationManager.notificationTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final provider = Provider.of<ProductsProvider>(context, listen: false);
            provider.loadProducts(searchKey: _searchController.text.trim());
            notificationManager.resetTrigger();
          });
        }

        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop && mounted) {
              final provider = Provider.of<ProductsProvider>(context, listen: false);
              provider.clearFilters();
            }
          },
          child: Scaffold(
            
            appBar: AppBar(
              
              title: _showSearchBar
                  ? TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        final provider = Provider.of<ProductsProvider>(context, listen: false);
                        _handleSearch(provider, value.trim());
                      },
                    )
                  : const Text('Products'),
              leading: (widget.orderId != null && widget.orderId!.isNotEmpty)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              actions: [
                IconButton(
                  icon: Icon(_showSearchBar ? Icons.close : Icons.search),
                  onPressed: _toggleSearchBar,
                ),
              ],
            ),
            body: Consumer<ProductsProvider>(
              builder: (context, provider, _) {
            return Column(
              children: [
                // Filters: Category and SubCategory
                SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          icon: SizedBox.shrink(),
                          // icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          value: provider.filterCategoryId,
                          items: [
                            // "All Category" option (matches KMP)
                            const DropdownMenuItem<int>(
                              value: -1,
                              child: Text('All Category',
                               maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                            ...provider.categoryList.map(
                              (c) => DropdownMenuItem<int>(
                                value: c.categoryId,
                                child: Text(c.name,
                                maxLines: 1,
                                style: TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                ),
                              ),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            // isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          // icon: const Icon(Icons.arrow_drop_down),
                          onChanged: (val) {
                            if (val == null) return;
                            final categoryId = val;
                            final categoryName = categoryId == -1
                                ? 'All Category'
                                : provider.categoryList
                                    .firstWhere((c) => c.categoryId == categoryId)
                                    .name;
                            provider.setCategoryFilter(categoryId, categoryName);
                            provider.loadSubCategories(categoryId);
                            provider.loadProducts(searchKey: _searchController.text.trim());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,

                          icon: SizedBox.shrink(),
                          // icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          value: provider.filterSubCategoryId == -1
                              ? null
                              : provider.filterSubCategoryId,
                          hint: const Text('Sub Category',
                          maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                          ),
                          items: [
                            ...provider.subCategoryList.map(
                              (s) => DropdownMenuItem<int>(
                                value: s.subCategoryId,
                                child: Text(s.name,
                                maxLines: 1,
                                style: TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                ),
                              ),
                            ),
                          ],
                          decoration: const InputDecoration(
                           
                            labelText: 'Sub Category',
                            border: OutlineInputBorder(),
                            // isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          // icon: const Icon(Icons.arrow_drop_down),
                          onChanged: (val) {
                            final subId = val ?? -1;
                            final subName = subId == -1
                                ? 'Sub Category'
                                : provider.subCategoryList
                                    .firstWhere((s) => s.subCategoryId == subId)
                                    .name;
                            provider.setSubCategoryFilter(subId, subName);
                            provider.loadProducts(searchKey: _searchController.text.trim());
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          
                const SizedBox(height: 8),
          
                if (provider.isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (provider.errorMessage != null)
                  Expanded(
                    child: Center(
                      child: Text(
                        provider.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  )
                  else if (provider.productList.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text('No products found'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: provider.productList.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = provider.productList[index];
                        return InkWell(
                          onTap: () {
                            if (widget.selectForSuggestion &&
                                widget.onProductSelected != null) {
                              widget.onProductSelected!(p);
                              // Don't pop - keep screen open for multiple selections
                              return;
                            }
                            if (widget.orderId != null && widget.orderId!.isNotEmpty) {
                              // Selection mode - show bottom sheet to add product to order
                              _showAddProductDialog(context, p);
                            } else {
                              // Normal mode - navigate to product details
                              Navigator.push(
                                context,
                                MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(productId: p.productId),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image (flex: 1)
                                Expanded(
                                  flex: 1,
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: ProductImage(url: p.photo),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Center content (flex: 3)
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text('Code: ${p.code}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 14, color: Colors.blue,fontWeight: FontWeight.w600),
                                          ),

                                      Text('Brand: ${p.brand}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                     
                                        const SizedBox(height: 2),
                                        Text('Sub Brand: ${p.sub_brand}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                     
                                      const SizedBox(height: 4),
                                      Text(
                                        'MRP: ${p.mrp.toStringAsFixed(2)}',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Right price (flex: 1)
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      SizedBox(height: 50),
                                      const Text(
                                        'Price',
                                        style: TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                      Text(
                                        p.price.toStringAsFixed(2),
                                        style:  TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
                ),
                floatingActionButton: FutureBuilder<int>(
          future: StorageHelper.getUserType(),
          builder: (context, snapshot) {
            final isAdmin = snapshot.data == 1;
            if (isShowAddOrder && isAdmin) {
              return FloatingActionButton(
                onPressed: _handleAddNew,
                backgroundColor: Colors.black,
                child: const Icon(Icons.add, color: Colors.white),
              );
            }
            return const SizedBox.shrink();
          },
                ),
          ),
        );
      },
    );
  }

  void _handleSearch(ProductsProvider provider, String searchKey) {
    // If orderId is provided, only search if search key is long enough (matches KMP)
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      if (searchKey.length > 2) {
        provider.loadProducts(searchKey: searchKey);
      } else {
        // Clear product list if search key is too short (matches KMP's setEmptyList)
        // Load with empty search key which will return empty results
        provider.loadProducts(searchKey: '');
      }
    } else {
      // Normal mode - search immediately
      provider.loadProducts(searchKey: searchKey);
    }
  }

  void _handleAddNew() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateProductScreen(),
      ),
    );
  }

  void _showAddProductDialog(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddProductToOrderDialog(
        product: product,
        orderId: widget.orderId!,
        onSave: (rate, quantity, narration, unitId, {bool replace = false}) async {
          final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
          
          // Check if orderMaster is set (draft order) or null (existing order)
          final bool isDraftOrder = ordersProvider.orderMaster != null;
          final int orderIdInt = int.tryParse(widget.orderId!) ?? -1;
          
          bool success;
          if (isDraftOrder) {
            // Use addProductToOrder for draft orders (requires orderMaster)
            success = await ordersProvider.addProductToOrder(
              productId: product.productId,
              productPrice: product.price, // Product's base price
              rate: rate, // User-entered rate
              quantity: quantity,
              narration: narration,
              unitId: unitId,
            );
          } else {
            // Use addProductToExistingOrder for existing sent orders
            success = await ordersProvider.addProductToExistingOrder(
              orderId: orderIdInt,
              productId: product.productId,
              productPrice: product.price,
              rate: rate,
              quantity: quantity,
              narration: narration,
              unitId: unitId,
            );
          }
          
          if (success && mounted) {
            Navigator.pop(context); // Close bottom sheet
            // Don't pop ProductsScreen - let user add more products
            ToastHelper.showSuccess('Product added to order');
            // ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(content: Text('Product added to order')),
            // );
          } else if (mounted) {
            ToastHelper.showWarning(ordersProvider.errorMessage ?? 'Failed to add product');
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text(ordersProvider.errorMessage ?? 'Failed to add product'),
            //   ),
            // );
          }
        },
      ),
    );
  }
}

class ProductImage extends StatelessWidget {
  final String url;
  const ProductImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.photo, color: Colors.grey),
      );
    }
    return Image.network(
      ImageUrlFixer.fix(url),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.grey.shade100,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}
