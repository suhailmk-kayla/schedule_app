import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../utils/asset_images.dart';
import '../../../provider/categories_provider.dart';
import '../../../../models/master_data_api.dart';

/// Category List Screen
/// Displays list of categories with search and inline add/edit dialog
/// Converted from KMP's CategoryListScreen.kt
class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSearchBar = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CategoriesProvider>(context, listen: false);
      provider.getCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearch(String searchKey) {
    final provider = Provider.of<CategoriesProvider>(context, listen: false);
    provider.getCategories(searchKey: searchKey.trim());
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        // Clear search when closing
        _searchController.clear();
        _handleSearch('');
      }
    });
    // Focus search field when opened
    if (_showSearchBar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  void _handleEditClick(Category category) {
    _showCategoryDialog(
      isEdit: true,
      categoryName: category.name,
      categoryId: category.id,
    );
  }

  void _handleAddClick() {
    _showCategoryDialog(isEdit: false);
  }

  void _showCategoryDialog({
    bool isEdit = false,
    String categoryName = '',
    int categoryId = 0,
  }) {
    showDialog(
      context: context,
      builder: (context) => _AddCategoryDialog(
        isAddNew: !isEdit,
        name: categoryName,
        onDismissRequest: () {
          Navigator.pop(context);
        },
        onConfirmation: (name) async {
          Navigator.pop(context);
          await _handleSave(name, isEdit, categoryId);
        },
      ),
    );
  }

  Future<void> _handleSave(
    String categoryName,
    bool isEdit,
    int categoryId,
  ) async {
    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter category name')),
      );
      return;
    }

    final provider = Provider.of<CategoriesProvider>(context, listen: false);
    final success = isEdit
        ? await provider.updateCategory(
            categoryId: categoryId,
            name: categoryName,
          )
        : await provider.createCategory(name: categoryName);

    if (success) {
      // Refresh list
      provider.getCategories(searchKey: _searchController.text);
      if (!isEdit) {
        _errorMessage = 'Category Added successfully';
        _showErrorDialog();
      }
    } else {
      _errorMessage = provider.errorMessage ?? 'Failed to save category';
      _showErrorDialog();
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message'),
        content: Text(_errorMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  _handleSearch(value);
                },
              )
            : const Text('Category List'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_showSearchBar ? Icons.close : Icons.search),
            onPressed: _toggleSearchBar,
          ),
        ],
      ),
      body: Column(
        children: [
          // Categories list
          Expanded(
            child: Consumer<CategoriesProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.categoriesList.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null &&
                    provider.categoriesList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          provider.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.getCategories(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.categoriesList.isEmpty) {
                  return const Center(
                    child: Text(
                      'No Category found',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: provider.categoriesList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final category = provider.categoriesList[index];
                    return _CategoryListItem(
                      category: category,
                      onEditTap: () => _handleEditClick(category),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleAddClick,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

/// Category List Item Widget
/// Converted from KMP's ListItem composable
class _CategoryListItem extends StatelessWidget {
  final Category category;
  final VoidCallback onEditTap;

  const _CategoryListItem({
    required this.category,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            const SizedBox(width: 8),
            // Category icon
            Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(5),
              child: Image.asset(AssetImages.imagesCategory),
            ),
            // Category name
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            // Edit icon button
            IconButton(
              icon: const Icon(Icons.edit, size: 24),
              onPressed: onEditTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Add/Edit Category Dialog
/// Converted from KMP's AddCategoryDialog composable
class _AddCategoryDialog extends StatefulWidget {
  final bool isAddNew;
  final String name;
  final VoidCallback onDismissRequest;
  final Function(String) onConfirmation;

  const _AddCategoryDialog({
    required this.isAddNew,
    required this.name,
    required this.onDismissRequest,
    required this.onConfirmation,
  });

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isAddNew ? 'Add Category' : 'Update Category'),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Category Name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: widget.onDismissRequest,
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_nameController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter category name')),
              );
              return;
            }
            widget.onConfirmation(_nameController.text.trim());
          },
          child: Text(widget.isAddNew ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}

