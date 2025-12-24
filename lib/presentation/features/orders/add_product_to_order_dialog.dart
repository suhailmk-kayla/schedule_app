import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/products_provider.dart';
import '../../../models/product_api.dart';
import '../../../models/order_api.dart';
import '../../../models/master_data_api.dart';

/// Add Product To Order Dialog
/// Bottom sheet dialog for adding/editing products in order
/// Converted from KMP's AddProductToOrderDialog
class AddProductToOrderDialog extends StatefulWidget {
  final Product product;
  final String orderId;
  final OrderSub? orderSub; // If provided, editing existing order sub
  final Function(double rate, double quantity, String narration, int unitId) onSave;

  const AddProductToOrderDialog({
    super.key,
    required this.product,
    required this.orderId,
    this.orderSub,
    required this.onSave,
  });

  @override
  State<AddProductToOrderDialog> createState() => _AddProductToOrderDialogState();
}

class _AddProductToOrderDialogState extends State<AddProductToOrderDialog> {
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _narrationController = TextEditingController();
  
  int _selectedUnitId = -1;
  String _selectedUnitName = '';
  List<Units> _unitList = [];

  @override
  void initState() {
    super.initState();
    // Initialize with orderSub values if editing, otherwise defaults
    if (widget.orderSub != null) {
      _quantityController.text = widget.orderSub!.orderSubQty.toString();
      _rateController.text = widget.orderSub!.orderSubUpdateRate.toString();
      _narrationController.text = widget.orderSub!.orderSubNarration ?? '';
      _selectedUnitId = widget.orderSub!.orderSubUnitId;
    } else {
      _quantityController.text = '1.0';
      _rateController.text = widget.product.price.toString();
    }
    
    // Load units for the product
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final productsProvider = Provider.of<ProductsProvider>(context, listen: false);
    // Load base unit first
    await productsProvider.loadBaseUnits();
    // If product has baseUnitId, load derived units
    if (widget.product.base_unit_id != -1) {
      await productsProvider.loadDerivedUnits(widget.product.base_unit_id);
    }
    // Get units from provider
    final units = productsProvider.unitList;
    // Set default unit if not set (matches KMP's ProductListScreen.kt line 1088-1090)
    if (_selectedUnitId == -1 && units.isNotEmpty) {
      // Try to find default unit, base unit, or use first available
      Units defaultUnit;
      
      // Try default_unit_id first (if valid)
      if (widget.product.default_unit_id != -1) {
        final found = units.where((u) => u.id == widget.product.default_unit_id).firstOrNull;
        if (found != null) {
          defaultUnit = found;
        } else if (widget.product.base_unit_id != -1) {
          // If not found, try base_unit_id (if valid)
          final baseFound = units.where((u) => u.id == widget.product.base_unit_id).firstOrNull;
          defaultUnit = baseFound ?? units.first;
        } else {
          // Use first unit in list (matches KMP line 1089)
          defaultUnit = units.first;
        }
      } else if (widget.product.base_unit_id != -1) {
        // Try base_unit_id if default_unit_id is not set
        final baseFound = units.where((u) => u.id == widget.product.base_unit_id).firstOrNull;
        defaultUnit = baseFound ?? units.first;
      } else {
        // Use first unit in list
        defaultUnit = units.first;
      }
      
      _selectedUnitId = defaultUnit.id;
      _selectedUnitName = defaultUnit.displayName.isNotEmpty 
          ? defaultUnit.displayName 
          : defaultUnit.name;
    }

    setState(() {
      _unitList = units;
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _rateController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  void _showUnitSelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _UnitSelectionBottomSheet(
        units: _unitList,
        selectedUnitId: _selectedUnitId,
        onUnitSelected: (unit) {
          setState(() {
            _selectedUnitId = unit.unitId;
            _selectedUnitName = unit.displayName.isNotEmpty ? unit.displayName : unit.name;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _handleSave() {
    final quantity = double.tryParse(_quantityController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final narration = _narrationController.text;

    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }

    if (rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid rate')),
      );
      return;
    }

    if (_selectedUnitId == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a unit')),
      );
      return;
    }

    widget.onSave(rate, quantity, narration, _selectedUnitId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Add Product',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: widget.product.photo.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                widget.product.photo,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image),
                              ),
                            )
                          : const Icon(Icons.image, size: 50),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Product Name
                  Center(
                    child: Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Product Details
                  if (widget.product.code.isNotEmpty)
                    _DetailRow(label: 'Code', value: widget.product.code),
                  if (widget.product.brand.isNotEmpty)
                    _DetailRow(label: 'Brand', value: widget.product.brand),
                  if (widget.product.sub_brand.isNotEmpty)
                    _DetailRow(label: 'Sub Brand', value: widget.product.sub_brand),
                  _DetailRow(label: 'Price', value: widget.product.price.toStringAsFixed(2)),
                  if (widget.product.mrp > 0)
                    _DetailRow(label: 'MRP', value: widget.product.mrp.toStringAsFixed(2)),
                  const SizedBox(height: 16),

                  // Quantity Field
                  TextField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),

                  // Rate Field
                  TextField(
                    controller: _rateController,
                    decoration: const InputDecoration(
                      labelText: 'Rate',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),

                  // Unit Selection
                  InkWell(
                    onTap: _showUnitSelection,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                      child: Text(
                        _selectedUnitName.isEmpty ? 'Select Unit' : _selectedUnitName,
                        style: TextStyle(
                          color: _selectedUnitName.isEmpty ? Colors.grey : Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Narration Field
                  TextField(
                    controller: _narrationController,
                    decoration: const InputDecoration(
                      labelText: 'Narration (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Add to Order'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _UnitSelectionBottomSheet extends StatelessWidget {
  final List<Units> units;
  final int selectedUnitId;
  final Function(Units) onUnitSelected;

  const _UnitSelectionBottomSheet({
    required this.units,
    required this.selectedUnitId,
    required this.onUnitSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select Unit',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: units.length,
              itemBuilder: (context, index) {
                final unit = units[index];
                final isSelected = unit.unitId == selectedUnitId;
                return ListTile(
                  title: Text(unit.displayName.isNotEmpty ? unit.displayName : unit.name),
                  subtitle: unit.name != unit.displayName ? Text(unit.name) : null,
                  selected: isSelected,
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () => onUnitSelected(unit),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

