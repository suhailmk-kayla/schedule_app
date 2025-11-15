import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../utils/asset_images.dart';
import '../../../provider/cars_provider.dart';
import '../../../../models/cars.dart';
import 'cars_details_screen.dart';
import 'create_car_screen.dart';

/// Cars List Screen
/// Displays list of cars with search
/// Converted from KMP's CarsListScreen.kt
class CarsListScreen extends StatefulWidget {
  const CarsListScreen({super.key});

  @override
  State<CarsListScreen> createState() => _CarsListScreenState();
}

class _CarsListScreenState extends State<CarsListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CarsProvider>(context, listen: false);
      provider.getCars();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch(String searchKey) {
    final provider = Provider.of<CarsProvider>(context, listen: false);
    provider.getCars(searchKey: searchKey);
  }

  void _handleItemClick(Cars car) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarsDetailsScreen(car: car),
      ),
    );
  }

  void _handleAddNew() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateCarScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car List'),
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
                hintText: 'Search cars...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _handleSearch,
              onSubmitted: _handleSearch,
            ),
          ),
          // Cars list
          Expanded(
            child: Consumer<CarsProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.carsList.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null &&
                    provider.carsList.isEmpty) {
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
                          onPressed: () => provider.getCars(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.carsList.isEmpty) {
                  return const Center(
                    child: Text(
                      'No cars found',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: provider.carsList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final car = provider.carsList[index];
                    return _CarListItem(
                      car: car,
                      onTap: () => _handleItemClick(car),
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

/// Car List Item Widget
/// Converted from KMP's ListItem composable
class _CarListItem extends StatelessWidget {
  final Cars car;
  final VoidCallback onTap;

  const _CarListItem({
    required this.car,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(width: 8),
              // Car icon
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(5),
                child: Image.asset(AssetImages.imagesCars),
              ),
              // Car details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        car.carName?.carName ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Brand: ${car.carBrand}',
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

