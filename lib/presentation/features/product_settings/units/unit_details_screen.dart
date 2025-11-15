import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../provider/units_provider.dart';
import '../../../../models/master_data_api.dart';
import 'edit_unit_screen.dart';

/// Unit Details Screen
/// Displays unit information with edit button
/// Converted from KMP's UnitsDetails.kt
class UnitDetailsScreen extends StatefulWidget {
  final Units unit;

  const UnitDetailsScreen({
    super.key,
    required this.unit,
  });

  @override
  State<UnitDetailsScreen> createState() => _UnitDetailsScreenState();
}

class _UnitDetailsScreenState extends State<UnitDetailsScreen> {
  String _baseUnitSt = '';

  @override
  void initState() {
    super.initState();
    _loadBaseUnit();
  }

  Future<void> _loadBaseUnit() async {
    if (widget.unit.type == 1 && widget.unit.baseId != -1) {
      final provider = Provider.of<UnitsProvider>(context, listen: false);
      final baseUnit = await provider.getUnitByUnitId(widget.unit.baseId);
      if (baseUnit == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Base Unit not found')),
          );
        }
      } else {
        setState(() {
          _baseUnitSt = baseUnit.name;
        });
      }
    }
  }

  void _handleEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditUnitScreen(unit: widget.unit),
      ),
    ).then((_) {
      // Refresh details if needed
      if (mounted) {
        _loadBaseUnit();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unitTypeSt = widget.unit.type == 0 ? 'Base Unit' : 'Derived Unit';
    final baseQtySt = widget.unit.baseQty.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unit Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type
            _buildDetailField('Type', unitTypeSt),
            // Base Unit (only for Derived Unit)
            if (widget.unit.type == 1) ...[
              const SizedBox(height: 6),
              _buildDetailField('Base Unit', _baseUnitSt),
            ],
            // Code
            const SizedBox(height: 6),
            _buildDetailField('Code', widget.unit.code),
            // Name
            const SizedBox(height: 6),
            _buildDetailField('Name', widget.unit.name),
            // Display Name
            const SizedBox(height: 6),
            _buildDetailField('Display Name', widget.unit.displayName),
            // Base Qty (only for Derived Unit)
            if (widget.unit.type == 1) ...[
              const SizedBox(height: 6),
              _buildDetailField('Base Qty', baseQtySt),
            ],
            // Edit Button
            const SizedBox(height: 16),
            SizedBox(
              width: 120,
              child: ElevatedButton(
                onPressed: _handleEdit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
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
            value,
            style: const TextStyle(color: Colors.black),
          ),
        ),
      ],
    );
  }
}

