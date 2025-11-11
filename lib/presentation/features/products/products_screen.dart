import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/products_provider.dart';
import 'product_details_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ProductsProvider>(context, listen: false);
      provider.loadProducts();
      provider.loadCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
      ),
      body: Consumer<ProductsProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search by code, name, brand...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (value) {
                          provider.loadProducts(searchKey: value.trim());
                        },
                        onChanged: (value) {
                          // simple immediate search for now
                          provider.loadProducts(searchKey: value.trim());
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Filters: Category and SubCategory
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: provider.filterCategoryId == -1
                            ? null
                            : provider.filterCategoryId,
                        items: [
                          const DropdownMenuItem<int>(
                            value: -1,
                            child: Text('All Category'),
                          ),
                          ...provider.categoryList.map(
                            (c) => DropdownMenuItem<int>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          final categoryId = val ?? -1;
                          final categoryName = categoryId == -1
                              ? 'All Category'
                              : provider.categoryList
                                  .firstWhere((c) => c.id == categoryId)
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
                        value: provider.filterSubCategoryId == -1
                            ? null
                            : provider.filterSubCategoryId,
                        items: [
                          const DropdownMenuItem<int>(
                            value: -1,
                            child: Text('Sub Category'),
                          ),
                          ...provider.subCategoryList.map(
                            (s) => DropdownMenuItem<int>(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Sub Category',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          final subId = val ?? -1;
                          final subName = subId == -1
                              ? 'Sub Category'
                              : provider.subCategoryList
                                  .firstWhere((s) => s.id == subId)
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
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: provider.productList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = provider.productList[index];
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailsScreen(productId: p.id),
                            ),
                          );
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
                                    child: _ProductImage(url: (p.photo ?? p.photo ?? '').toString()),
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
                                    const Text(
                                      'Price',
                                      style: TextStyle(fontSize: 12, color: Colors.black54),
                                    ),
                                    Text(
                                      p.price.toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
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
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String url;
  const _ProductImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.photo, color: Colors.grey),
      );
    }
    return Image.network(
      url,
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
