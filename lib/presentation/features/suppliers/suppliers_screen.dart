import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/suppliers_provider.dart';
import '../../../models/supplier_model.dart';
import '../../../utils/asset_images.dart';
import '../../../utils/storage_helper.dart';
import 'create_supplier_screen.dart';
import 'supplier_details_screen.dart';
import '../out_of_stock/out_of_stock_list_supplier_screen.dart';

/// Suppliers Screen
/// Displays list of suppliers with search functionality
/// Converted from KMP's SuppliersScreen.kt
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_)async{
      final provider = Provider.of<SuppliersProvider>(context, listen: false);
      await provider.getSuppliers();
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
        title: _showSearchBar
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  final provider = Provider.of<SuppliersProvider>(context, listen: false);
                  provider.getSuppliers(searchKey: value);
                },
              )
            : const Text('Suppliers List'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_showSearchBar ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchController.clear();
                  final provider = Provider.of<SuppliersProvider>(context, listen: false);
                  provider.getSuppliers();
                }
              });
            },
          ),
        ],
      ),
      body: Consumer<SuppliersProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.suppliersList.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null && provider.suppliersList.isEmpty) {
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
                    onPressed: () => provider.getSuppliers(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.suppliersList.isEmpty) {
            return const Center(
              child: Text(
                'No supplier found',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.suppliersList.length,
            itemBuilder: (context, index) {
              final supplier = provider.suppliersList[index];
              return _SupplierListItem(
                supplier: supplier,
                onTap: () {
                  // Navigate to supplier details screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupplierDetailsScreen(userId: supplier.userId ?? -1),
                    ),
                  );
                },
                onReportTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OutOfStockListSupplierScreen(
                        userId: supplier.userId ?? -1,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<int>(
        future: StorageHelper.getUserType(),
        builder: (context, snapshot) {
          final isAdmin = snapshot.data == 1;
          if (!isAdmin) {
            return const SizedBox.shrink();
          }
          final suppliersProvider = Provider.of<SuppliersProvider>(context, listen: false);
          return FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateSupplierScreen(),
                ),
              ).then((result) {
                if (!mounted) return;
                if (result == true) {
                  suppliersProvider.getSuppliers();
                }
              });
            },
            backgroundColor: Colors.black,
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
    );
  }
}

class _SupplierListItem extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onTap;
  final VoidCallback onReportTap;

  const _SupplierListItem({
    required this.supplier,
    required this.onTap,
    required this.onReportTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 4.0,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            children: [
              const SizedBox(width: 10),
              // Supplier icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(5),
                child: Image.asset(
                  AssetImages.imagesSupplier,
                  width: 32,
                  height: 32,
                ),
              ),
              const SizedBox(width: 10),
              // Supplier details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      supplier.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Code: ${supplier.code}',
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Report/List icon button
              IconButton(
                icon: const Icon(Icons.list_alt),
                onPressed: onReportTap,
                tooltip: 'View Orders',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

