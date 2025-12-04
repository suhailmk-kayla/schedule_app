import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/asset_images.dart';
import 'package:schedule_frontend_flutter/utils/notification_manager.dart';
import '../../provider/salesman_provider.dart';
import '../../../models/salesman_model.dart';
import 'create_salesman_screen.dart';
import 'salesman_details_screen.dart';

/// Salesman Screen
/// Displays list of salesmen with search and navigation
/// Converted from KMP's SalesManScreen.kt
class SalesmanScreen extends StatefulWidget {
  const SalesmanScreen({super.key});

  @override
  State<SalesmanScreen> createState() => _SalesmanScreenState();
}

class _SalesmanScreenState extends State<SalesmanScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<SalesmanProvider>(context, listen: false);
      provider.loadSalesmen();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearch(String searchKey) {
    final provider = Provider.of<SalesmanProvider>(context, listen: false);
    provider.loadSalesmen(searchKey: searchKey);
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

  void _handleItemClick(SalesMan salesman) {
    // Navigate to salesman details screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalesmanDetailsScreen(userId: salesman.userId),
      ),
    );
  }

  void _handleReportViewClick(int userId) {
    // Navigate to SalesmanOrders screen (TODO: implement SalesmanOrdersScreen)
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => SalesmanOrdersScreen(userId: userId),
    //   ),
    // );
  }

  void _handleAddNew() {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateSalesmanScreen(),
      ),
    ).then((created) {
      if (created == true && mounted) {
        Provider.of<SalesmanProvider>(context, listen: false)
            .loadSalesmen(searchKey: _searchController.text.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationManager>(
      builder: (context, notificationManager, _) {
        // Listen to notification trigger and refresh data
        if (notificationManager.notificationTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final provider = Provider.of<SalesmanProvider>(context, listen: false);
            provider.loadSalesmen(searchKey: _searchController.text.trim());
            notificationManager.resetTrigger();
          });
        }

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
            : const Text('Salesman List'),
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
          // Salesmen list
          Expanded(
            child: Consumer<SalesmanProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.salesmanList.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null && provider.salesmanList.isEmpty) {
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
                          onPressed: () => provider.loadSalesmen(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.salesmanList.isEmpty) {
                  return const Center(
                    child: Text(
                      'No salesman found',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: provider.salesmanList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final salesman = provider.salesmanList[index];
                    return _SalesmanListItem(
                      salesman: salesman,
                      onTap: () => _handleItemClick(salesman),
                      onReportTap: () => _handleReportViewClick(salesman.userId),
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
      },
    );
  }
}

/// Salesman List Item Widget
/// Converted from KMP's ListItem composable
class _SalesmanListItem extends StatelessWidget {
  final SalesMan salesman;
  final VoidCallback onTap;
  final VoidCallback onReportTap;

  const _SalesmanListItem({
    required this.salesman,
    required this.onTap,
    required this.onReportTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation:2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              const SizedBox(width: 10),
              // Salesman icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(5),
                child: Image.asset(AssetImages.imagesSalesman),
              ),
              const SizedBox(width: 10),
              // Salesman name and code
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      salesman.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Code: ${salesman.code}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Report/List icon button
              IconButton(
                icon: const Icon(Icons.list_alt, size: 24),
                onPressed: onReportTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

