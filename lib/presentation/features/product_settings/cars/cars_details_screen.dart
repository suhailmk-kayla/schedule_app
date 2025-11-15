import 'package:flutter/material.dart';
import '../../../../models/cars.dart';

/// Cars Details Screen
/// Displays car details with models and versions
/// Converted from KMP's CarsDetailsScreen.kt
class CarsDetailsScreen extends StatelessWidget {
  final Cars car;

  const CarsDetailsScreen({
    super.key,
    required this.car,
  });

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
                car.carBrand,
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
                car.carName?.carName ?? '',
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
            if (car.carModelList.isEmpty)
              const Text(
                'No models found',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...car.carModelList.map((modelAndVersion) {
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
          ],
        ),
      ),
    );
  }
}

