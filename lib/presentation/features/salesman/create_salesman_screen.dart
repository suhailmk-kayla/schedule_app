import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/toast_helper.dart';

import '../../provider/salesman_provider.dart';
import '../../provider/users_provider.dart';

/// Create/Edit Salesman Screen
/// Converted from KMP's CreateSalesmanScreen.kt and EditUserScreen.kt
class CreateSalesmanScreen extends StatefulWidget {
  final int? userId; // Salesman's user ID (required for edit mode)

  const CreateSalesmanScreen({
    super.key,
    this.userId,
  });

  @override
  State<CreateSalesmanScreen> createState() => _CreateSalesmanScreenState();
}

class _CreateSalesmanScreenState extends State<CreateSalesmanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSaving = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_stripCodeSpaces);
    // If editing, load salesman data
    if (widget.userId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSalesmanData();
      });
    }
  }

  Future<void> _loadSalesmanData() async {
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
    _codeController
      ..removeListener(_stripCodeSpaces)
      ..dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _hasFormChanges =>
      _codeController.text.trim().isNotEmpty ||
      _nameController.text.trim().isNotEmpty ||
      _phoneController.text.trim().isNotEmpty ||
      _addressController.text.trim().isNotEmpty ||
      _passwordController.text.trim().isNotEmpty;

  void _stripCodeSpaces() {
    final cleaned = _codeController.text.replaceAll(' ', '');
    if (_codeController.text != cleaned) {
      final selection = _codeController.selection;
      _codeController.value = TextEditingValue(
        text: cleaned,
        selection: selection.copyWith(
          baseOffset: cleaned.length,
          extentOffset: cleaned.length,
        ),
      );
    }
    setState(() {});
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validation 3: Check if phone number is already taken by another salesman
    final usersProvider = context.read<UsersProvider>();
    final phoneNumber = _phoneController.text.trim();
    
    final phoneExists = widget.userId == null
        ? await usersProvider.checkSalesmanPhoneExists(phoneNumber)
        : await usersProvider.checkSalesmanPhoneExistsWithId(phoneNumber, widget.userId!);
    
    if (phoneExists) {
      if (!mounted) return;
      ToastHelper.showWarning('Phone number already taken by another salesman');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final success = widget.userId == null
        ? await usersProvider.createUser(
            code: _codeController.text.trim(),
            name: _nameController.text.trim(),
            phone: phoneNumber,
            categoryId: 3, // Salesman category
            address: _addressController.text.trim(),
            password: _passwordController.text,
          )
        : await usersProvider.updateUser(
            userId: widget.userId!,
            code: _codeController.text.trim(),
            name: _nameController.text.trim(),
            phone: phoneNumber,
            categoryId: 3, // Salesman category
            address: _addressController.text.trim(),
          );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (success) {
      await context.read<SalesmanProvider>().loadSalesmen();
      Navigator.of(context).pop(true);
      ToastHelper.showSuccess(widget.userId == null ? 'Salesman created successfully' : 'Salesman updated successfully');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(widget.userId == null
      //         ? 'Salesman created successfully'
      //         : 'Salesman updated successfully'),
      //   ),
      // );
    } else {
      final message =
          usersProvider.errorMessage ?? 'Failed to ${widget.userId == null ? 'create' : 'update'} salesman. Please try again.';
          ToastHelper.showError(message);
    }
  }

  Future<bool> _handleWillPop() async {
    if (!_hasFormChanges) {
      return true;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Do you really want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_hasFormChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _handleWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.userId == null ? 'Create Salesman' : 'Edit Salesman'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Code field
                  TextFormField(
                    maxLength: 20,
                    controller: _codeController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'Code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Code cannot be empty';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Name field
                  TextFormField(
                    maxLength: 50,
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name cannot be empty';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Phone field
                  TextFormField(
                    maxLength: 10,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      // Validation 1: Phone number cannot be empty or null
                      if (value == null || value.trim().isEmpty) {
                        return 'Phone number cannot be empty';
                      }
                      
                      // Validation 2: Phone number must be exactly 10 digits
                      if (value.trim().length != 10) {
                        return 'Phone number must be exactly 10 digits';
                      }
                      
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Address field
                  TextFormField(
                    maxLength: 100,
                    controller: _addressController,
                    maxLines: 2,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'Address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    // Address can be empty, no validation needed
                  ),
                  if (widget.userId == null) ...[
                    const SizedBox(height: 12),
                    // Password field (create mode only)
                    TextFormField(
                      maxLength: 50,
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Password cannot be empty';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}

