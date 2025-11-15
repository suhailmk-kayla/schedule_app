import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../provider/units_provider.dart';
import '../../../../models/master_data_api.dart';

/// Create Unit Screen
/// Form to create a new unit
/// Converted from KMP's CreateUnitScreen.kt
class CreateUnitScreen extends StatefulWidget {
  const CreateUnitScreen({super.key});

  @override
  State<CreateUnitScreen> createState() => _CreateUnitScreenState();
}

class _CreateUnitScreenState extends State<CreateUnitScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _baseQtyController = TextEditingController(text: '1.0');
  final TextEditingController _commentController = TextEditingController();

  int _unitType = -1; // -1 = not selected, 0 = Base Unit, 1 = Derived Unit
  String _unitTypeSt = 'Select unit Type';
  int _baseUnitIndex = -1;
  String _baseUnitSt = 'Select base unit';
  int _baseUnitId = -1;
  bool _showDiscardAlert = false;
  bool _showErrorAlert = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
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

  Future<bool> _onWillPop() async {
    if (_codeController.text.isNotEmpty ||
        _nameController.text.isNotEmpty ||
        _displayNameController.text.isNotEmpty) {
      setState(() {
        _showDiscardAlert = true;
      });
      return false;
    }
    return true;
  }

  void _showUnitTypeBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer<UnitsProvider>(
          builder: (context, provider, _) {
            final unitTypeList = ['Base Unit', 'Derived Unit'];
            return ListView.builder(
              itemCount: unitTypeList.length,
              itemBuilder: (context, index) {
                final isSelected = _unitType == index;
                return RadioListTile<int>(
                  title: Text(unitTypeList[index]),
                  value: index,
                  groupValue: _unitType,
                  onChanged: (value) {
                    setState(() {
                      _unitType = value!;
                      _unitTypeSt = unitTypeList[value];
                      if (value == 0) {
                        // Base unit selected, reset derived unit fields
                        _baseUnitIndex = -1;
                        _baseUnitSt = 'Select base unit';
                        _baseUnitId = -1;
                      }
                    });
                    Navigator.pop(context);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showBaseUnitBottomSheet() {
    final provider = Provider.of<UnitsProvider>(context, listen: false);
    if (provider.baseUnitsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No base units found')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer<UnitsProvider>(
          builder: (context, provider, _) {
            return ListView.builder(
              itemCount: provider.baseUnitsList.length,
              itemBuilder: (context, index) {
                final baseUnit = provider.baseUnitsList[index];
                final isSelected = _baseUnitIndex == index;
                return RadioListTile<int>(
                  title: Text(baseUnit.name),
                  value: index,
                  groupValue: _baseUnitIndex,
                  onChanged: (value) {
                    setState(() {
                      _baseUnitIndex = value!;
                      _baseUnitSt = baseUnit.name;
                      _baseUnitId = baseUnit.id;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _handleSave() async {
    if (_unitType == -1) {
      _showError('Select unit type');
      return;
    }

    if (_unitType == 1 && _baseUnitId == -1) {
      _showError('Choose a base unit');
      return;
    }

    if (_codeController.text.isEmpty) {
      _showError('Enter code');
      return;
    }

    if (_nameController.text.isEmpty) {
      _showError('Enter name');
      return;
    }

    if (_displayNameController.text.isEmpty) {
      _showError('Enter display name');
      return;
    }

    double baseQty = 1.0;
    if (_unitType == 1) {
      if (_baseQtyController.text.isEmpty ||
          (double.tryParse(_baseQtyController.text) ?? 0.0) <= 0) {
        _showError('Enter base quantity');
        return;
      }
      baseQty = double.tryParse(_baseQtyController.text) ?? 0.0;
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

    if (success) {
      _showError('Unit Saved Successfully');
      // Reset form
      setState(() {
        _unitType = -1;
        _unitTypeSt = 'Select unit Type';
        _baseUnitIndex = -1;
        _baseUnitSt = 'Select base unit';
        _baseUnitId = -1;
        _codeController.clear();
        _nameController.clear();
        _displayNameController.clear();
        _baseQtyController.text = '1.0';
        _commentController.clear();
      });
    } else {
      _showError(provider.errorMessage ?? 'Failed to save unit');
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
          title: const Text('Create Unit'),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Unit Type Selection
                  _buildSelectableField(
                    label: 'Unit Type',
                    value: _unitTypeSt,
                    onTap: _showUnitTypeBottomSheet,
                  ),
                  // Base Unit Selection (only for Derived Unit)
                  if (_unitType == 1) ...[
                    const SizedBox(height: 6),
                    _buildSelectableField(
                      label: 'Base Unit',
                      value: _baseUnitSt,
                      onTap: _showBaseUnitBottomSheet,
                    ),
                  ],
                  // Code Field
                  const SizedBox(height: 6),
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  // Name Field
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  // Display Name Field
                  const SizedBox(height: 6),
                  TextField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  // Base Qty Field (only for Derived Unit)
                  if (_unitType == 1) ...[
                    const SizedBox(height: 6),
                    TextField(
                      controller: _baseQtyController,
                      decoration: const InputDecoration(
                        labelText: 'Base Qty',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (input) {
                        // Validate numeric input
                        if (input.isNotEmpty &&
                            !RegExp(r'^\d*\.?\d*$').hasMatch(input)) {
                          _baseQtyController.text = input.substring(0, input.length - 1);
                          _baseQtyController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _baseQtyController.text.length),
                          );
                        }
                      },
                    ),
                  ],
                  // Save Button
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
                          : const Text(
                              'Save',
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
    if (_showErrorAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Message'),
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

  Widget _buildSelectableField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          child: Container(
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
        ),
      ],
    );
  }
}

