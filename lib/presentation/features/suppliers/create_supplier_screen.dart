import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/toast_helper.dart';
import '../../provider/users_provider.dart';

/// Create/Edit Supplier Screen
/// Converted from KMP's CreateSupplierScreen.kt and EditUserScreen.kt
class CreateSupplierScreen extends StatefulWidget {
  final int? supplierId; // If provided, this is edit mode
  final int? userId; // Supplier's user ID (required for edit mode)

  const CreateSupplierScreen({
    super.key,
    this.supplierId,
    this.userId,
  });

  @override
  State<CreateSupplierScreen> createState() => _CreateSupplierScreenState();
}

class _CreateSupplierScreenState extends State<CreateSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _showDiscardDialog = false;
  bool _showErrorDialog = false;

  @override
  void initState() {
    super.initState();
    // If editing, load supplier data
    if (widget.userId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSupplierData();
      });
    }
  }

  Future<void> _loadSupplierData() async {
    if (widget.userId == null) return;

    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    await usersProvider.loadUserById(widget.userId!);

    if (usersProvider.currentUser == null) return;

    final user = usersProvider.currentUser!.user;
    setState(() {
      _codeController.text = user.code;
      _nameController.text = user.name;
      _phoneController.text = user.phoneNo;
      _addressController.text = user.address;
      // Password field is not loaded for edit mode
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

  bool get _hasChanges {
    return _codeController.text.isNotEmpty ||
        _nameController.text.isNotEmpty ||
        _phoneController.text.isNotEmpty ||
        _addressController.text.isNotEmpty ||
        _passwordController.text.isNotEmpty;
  }

  Future<void> _handleSave() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim().isEmpty ? '0' : _phoneController.text.trim();
    final address = _addressController.text.trim();
    final password = _passwordController.text.trim();

    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    final success = widget.userId == null
        ? await usersProvider.createUser(
            code: code,
            name: name,
            phone: phone,
            categoryId: 4, // Supplier category (matches KMP)
            address: address,
            password: password,
          )
        : await usersProvider.updateUser(
            userId: widget.userId!,
            code: code,
            name: name,
            phone: phone,
            categoryId: 4, // Supplier category
            address: address,
          );

    if (!mounted) return;

    if (success) {
      ToastHelper.showSuccess('Supplier created successfully');
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
          title: Text(widget.userId == null ? 'Create Supplier' : 'Edit Supplier'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handlePop,
          ),
        ),
        body: Stack(
          children: [
            Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      maxLength: 20,
                      controller: _codeController,
                      decoration: const InputDecoration(
                        counterText: '',
                        labelText: 'Code',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.none,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter code';
                        }
                        return null;
                      },
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
                    TextFormField(
                      maxLength: 50,
                      controller: _nameController,
                      decoration: const InputDecoration(
                        counterText: '',
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      maxLength: 10,
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        counterText: '',
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          if (value.trim().length < 10) {
                            return 'Phone number must be 10 digits';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      maxLength: 100,
                      controller: _addressController,
                      decoration: const InputDecoration(
                        counterText: '',
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 1,
                    ),
                    if (widget.userId == null) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        maxLength: 50,
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter password';
                          }
                          return null;
                        },
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
                    ],
                  const SizedBox(height: 24),
                  // if (_codeController.text.isNotEmpty &&
                  //     _nameController.text.isNotEmpty &&
                  //     _passwordController.text.isNotEmpty)
                    ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
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

