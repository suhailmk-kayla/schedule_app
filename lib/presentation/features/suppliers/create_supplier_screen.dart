import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/toast_helper.dart';
import '../../provider/users_provider.dart';

/// Create Supplier Screen
/// Converted from KMP's CreateSupplierScreen.kt
class CreateSupplierScreen extends StatefulWidget {
  const CreateSupplierScreen({super.key});

  @override
  State<CreateSupplierScreen> createState() => _CreateSupplierScreenState();
}

class _CreateSupplierScreenState extends State<CreateSupplierScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _showDiscardDialog = false;
  bool _showErrorDialog = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    return _codeController.text.isNotEmpty ||
        _nameController.text.isNotEmpty ||
        _phoneController.text.isNotEmpty ||
        _addressController.text.isNotEmpty ||
        _passwordController.text.isNotEmpty;
  }

  Future<void> _handleSave() async {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim().isEmpty ? '0' : _phoneController.text.trim();
    final address = _addressController.text.trim();
    final password = _passwordController.text.trim();

    if (code.isEmpty) {
      ToastHelper.showWarning('Enter code');
      return;
    }
    if (name.isEmpty) {
      ToastHelper.showWarning('Enter name');
      return;
    }
    if (password.isEmpty) {
      ToastHelper.showWarning('Enter password');
      return;
    }

    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    final success = await usersProvider.createUser(
      code: code,
      name: name,
      phone: phone,
      categoryId: 4, // Supplier category (matches KMP)
      address: address,
      password: password,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _showErrorDialog = true;
      });
    }
  }

  void _handlePop() {
    if (_hasChanges) {
      setState(() {
        _showDiscardDialog = true;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handlePop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Supplier'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handlePop,
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      if (value.contains(' ')) {
                        final sanitized = value.replaceAll(' ', '');
                        _codeController.value = TextEditingValue(
                          text: sanitized,
                          selection: TextSelection.collapsed(offset: sanitized.length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    onChanged: (value) {
                      if (value.contains(' ')) {
                        final sanitized = value.replaceAll(' ', '');
                        _passwordController.value = TextEditingValue(
                          text: sanitized,
                          selection: TextSelection.collapsed(offset: sanitized.length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  // if (_codeController.text.isNotEmpty &&
                  //     _nameController.text.isNotEmpty &&
                  //     _passwordController.text.isNotEmpty)
                    ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
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
            Consumer<UsersProvider>(
              builder: (context, provider, _) {
                if (!provider.isLoading) return const SizedBox.shrink();
                return Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
            ),
            if (_showDiscardDialog)
              Container(
                color: Colors.black54,
                child: Center(
                  child: AlertDialog(
                    title: const Text('Confirm'),
                    content: const Text('Discard changes?'),
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
            if (_showErrorDialog)
              Consumer<UsersProvider>(
                builder: (context, provider, _) {
                  return Container(
                    color: Colors.black54,
                    child: Center(
                      child: AlertDialog(
                        title: const Text('Error'),
                        content: Text(provider.errorMessage ?? 'Failed to create supplier'),
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

