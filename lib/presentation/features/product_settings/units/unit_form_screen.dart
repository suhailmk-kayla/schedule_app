import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../provider/units_provider.dart';
import '../../../../models/master_data_api.dart';
import '../../../../utils/toast_helper.dart';

/// Unit Form Screen
/// Unified screen for creating and editing units
/// Handles both create and edit modes conditionally
/// Converted from KMP's CreateUnitScreen.kt and EditUnitScreen.kt
class UnitFormScreen extends StatefulWidget {
  final Units? unit; // null = create mode, not null = edit mode

  const UnitFormScreen({
    super.key,
    this.unit,
  });

  @override
  State<UnitFormScreen> createState() => _UnitFormScreenState();
}

class _UnitFormScreenState extends State<UnitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _baseQtyController = TextEditingController(text: '1.0');
  final TextEditingController _commentController = TextEditingController();

  int _unitType = -1; // -1 = not selected, 0 = Base Unit, 1 = Derived Unit
  int _baseUnitId = -1;
  String _baseUnitSt = '';
  bool _showDiscardAlert = false;
  bool _showErrorAlert = false;
  String _errorMessage = '';

  bool get _isEditMode => widget.unit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      // Edit mode: populate from existing unit
      final unit = widget.unit!;
      _codeController.text = unit.code;
      _nameController.text = unit.name;
      _displayNameController.text = unit.displayName;
      _baseQtyController.text = unit.baseQty.toString();
      _commentController.text = unit.comment;
      _unitType = unit.type;
      _baseUnitId = unit.baseId;
      _loadBaseUnit();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<UnitsProvider>(context, listen: false);
      provider.getAllBaseUnits();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _displayNameController.dispose();
    _baseQtyController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadBaseUnit() async {
    if (_isEditMode && widget.unit!.type == 1 && widget.unit!.baseId != -1) {
      final provider = Provider.of<UnitsProvider>(context, listen: false);
      final baseUnit = await provider.getUnitByUnitId(widget.unit!.baseId);
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


  Future<void> _handleSave() async {
     

    if (_isEditMode) {
      // Edit mode: validate and update
      if (_nameController.text.trim().isEmpty) {
        _showError('Enter name');
        return;
      }
      if (_displayNameController.text.trim().isEmpty) {
        _showError('Enter display name');
        return;
      }

      // Check if anything changed
      final nameChanged = _nameController.text.trim() != widget.unit!.name.trim();
      final displayNameChanged =
          _displayNameController.text.trim() != widget.unit!.displayName.trim();

      if (!nameChanged && !displayNameChanged) {
        // No changes, just go back
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      // Show confirm dialog directly
      final shouldUpdate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm'),
          content: const Text('Do you want to update changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );

      if (shouldUpdate == true && mounted) {
        await _confirmUpdate();
      }
    } else {
      // Create mode: validate all fields
      if (!_formKey.currentState!.validate()) {
        return;
      }

      double baseQty = 1.0;
      if (_unitType == 1) {
        baseQty = double.tryParse(_baseQtyController.text) ?? 1.0;
      }

      final provider = Provider.of<UnitsProvider>(context, listen: false);
      final success = await provider.createUnit(
        type: _unitType,
        baseUnitId: _baseUnitId,
        code: _codeController.text.trim(),
        name: _nameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        baseQty: baseQty,
        comment: _commentController.text.trim(),
      );

      if (success && mounted) {
        ToastHelper.showSuccess('Unit saved successfully');
        Navigator.of(context).pop();
      } else if (mounted) {
        ToastHelper.showError(provider.errorMessage ?? 'Failed to save unit');
         
      }
    }
  }

  Future<void> _confirmUpdate() async {
    final provider = Provider.of<UnitsProvider>(context, listen: false);

    // Only send changed fields
    String? name;
    String? displayName;

    final trimmedName = _nameController.text.trim();
    final trimmedDisplayName = _displayNameController.text.trim();

    if (trimmedName != widget.unit!.name.trim()) {
      name = trimmedName;
    }
    if (trimmedDisplayName != widget.unit!.displayName.trim()) {
      displayName = trimmedDisplayName;
    }

    final success = await provider.updateUnit(
      unit: widget.unit!,
      name: name,
      displayName: displayName,
    );

    if (success) {
      if (mounted) {
        ToastHelper.showSuccess('Unit updated successfully');
        // Pop back to list screen - the list will auto-refresh via Consumer
        Navigator.of(context).pop();
      }
    } else {
      if (mounted) {
        _errorMessage = provider.errorMessage ?? 'Failed to update unit';
        _showErrorAlert = true;
        setState(() {});
      }
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
    final unitTypeSt = _isEditMode
        ? (widget.unit!.type == 0 ? 'Base Unit' : 'Derived Unit')
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Unit' : 'Create Unit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: (){
            Navigator.of(context).pop();
          }
        ),
      ),
      body: Consumer<UnitsProvider>(
        builder: (context, provider, _) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unit Type (read-only in edit mode, editable in create mode)
                  if (_isEditMode) ...[
                    _buildReadOnlyField('Unit Type', unitTypeSt),
                  ] else ...[
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _unitType == -1 ? null : _unitType,
                      decoration: const InputDecoration(
                        labelText: 'Unit Type',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Select unit type'),
                      items: const [
                        DropdownMenuItem<int>(
                          value: 0,
                          child: Text('Base Unit'),
                        ),
                        DropdownMenuItem<int>(
                          value: 1,
                          child: Text('Derived Unit'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _unitType = value ?? -1;
                          if (value == 0) {
                            // Base unit selected, reset derived unit fields
                            _baseUnitId = -1;
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null || value == -1) {
                          return 'Unit type cannot be empty';
                        }
                        return null;
                      },
                    ),
                  ],
                  // Base Unit (read-only in edit mode, editable in create mode)
                  if (_isEditMode && widget.unit!.type == 1) ...[
                    const SizedBox(height: 6),
                    _buildReadOnlyField('Base Unit', _baseUnitSt),
                  ] else if (!_isEditMode && _unitType == 1) ...[
                    const SizedBox(height: 6),
                    Consumer<UnitsProvider>(
                      builder: (context, provider, _) {
                        return DropdownButtonFormField<int>(
                          value: _baseUnitId == -1 ? null : _baseUnitId,
                          decoration: const InputDecoration(
                            labelText: 'Base Unit',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('Select base unit'),
                          items: provider.baseUnitsList.map((baseUnit) {
                            return DropdownMenuItem<int>(
                              value: baseUnit.unitId, // Use server ID
                              child: Text(baseUnit.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _baseUnitId = value;
                              });
                            }
                          },
                          validator: (value) {
                            if (_unitType == 1 && (value == null || value == -1)) {
                              return 'Base unit cannot be empty';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                  ],
                  // Code Field (read-only in edit mode, editable in create mode)
                  const SizedBox(height: 6),
                  if (_isEditMode)
                    TextField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Code',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    )
                  else
                    TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Code',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Code cannot be empty';
                        }
                        return null;
                      },
                    ),
                  // Name Field (editable in both modes)
                  const SizedBox(height: 6),
                  if (_isEditMode)
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    )
                  else
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name cannot be empty';
                        }
                        return null;
                      },
                    ),
                  // Display Name Field (editable in both modes)
                  const SizedBox(height: 6),
                  if (_isEditMode)
                    TextField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        border: OutlineInputBorder(),
                      ),
                    )
                  else
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Display name cannot be empty';
                        }
                        return null;
                      },
                    ),
                  // Base Qty Field (read-only in edit mode, editable in create mode)
                  if (_isEditMode && widget.unit!.type == 1) ...[
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(
                        text: widget.unit!.baseQty.toString(),
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Base Qty',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ] else if (!_isEditMode && _unitType == 1) ...[
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _baseQtyController,
                      decoration: const InputDecoration(
                        labelText: 'Base Qty',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                      ],
                      validator: (value) {
                        if (_unitType == 1) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Base quantity cannot be empty';
                          }
                          final qty = double.tryParse(value);
                          if (qty == null || qty <= 0) {
                            return 'Base quantity must be greater than 0';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                  // Save/Update Button
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: provider.isLoading ? null : _handleSave,
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
                          : Text(
                              _isEditMode ? 'Update' : 'Save',
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
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
    // Confirm dialog is now shown directly in _handleSave, so this is no longer needed
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

