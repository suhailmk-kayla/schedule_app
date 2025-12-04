import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/users_provider.dart';
import '../../../helpers/user_type_helper.dart';
import 'create_user_screen.dart';

/// User Details Screen
/// Displays user details with edit, delete, change password, and logout device options
/// Converted from KMP's UserDetails.kt
class UserDetailsScreen extends StatefulWidget {
  final int userId;

  const UserDetailsScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  bool _showChangePasswordDialog = false;
  bool _showConfirmDialog = false;
  String _confirmMessage = '';
  int _confirmDialogType = 0; // 0-change password, 1-logout devices, 2-delete user
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _passwordError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<UsersProvider>(context, listen: false);
      provider.loadUserById(widget.userId);
      provider.checkUserActive(widget.userId);
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateUserScreen(userId: widget.userId),
      ),
    ).then((_) {
      // Reload user data after returning from edit screen
      if (mounted) {
        final provider = Provider.of<UsersProvider>(context, listen: false);
        provider.loadUserById(widget.userId);
        provider.checkUserActive(widget.userId);
      }
    });
  }

  void _handleDelete() {
    setState(() {
      _confirmMessage =
          'This will delete the user permanently. And also logout from the login devices?\n\nDo you want to continue?';
      _confirmDialogType = 2;
      _showConfirmDialog = true;
    });
  }

  void _handleChangePassword() {
    setState(() {
      _showChangePasswordDialog = true;
    });
  }

  void _handleLogoutDevice() {
    setState(() {
      _confirmMessage = 'Do you want to Logout from this user devices?';
      _confirmDialogType = 1;
      _showConfirmDialog = true;
    });
  }

  Future<void> _handleConfirm() async {
    final provider = Provider.of<UsersProvider>(context, listen: false);
    bool success = false;

    switch (_confirmDialogType) {
      case 0: // Change password
        success = await provider.changeUserPassword(
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

      case 1: // Logout devices
        success = await provider.logoutFromDevices(widget.userId);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User logged out from all devices')),
          );
        }
        break;

      case 2: // Delete user
        final currentUser = provider.currentUser;
        if (currentUser != null) {
          success = await provider.deleteUser(
            userId: widget.userId,
            categoryId: currentUser.user.catId,
          );
          if (success && mounted) {
            Navigator.of(context).pop();
          }
        }
        break;
    }

    if (!success && mounted) {
      _showErrorDialog(provider.errorMessage ?? 'Operation failed');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_showChangePasswordDialog) _buildChangePasswordDialog(),
          if (_showConfirmDialog) _buildConfirmDialog(),
        ],
      ),
      bottomNavigationBar: Consumer<UsersProvider>(
        builder: (context, provider, _) {
          return SafeArea(
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
                  if (provider.isUserActive) ...[
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
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<UsersProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.currentUser == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.currentUser == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  provider.errorMessage ?? 'User not found',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          );
        }

        final userWithCategory = provider.currentUser!;
        final user = userWithCategory.user;
        final categoryName = userWithCategory.categoryName.isNotEmpty
            ? userWithCategory.categoryName
            : UserTypeHelper.nameFromCatId(user.catId);
        final showAddress = user.catId == 3 || user.catId == 4; // SalesMan or Supplier

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // User details card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: Stack(
                  children: [
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User name
                          Text(
                            user.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Code
                          Row(
                            children: [
                              const Text(
                                'Code : ',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                user.code,
                                style: const TextStyle(fontSize: 14, color: Colors.black),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Category
                          Row(
                            children: [
                              const Text(
                                'Category : ',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                categoryName,
                                style: const TextStyle(fontSize: 14, color: Colors.black),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Phone
                          Row(
                            children: [
                              const Text(
                                'Phone : ',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                user.phoneNo,
                                style: const TextStyle(fontSize: 14, color: Colors.black),
                              ),
                            ],
                          ),
                          // Address (only for SalesMan or Supplier)
                          if (showAddress) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Text(
                                  'Address : ',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Expanded(
                                  child: Text(
                                    user.address,
                                    style: const TextStyle(fontSize: 14, color: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          // Status
                          Row(
                            children: [
                              const Text(
                                'Status : ',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                provider.isUserActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: provider.isUserActive ? Colors.green : Colors.red,
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
    );
  }

  Widget _buildChangePasswordDialog() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: AlertDialog(
          title: const Text('Change password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                onChanged: (_) {
                  setState(() {
                    _passwordError = false;
                  });
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
                onChanged: (_) {
                  setState(() {
                    _passwordError = false;
                  });
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
                });
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
                setState(() {
                  _confirmMessage = 'Do you want to change the user password?';
                  _confirmDialogType = 0;
                  _showChangePasswordDialog = false;
                  _showConfirmDialog = true;
                });
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmDialog() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: AlertDialog(
          title: const Text('Confirm'),
          content: Text(_confirmMessage),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _showConfirmDialog = false;
                });
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: _handleConfirm,
              child: const Text('Yes'),
            ),
          ],
        ),
      ),
    );
  }
}

