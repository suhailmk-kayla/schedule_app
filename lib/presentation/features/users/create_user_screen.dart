import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/toast_helper.dart';
import '../../provider/users_provider.dart';
import '../../../models/user_category_model.dart';

/// Create User Screen
/// Form for creating new users with category selection
/// Converted from KMP's CreateUserScreen.kt
class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  int? _selectedCategoryId;
  String _selectedCategoryName = 'Select User Category';
  bool _showDiscardDialog = false;
  bool _showErrorDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UsersProvider>(context, listen: false).getAllUserCategories();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_hasChanges()) {
      setState(() {
        _showDiscardDialog = true;
      });
      return false;
    }
    return true;
  }

  bool _hasChanges() {
    return _codeController.text.isNotEmpty ||
        _nameController.text.isNotEmpty ||
        _phoneController.text.isNotEmpty ||
        _addressController.text.isNotEmpty ||
        _passwordController.text.isNotEmpty ||
        _selectedCategoryId != null;
  }

  void _showCategoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer<UsersProvider>(
          builder: (context, provider, _) {
            final categories = provider.userCategories
                .where((cat) => cat.id != 1) // Exclude Admin (id=1)
                .toList();

            return ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = _selectedCategoryId == category.id;

                return RadioListTile<int>(
                  title: Text(category.name),
                  value: category.id,
                  groupValue: _selectedCategoryId,
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                      _selectedCategoryName = category.name;
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
    // Validation
    if (_codeController.text.trim().isEmpty) {
     ToastHelper.showWarning('Enter code');
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ToastHelper.showWarning('Enter name');
      return;
    }

    if (_selectedCategoryId == null) {
      ToastHelper.showWarning('Select Category');
      return;
    }

    if (_passwordController.text.trim().isEmpty) {
      ToastHelper.showWarning('Enter password');
      return;
    }

    final provider = Provider.of<UsersProvider>(context, listen: false);
    final success = await provider.createUser(
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      categoryId: _selectedCategoryId!,
      address: _addressController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (success && mounted) {
      Navigator.of(context).pop();
    } else if (mounted) {
      setState(() {
        _showErrorDialog = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onWillPop().then((shouldPop) {
            if (shouldPop && mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create User'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _onWillPop().then((shouldPop) {
              if (shouldPop && mounted) {
                Navigator.of(context).pop();
              }
            }),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // Code field
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      // Remove spaces
                      if (value.contains(' ')) {
                        _codeController.value = TextEditingValue(
                          text: value.replaceAll(' ', ''),
                          selection: TextSelection.collapsed(
                            offset: value.replaceAll(' ', '').length,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Name field
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Phone field
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  // Category selection
                  const Text(
                    'Category',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _showCategoryBottomSheet,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedCategoryName,
                            style: const TextStyle(color: Colors.black),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  // Address field (only for SalesMan or Supplier)
                  if (_selectedCategoryId == 3 || _selectedCategoryId == 4) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Password field
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    onChanged: (value) {
                      // Remove spaces
                      if (value.contains(' ')) {
                        _passwordController.value = TextEditingValue(
                          text: value.replaceAll(' ', ''),
                          selection: TextSelection.collapsed(
                            offset: value.replaceAll(' ', '').length,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  // Save button (only shown when all required fields are filled)
                  if (_codeController.text.isNotEmpty &&
                      _nameController.text.isNotEmpty &&
                      _selectedCategoryId != null &&
                      _passwordController.text.isNotEmpty)
                    ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // Discard dialog
            if (_showDiscardDialog)
              Container(
                color: Colors.black54,
                child: Center(
                  child: AlertDialog(
                    title: const Text('Confirm'),
                    content: const Text('discard changes?'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showDiscardDialog = false;
                          });
                        },
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showDiscardDialog = false;
                          });
                          Navigator.of(context).pop();
                        },
                        child: const Text('Yes'),
                      ),
                    ],
                  ),
                ),
              ),
            // Error dialog
            if (_showErrorDialog)
              Consumer<UsersProvider>(
                builder: (context, provider, _) {
                  return Container(
                    color: Colors.black54,
                    child: Center(
                      child: AlertDialog(
                        title: const Text('Error'),
                        content: Text(provider.errorMessage ?? 'Failed to create user'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showErrorDialog = false;
                              });
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

