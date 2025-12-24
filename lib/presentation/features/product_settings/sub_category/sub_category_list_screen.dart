import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../utils/asset_images.dart';
import '../../../provider/sub_categories_provider.dart';
import '../../../../models/master_data_api.dart';

/// Sub Category List Screen
/// Displays list of sub-categories with search and inline add/edit dialog
/// Converted from KMP's SubCategoryListScreen.kt
class SubCategoryListScreen extends StatefulWidget {
  const SubCategoryListScreen({super.key});

  @override
  State<SubCategoryListScreen> createState() => _SubCategoryListScreenState();
}

class _SubCategoryListScreenState extends State<SubCategoryListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSearchBar = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<SubCategoriesProvider>(context, listen: false);
      provider.getSubCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearch(String searchKey) {
    final provider = Provider.of<SubCategoriesProvider>(context, listen: false);
    provider.getSubCategories(searchKey: searchKey.trim());
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

  void _handleEditClick(SubCategoryWithCategory subCategoryWithCategory) {
    _showSubCategoryDialog(
      isEdit: true,
      subCategory: subCategoryWithCategory.subCategory,
      categoryName: subCategoryWithCategory.categoryName,
    );
  }

  void _handleAddClick() {
    _showSubCategoryDialog(isEdit: false);
  }

  void _showSubCategoryDialog({
    bool isEdit = false,
    SubCategory? subCategory,
    String categoryName = '',
  }) {
    showDialog(
      context: context,
      builder: (context) => _AddSubCategoryDialog(
        isAddNew: !isEdit,
        subCategory: subCategory,
        categoryName: categoryName,
        onDismissRequest: () {
          Navigator.pop(context);
        },
        onConfirmation: (parentId, subCategoryId, subCategoryName) async {
          Navigator.pop(context);
          await _handleSave(subCategoryName, isEdit, subCategoryId, parentId);
        },
      ),
    );
  }

  Future<void> _handleSave(
    String subCategoryName,
    bool isEdit,
    int subCategoryId,
    int parentId,
  ) async {
    if (parentId == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select category')),
      );
      return;
    }

    if (subCategoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter Sub-category name')),
      );
      return;
    }

    final provider = Provider.of<SubCategoriesProvider>(context, listen: false);
    final success = isEdit
        ? await provider.updateSubCategory(
            subCategoryId: subCategoryId,
            parentId: parentId,
            name: subCategoryName,
          )
        : await provider.createSubCategory(
            name: subCategoryName,
            parentId: parentId,
          );

    if (success) {
      // Refresh list
      provider.getSubCategories(searchKey: _searchController.text);
      if (!isEdit) {
        _errorMessage = 'Sub-Category Added successfully';
        _showErrorDialog();
      }
    } else {
      _errorMessage = provider.errorMessage ?? 'Failed to save sub-category';
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
            : const Text('Sub Category List'),
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
          // Sub-categories list
          Expanded(
            child: Consumer<SubCategoriesProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.subCategoriesList.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null &&
                    provider.subCategoriesList.isEmpty) {
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
                          onPressed: () => provider.getSubCategories(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.subCategoriesList.isEmpty) {
                  return const Center(
                    child: Text(
                      'No Category found',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: provider.subCategoriesList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final subCategoryWithCategory =
                        provider.subCategoriesList[index];
                    return _SubCategoryListItem(
                      subCategoryWithCategory: subCategoryWithCategory,
                      onEditTap: () =>
                          _handleEditClick(subCategoryWithCategory),
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

/// Sub Category List Item Widget
/// Converted from KMP's ListItem composable
class _SubCategoryListItem extends StatelessWidget {
  final SubCategoryWithCategory subCategoryWithCategory;
  final VoidCallback onEditTap;

  const _SubCategoryListItem({
    required this.subCategoryWithCategory,
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
            // Sub-category icon
            Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(5),
              child: Image.asset(AssetImages.imagesSubCategory),
            ),
            // Sub-category details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      subCategoryWithCategory.subCategory.name,
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Category: ${subCategoryWithCategory.categoryName}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
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

/// Add/Edit Sub Category Dialog
/// Converted from KMP's AddCategoryDialog composable
class _AddSubCategoryDialog extends StatefulWidget {
  final bool isAddNew;
  final SubCategory? subCategory;
  final String categoryName;
  final VoidCallback onDismissRequest;
  final Function(int, int, String) onConfirmation;

  const _AddSubCategoryDialog({
    required this.isAddNew,
    this.subCategory,
    this.categoryName = '',
    required this.onDismissRequest,
    required this.onConfirmation,
  });

  @override
  State<_AddSubCategoryDialog> createState() => _AddSubCategoryDialogState();
}

class _AddSubCategoryDialogState extends State<_AddSubCategoryDialog> {
  late TextEditingController _nameController;
  int _categoryId = -1;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.subCategory?.name ?? '',
    );
    if (widget.isAddNew) {
      // Load categories for selection
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider =
            Provider.of<SubCategoriesProvider>(context, listen: false);
        provider.getAllCategories();
      });
    } else {
      // Edit mode - set category from sub-category
      _categoryId = widget.subCategory?.catId ?? -1;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isAddNew ? 'Add Sub Category' : 'Update Sub Category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Category selection dropdown
          Consumer<SubCategoriesProvider>(
            builder: (context, provider, _) {
              return DropdownButtonFormField<int>(
                value: _categoryId == -1 ? null : _categoryId,
                decoration: const InputDecoration(
                  // suffixIcon: Icon(Icons.arrow_drop_down),
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                hint: const Text('Select Category'),
                items: provider.categoriesList.map((category) {
                  return DropdownMenuItem<int>(
                    value: category.categoryId, // Use server ID, not local DB primary key
                    child: Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: widget.isAddNew
                    ? (value) {
                        if (value != null) {
                          setState(() {
                            _categoryId = value;
                          });
                        }
                      }
                    : null, // Disabled in edit mode
                validator: (value) {
                  if (value == null || value == -1) {
                    return 'Please select a category';
                  }
                  return null;
                },
              );
            },
          ),
          const SizedBox(height: 16),
          // Sub-category name
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Sub Category Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onDismissRequest,
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_categoryId == -1) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Select category')),
              );
              return;
            }
            if (_nameController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter Sub-category name')),
              );
              return;
            }
            widget.onConfirmation(
              _categoryId,
              widget.subCategory?.subCategoryId ?? -1, // Use server ID, not local DB primary key
              _nameController.text.trim(),
            );
          },
          child: Text(widget.isAddNew ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}

