import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/cars.dart';
import '../../../provider/products_provider.dart';

/// Cars Details Screen
/// Displays car details with models and versions
/// Converted from KMP's CarsDetailsScreen.kt
class CarsDetailsScreen extends StatefulWidget {
  final Cars car;
  final int? productId; // If provided, this is for adding car to product

  const CarsDetailsScreen({
    super.key,
    required this.car,
    this.productId,
  });

  @override
  State<CarsDetailsScreen> createState() => _CarsDetailsScreenState();
}

class _CarsDetailsScreenState extends State<CarsDetailsScreen> {
  bool _isLoading = false;

  Future<void> _handleAddCarToProduct() async {
    if (widget.productId == null || widget.productId == -1) return;

    final productsProvider = Provider.of<ProductsProvider>(context, listen: false);
    
    // Get brand and name IDs
    final brandId = widget.car.carName?.carBrandId ?? -1;
    final nameId = widget.car.carName?.carNameId ?? -1;

    if (brandId == -1 || nameId == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Car brand or name not found')),
      );
      return;
    }

    // Build selectedMap: For now, add all models with all versions
    // Format: Map<String, Map<int, List<int>>> where:
    // - Key: modelId as String
    // - Value: Map with versionId as key and empty list as value
    final Map<String, Map<int, List<int>>> selectedMap = {};
    
    for (final modelAndVersion in widget.car.carModelList) {
      final modelId = modelAndVersion.carModel.carModelId;
      
      if (modelId == -1) continue;
      
      final versionMap = <int, List<int>>{};
      
      if (modelAndVersion.carVersionList.isEmpty) {
        // If no versions, add with version_id = -1 (all versions)
        versionMap[-1] = [];
      } else {
        // Add each version
        for (final version in modelAndVersion.carVersionList) {
          if (version.carVersionId != -1) {
            versionMap[version.carVersionId] = [];
          }
        }
      }
      
      if (versionMap.isNotEmpty) {
        selectedMap[modelId.toString()] = versionMap;
      }
    }

    setState(() {
      _isLoading = true;
    });

    final error = await productsProvider.addCarToProduct(
      productId: widget.productId!,
      brandId: brandId,
      nameId: nameId,
      selectedMap: selectedMap,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Car successfully added to product')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand
            const Text(
              'Brand',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.car.carBrand,
                style: const TextStyle(color: Colors.black),
              ),
            ),
            const SizedBox(height: 16),
            // Name
            const Text(
              'Name',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.car.carName?.carName ?? '',
                style: const TextStyle(color: Colors.black),
              ),
            ),
            const SizedBox(height: 16),
            // Models
            const Text(
              'Models',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.car.carModelList.isEmpty)
              const Text(
                'No models found',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...widget.car.carModelList.map((modelAndVersion) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Model: ${modelAndVersion.carModel.modelName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (modelAndVersion.carVersionList.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Versions: ${modelAndVersion.carVersionList.map((v) => v.versionName).join(', ')}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
          ],
        ),
      ),
      // Add Car to Product button (only when productId is provided)
      floatingActionButton: widget.productId != null && widget.productId != -1
          ? FloatingActionButton.extended(
              onPressed: _isLoading ? null : _handleAddCarToProduct,
              backgroundColor: Colors.black,
              label: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Add Car to Product',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
            )
          : null,
    );
  }
}

