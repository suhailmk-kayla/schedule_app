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
    super.dispose();
  }

  void _handleSearch(String searchKey) {
    final provider = Provider.of<SalesmanProvider>(context, listen: false);
    provider.loadSalesmen(searchKey: searchKey);
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
        title: const Text('Salesman List'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Show search dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Search'),
                  content: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Enter search key',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      Navigator.pop(context);
                      _handleSearch(value);
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleSearch(_searchController.text);
                      },
                      child: const Text('Search'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search salesmen...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _handleSearch,
              onSubmitted: _handleSearch,
            ),
          ),
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

