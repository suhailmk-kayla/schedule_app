import 'package:flutter/material.dart';

/// Create Car Screen
/// Form for creating new cars with brand, name, models, and versions
/// Converted from KMP's CreateCarScreen.kt
/// TODO: Implement full create car functionality
class CreateCarScreen extends StatelessWidget {
  const CreateCarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Car'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const Center(
        child: Text('Create Car Screen - Coming Soon'),
      ),
    );
  }
}

