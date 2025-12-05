import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../utils/asset_images.dart';
import '../../../provider/units_provider.dart';
import '../../../../models/master_data_api.dart';
import 'create_unit_screen.dart';
import 'unit_details_screen.dart';

/// Units List Screen
/// Displays list of units with search and navigation
/// Converted from KMP's UnitListScreen.kt
class UnitsListScreen extends StatefulWidget {
  const UnitsListScreen({super.key});

  @override
  State<UnitsListScreen> createState() => _UnitsListScreenState();
}

class _UnitsListScreenState extends State<UnitsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<UnitsProvider>(context, listen: false);
      provider.getUnits();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearch(String searchKey) {
    final provider = Provider.of<UnitsProvider>(context, listen: false);
    provider.getUnits(searchKey: searchKey.trim());
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

  void _handleItemClick(Units unit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UnitDetailsScreen(unit: unit),
      ),
    );
  }

  void _handleAddNew() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateUnitScreen(),
      ),
    ).then((_) {
      // Refresh list after returning from create screen
      final provider = Provider.of<UnitsProvider>(context, listen: false);
      provider.getUnits(searchKey: _searchController.text);
    });
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
            : const Text('Unit List'),
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
          // Units list
          Expanded(
            child: Consumer<UnitsProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.unitsList.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null && provider.unitsList.isEmpty) {
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
                          onPressed: () => provider.getUnits(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.unitsList.isEmpty) {
                  return const Center(
                    child: Text(
                      'No units found',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: provider.unitsList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final unit = provider.unitsList[index];
                    return _UnitListItem(
                      unit: unit,
                      onTap: () => _handleItemClick(unit),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleAddNew,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

/// Unit List Item Widget
/// Converted from KMP's ListItem composable
class _UnitListItem extends StatelessWidget {
  final Units unit;
  final VoidCallback onTap;

  const _UnitListItem({
    required this.unit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unitType = unit.type == 0 ? 'Base unit' : 'Derived Unit';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            children: [
              const SizedBox(width: 4),
              // Unit icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.asset(AssetImages.imagesUnits),
              ),
              const SizedBox(width: 5),
              // Unit details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      unit.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Code: ${unit.code}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      'Display: ${unit.displayName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      'Type: $unitType',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

