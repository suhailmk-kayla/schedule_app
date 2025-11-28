import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/users_provider.dart';
import '../../provider/salesman_provider.dart';
import '../../../utils/storage_helper.dart';
import 'create_salesman_screen.dart';

/// Salesman Details Screen
/// Shows salesman information with edit, delete, and change password buttons (admin only)
/// Converted from KMP's UserDetails.kt (salesmen use UserDetails screen)
class SalesmanDetailsScreen extends StatefulWidget {
  final int userId; // Salesman's user ID

  const SalesmanDetailsScreen({
    super.key,
    required this.userId,
  });

  @override
  State<SalesmanDetailsScreen> createState() => _SalesmanDetailsScreenState();
}

class _SalesmanDetailsScreenState extends State<SalesmanDetailsScreen> {
  bool _showChangePasswordDialog = false;
  bool _showConfirmDialog = false;
  String _confirmMessage = '';
  int _confirmDialogType = 0; // 0-change password, 1-delete salesman, 2-logout devices
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _passwordError = false;

  int _userType = 0;
  bool _isUserActive = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usersProvider = Provider.of<UsersProvider>(context, listen: false);
      usersProvider.loadUserById(widget.userId);
      usersProvider.checkUserActive(widget.userId);
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userType = await StorageHelper.getUserType();
    setState(() {
      _userType = userType;
    });
  }

  void _handleEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateSalesmanScreen(
          userId: widget.userId,
        ),
      ),
    ).then((result) {
      // Reload salesman details if salesman was updated
      if (result == true && mounted) {
        final usersProvider = Provider.of<UsersProvider>(context, listen: false);
        usersProvider.loadUserById(widget.userId);
        final salesmanProvider = Provider.of<SalesmanProvider>(context, listen: false);
        salesmanProvider.loadSalesmen();
      }
    });
  }

  void _handleDelete() {
    setState(() {
      _confirmMessage =
          'This will delete the salesman permanently. And also logout from the login devices?\n\nDo you want to continue?';
      _confirmDialogType = 1;
      _showConfirmDialog = true;
    });
  }

  void _handleLogoutDevice() {
    if (!_isUserActive) return;
    setState(() {
      _confirmMessage = 'Do you want to logout this salesman from all devices?';
      _confirmDialogType = 2;
      _showConfirmDialog = true;
    });
  }

  void _handleChangePassword() {
    setState(() {
      _showChangePasswordDialog = true;
    });
  }

  Future<void> _handleConfirm() async {
    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    bool success = false;

    switch (_confirmDialogType) {
      case 0: // Change password
        success = await usersProvider.changeUserPassword(
          userId: widget.userId,
          password: _passwordController.text.trim(),
          confirmPassword: _confirmPasswordController.text.trim(),
        );
        if (success) {
          _passwordController.clear();
          _confirmPasswordController.clear();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password changed successfully')),
            );
          }
        }
        break;

      case 1: // Delete salesman
        final currentUser = usersProvider.currentUser;
        if (currentUser != null) {
          success = await usersProvider.deleteUser(
            userId: widget.userId,
            categoryId: 3, // Salesman category ID
          );
          if (success && mounted) {
            Navigator.of(context).pop();
          }
        }
        break;

      case 2: // Logout devices
        success = await usersProvider.logoutFromDevices(widget.userId);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Salesman logged out from all devices')),
          );
        }
        break;
    }

    if (!success && mounted) {
      _showErrorDialog(usersProvider.errorMessage ?? 'Operation failed');
    }

    setState(() {
      _showConfirmDialog = false;
      _showChangePasswordDialog = false;
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Additional security layer: Only admin can access
    if (_userType != 1) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Salesman Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('Access denied. Admin only.'),
        ),
      );
    }

    // Show change password dialog
    if (_showChangePasswordDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: const OutlineInputBorder(),
                      errorText: _passwordError ? 'Passwords do not match' : null,
                    ),
                    obscureText: true,
                    onChanged: (value) {
                      if (_passwordError && value == _confirmPasswordController.text) {
                        setState(() {
                          _passwordError = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      border: const OutlineInputBorder(),
                      errorText: _passwordError ? 'Passwords do not match' : null,
                    ),
                    obscureText: true,
                    onChanged: (value) {
                      if (_passwordError && value == _passwordController.text) {
                        setState(() {
                          _passwordError = false;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showChangePasswordDialog = false;
                      _passwordController.clear();
                      _confirmPasswordController.clear();
                      _passwordError = false;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (_passwordController.text != _confirmPasswordController.text) {
                      setState(() {
                        _passwordError = true;
                      });
                      return;
                    }
                    if (_passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter password')),
                      );
                      return;
                    }
                    Navigator.of(context).pop();
                    setState(() {
                      _confirmMessage = 'Do you want to change the salesman password?';
                      _confirmDialogType = 0;
                      _showChangePasswordDialog = false;
                      _showConfirmDialog = true;
                    });
                  },
                  child: const Text('Update'),
                ),
              ],
            ),
          );
        }
      });
    }

    // Show confirm dialog
    if (_showConfirmDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirm'),
              content: Text(_confirmMessage),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showConfirmDialog = false;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handleConfirm();
                  },
                  child: const Text('Yes'),
                ),
              ],
            ),
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salesman Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<UsersProvider>(
        builder: (context, usersProvider, child) {
          if (usersProvider.isLoading && usersProvider.currentUser == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final userWithCategory = usersProvider.currentUser;
          if (userWithCategory == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Salesman not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      usersProvider.loadUserById(widget.userId);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final user = userWithCategory.user;
          _isUserActive = usersProvider.isUserActive;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Text(
                                  'Code : ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  user.code,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Text(
                                  'Category : ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  userWithCategory.categoryName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Text(
                                  'Phone : ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  user.phoneNo,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Address : ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    user.address,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Text(
                                  'Status : ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  _isUserActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _isUserActive
                                        ? Colors.green.shade700
                                        : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Edit button - top right
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.edit, size: 24),
                          onPressed: _handleEdit,
                        ),
                      ),
                      // Delete button - bottom right
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.delete, size: 24, color: Colors.red),
                          onPressed: _handleDelete,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleChangePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Change Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              if (_isUserActive) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleLogoutDevice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Logout Device',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

