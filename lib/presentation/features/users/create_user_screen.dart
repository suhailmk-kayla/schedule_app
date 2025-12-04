import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/toast_helper.dart';
import '../../provider/users_provider.dart';

/// Create/Edit User Screen
/// Form for creating new users or editing existing ones
/// Converted from KMP's CreateUserScreen.kt and EditUserScreen.kt
class CreateUserScreen extends StatefulWidget {
  final int? userId; // If provided, this is edit mode

  const CreateUserScreen({
    super.key,
    this.userId,
  });

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
  bool _isLoadingUser = false;

  // Store initial values for change detection (edit mode)
  String _initCode = '';
  String _initName = '';
  String _initPhone = '';
  String _initAddress = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<UsersProvider>(context, listen: false);
      await provider.getAllUserCategories();
      
      if (widget.userId != null) {
        // Edit mode: Load existing user data
        await _loadUserData(widget.userId!);
      }
    });
  }

  Future<void> _loadUserData(int userId) async {
    setState(() {
      _isLoadingUser = true;
    });

    final provider = Provider.of<UsersProvider>(context, listen: false);
    await provider.loadUserById(userId);

    if (!mounted) return;

    final userWithCategory = provider.currentUser;
    if (userWithCategory == null) {
      ToastHelper.showError('User not found');
      Navigator.pop(context);
      return;
    }

    final user = userWithCategory.user;
    
    // Store initial values for change detection
    _initCode = user.code;
    _initName = user.name;
    _initPhone = user.phoneNo;
    _initAddress = user.address;

    // Populate form fields
    _codeController.text = user.code;
    _nameController.text = user.name;
    _phoneController.text = user.phoneNo;
    _addressController.text = user.address;
    _selectedCategoryId = user.catId;
    _selectedCategoryName = userWithCategory.categoryName;

    setState(() {
      _isLoadingUser = false;
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
    if (widget.userId != null) {
      // Edit mode: Compare with initial values
      return _codeController.text != _initCode ||
          _nameController.text != _initName ||
          _phoneController.text != _initPhone ||
          _addressController.text != _initAddress;
    } else {
      // Create mode: Check if any field has value
      return _codeController.text.isNotEmpty ||
          _nameController.text.isNotEmpty ||
          _phoneController.text.isNotEmpty ||
          _addressController.text.isNotEmpty ||
          _passwordController.text.isNotEmpty ||
          _selectedCategoryId != null;
    }
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

    final provider = Provider.of<UsersProvider>(context, listen: false);

    if (widget.userId != null) {
      // Edit mode: Update user
      // Check code duplicate (excluding current user)
      final codeExists = await provider.checkCodeExistsWithId(
        _codeController.text.trim(),
        widget.userId!,
      );
      if (codeExists) {
        ToastHelper.showError('Code already Exist');
        return;
      }

      final success = await provider.updateUser(
        userId: widget.userId!,
        code: _codeController.text.trim(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? '0'
            : _phoneController.text.trim(),
        categoryId: _selectedCategoryId!,
        address: _addressController.text.trim(),
      );

      if (success && mounted) {
        ToastHelper.showSuccess('User updated successfully');
        Navigator.of(context).pop();
      } else if (mounted) {
        setState(() {
          _showErrorDialog = true;
        });
      }
    } else {
      // Create mode: Create new user
      if (_passwordController.text.trim().isEmpty) {
        ToastHelper.showWarning('Enter password');
        return;
      }

      final success = await provider.createUser(
        code: _codeController.text.trim(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        categoryId: _selectedCategoryId!,
        address: _addressController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (success && mounted) {
        ToastHelper.showSuccess('User created successfully');
        Navigator.of(context).pop();
      } else if (mounted) {
        setState(() {
          _showErrorDialog = true;
        });
      }
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
          title: Text(widget.userId == null ? 'Create User' : 'Edit User'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _onWillPop().then((shouldPop) {
              if (shouldPop && mounted) {
                Navigator.of(context).pop();
              }
            }),
          ),
        ),
        body: _isLoadingUser
            ? const Center(child: CircularProgressIndicator())
            : Stack(
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
                  // Category selection (read-only in edit mode)
                  const Text(
                    'Category',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: widget.userId == null ? _showCategoryBottomSheet : null,
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
                          if (widget.userId == null)
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
                  // Password field (only in create mode)
                  if (widget.userId == null) ...[
                    const SizedBox(height: 16),
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
                  ],
                  const SizedBox(height: 24),
                  // Save button
                  Consumer<UsersProvider>(
                    builder: (context, provider, _) {
                      final bool showButton;
                      if (widget.userId != null) {
                        // Edit mode: Show button if there are changes
                        showButton = _hasChanges() &&
                            _codeController.text.isNotEmpty &&
                            _nameController.text.isNotEmpty &&
                            _selectedCategoryId != null;
                      } else {
                        // Create mode: Show button when all required fields are filled
                        showButton = _codeController.text.isNotEmpty &&
                            _nameController.text.isNotEmpty &&
                            _selectedCategoryId != null &&
                            _passwordController.text.isNotEmpty;
                      }

                      return showButton
                          ? ElevatedButton(
                              onPressed: provider.isLoading ? null : _handleSave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
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
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(widget.userId == null ? 'Save' : 'Update'),
                            )
                          : const SizedBox.shrink();
                    },
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

