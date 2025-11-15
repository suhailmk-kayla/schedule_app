import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../provider/units_provider.dart';
import '../../../../models/master_data_api.dart';

/// Edit Unit Screen
/// Form to edit an existing unit
/// Converted from KMP's EditUnitScreen.kt
class EditUnitScreen extends StatefulWidget {
  final Units unit;

  const EditUnitScreen({
    super.key,
    required this.unit,
  });

  @override
  State<EditUnitScreen> createState() => _EditUnitScreenState();
}

class _EditUnitScreenState extends State<EditUnitScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();

  bool _showDiscardAlert = false;
  bool _showConfirmDialog = false;
  bool _showErrorAlert = false;
  String _errorMessage = '';
  String _baseUnitSt = '';

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.unit.name;
    _displayNameController.text = widget.unit.displayName;
    _loadBaseUnit();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    super.dispose();
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

  Future<bool> _onWillPop() async {
    if (_nameController.text != widget.unit.name ||
        _displayNameController.text != widget.unit.displayName) {
      setState(() {
        _showDiscardAlert = true;
      });
      return false;
    }
    return true;
  }

  Future<void> _handleUpdate() async {
    if (_nameController.text.isEmpty) {
      _showError('Enter name');
      return;
    }

    if (_displayNameController.text.isEmpty) {
      _showError('Enter display name');
      return;
    }

    setState(() {
      _showConfirmDialog = true;
    });
  }

  Future<void> _confirmUpdate() async {
    final provider = Provider.of<UnitsProvider>(context, listen: false);
    final success = await provider.updateUnit(
      unit: widget.unit,
      name: _nameController.text.trim(),
      displayName: _displayNameController.text.trim(),
    );

    if (success) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      setState(() {
        _showConfirmDialog = false;
        _errorMessage = provider.errorMessage ?? 'Failed to update unit';
        _showErrorAlert = true;
      });
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _showErrorAlert = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unitTypeSt = widget.unit.type == 0 ? 'Base Unit' : 'Derived Unit';
    final baseQtySt = widget.unit.baseQty.toString();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onWillPop().then((shouldPop) {
            if (shouldPop) {
              Navigator.of(context).pop();
            }
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Unit'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _onWillPop().then((shouldPop) {
              if (shouldPop) {
                Navigator.of(context).pop();
              }
            }),
          ),
        ),
        body: Consumer<UnitsProvider>(
          builder: (context, provider, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unit Type (read-only)
                  _buildReadOnlyField('Unit Type', unitTypeSt),
                  // Base Unit (read-only, only for Derived Unit)
                  if (widget.unit.type == 1) ...[
                    const SizedBox(height: 6),
                    _buildReadOnlyField('Base Unit', _baseUnitSt),
                  ],
                  // Code (read-only)
                  const SizedBox(height: 6),
                  TextField(
                    controller: TextEditingController(text: widget.unit.code),
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                  ),
                  // Name (editable)
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  // Display Name (editable)
                  const SizedBox(height: 6),
                  TextField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  // Base Qty (read-only, only for Derived Unit)
                  if (widget.unit.type == 1) ...[
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: baseQtySt),
                      decoration: const InputDecoration(
                        labelText: 'Base Qty',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                  // Update Button
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: provider.isLoading ? null : _handleUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: provider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Update',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Show dialogs when state changes
    if (_showDiscardAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Changes'),
            content: const Text('Discard changes?'),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _showDiscardAlert = false;
                  });
                  Navigator.pop(context);
                  Navigator.of(context).pop();
                },
                child: const Text('Yes'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showDiscardAlert = false;
                  });
                  Navigator.pop(context);
                },
                child: const Text('No'),
              ),
            ],
          ),
        );
      });
    }
    if (_showConfirmDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm'),
            content: const Text('Do you want to update changes?'),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _showConfirmDialog = false;
                  });
                  Navigator.pop(context);
                  _confirmUpdate();
                },
                child: const Text('Yes'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showConfirmDialog = false;
                  });
                  Navigator.pop(context);
                },
                child: const Text('No'),
              ),
            ],
          ),
        );
      });
    }
    if (_showErrorAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(_errorMessage),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _showErrorAlert = false;
                  });
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }
  }
}

