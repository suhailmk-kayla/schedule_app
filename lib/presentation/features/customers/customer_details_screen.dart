import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/customers_provider.dart';
import '../../../utils/storage_helper.dart';
import '../../../utils/toast_helper.dart';
import '../../../models/master_data_api.dart';
import 'create_customer_screen.dart';

/// Customer Details Screen
/// Shows customer information with suspend and edit buttons (admin only)
/// Converted from KMP's CustomerDetails.kt
class CustomerDetailsScreen extends StatefulWidget {
  final int customerId;

  const CustomerDetailsScreen({
    super.key,
    required this.customerId,
  });

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  CustomerWithNames? _customer;

  bool _isLoading = false;

  int _userType = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomerDetails();
    });
  }

  Future<void> _loadUserData() async {
    final userType = await StorageHelper.getUserType();
    setState(() {
      _userType = userType;
    });
  }

  Future<void> _loadCustomerDetails() async {
    setState(() {
      _isLoading = true;
    });

    final provider = Provider.of<CustomersProvider>(context, listen: false);
    
    // Get customer from the list (which has joined names)
    final customers = provider.customers;
    final customerWithNames = customers.firstWhere(
      (c) => c.customerId == widget.customerId,
      orElse: () => throw Exception('Customer not found in list'),
    );

    if (!mounted) return;

    setState(() {
      _customer = customerWithNames;
      _isLoading = false;
    });
  }

  Future<void> _handleSuspendActivate() async {
    if (_customer == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(_customer!.flag == 1
            ? 'Do you want to Suspend this customer?'
            : 'Do you want to Activate this customer?'),
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

    if (confirm == true) {
      await _confirmSuspendActivate();
    }
  }

  Future<void> _confirmSuspendActivate() async {
    if (_customer == null) return;

    setState(() {
      _isLoading = true;
    });

    final provider = Provider.of<CustomersProvider>(context, listen: false);
    final newFlag = _customer!.flag == 1 ? 0 : 1;
    final success = await provider.updateCustomerFlag(
      customerId: widget.customerId,
      salesmanId: _customer!.salesmanId,
      flag: newFlag,
    );

    if (!mounted) return;

    if (success) {
      // Wait for provider to reload customers list
      await provider.loadCustomers();
      
      // Reload customer details to get updated data
      await _loadCustomerDetails();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Show success toast
        ToastHelper.showSuccess(
          newFlag == 1
              ? 'Customer activated successfully'
              : 'Customer suspended successfully',
        );
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        // Show error toast
        ToastHelper.showError(
          provider.errorMessage ?? 'Failed to update customer status',
        );
      }
    }
  }

  Future<void> _handleEdit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCustomerScreen(
          customerId: widget.customerId,
        ),
      ),
    );
    
    // Reload customer details if customer was updated
    if (result == true && mounted) {
      final provider = Provider.of<CustomersProvider>(context, listen: false);
      // Wait for customers list to reload before loading details
      await provider.loadCustomers();
      await _loadCustomerDetails();
    }
  }

  Widget _buildStarRating(int rating) {
    const starCount = 5;
    final ratingOutOf5 = (rating / 2.0).clamp(0.0, 5.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(starCount, (index) {
        final starIndex = index + 1;
        IconData icon;
        Color color;

        if (ratingOutOf5 >= starIndex) {
          icon = Icons.star;
          color = Colors.amber;
        } else if (ratingOutOf5 >= starIndex - 0.5) {
          icon = Icons.star_half;
          color = Colors.amber;
        } else {
          icon = Icons.star_border;
          color = Colors.grey;
        }

        return Icon(
          icon,
          size: 24,
          color: color,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Additional security layer: Only admin can access
    // if (_userType != 1) {
    //   return Scaffold(
    //     appBar: AppBar(
    //       title: const Text('Customer Details'),
    //       leading: IconButton(
    //         icon: const Icon(Icons.arrow_back),
    //         onPressed: () => Navigator.of(context).pop(),
    //       ),
    //     ),
    //     body: const Center(
    //       child: Text('Access denied. Admin only.'),
    //     ),
    //   );
    // }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading || _customer == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _customer!.name.toUpperCase(),
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
                                _customer!.code,
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
                                _customer!.phone,
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
                                'Salesman : ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _customer!.saleman ?? '',
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
                                'Route : ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _customer!.route ?? '',
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
                                  _customer!.address,
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
                                _customer!.flag == 1 ? 'Active' : 'Suspended',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _customer!.flag == 1
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Text(
                                'Rating : ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              _buildStarRating(_customer!.rating),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Visibility(
        visible: _userType == 1,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleSuspendActivate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _customer?.flag == 1
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      _customer?.flag == 1 ? 'Suspend' : 'Activate',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleEdit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

