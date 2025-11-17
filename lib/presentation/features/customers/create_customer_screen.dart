import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/customers_provider.dart';
import '../../../utils/storage_helper.dart';

/// Create Customer Screen
/// Screen for adding new customers
/// Converted from KMP's CreateCustomerScreen.kt
class CreateCustomerScreen extends StatefulWidget {
  const CreateCustomerScreen({super.key});

  @override
  State<CreateCustomerScreen> createState() => _CreateCustomerScreenState();
}

class _CreateCustomerScreenState extends State<CreateCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String _salesmanSt = 'Select salesman';
  int _salesmanId = -1;
  String _routeSt = 'Select route';
  int _routeId = -1;
  double _rating = 10.0;

  bool _hasChanges = false;
  final TextEditingController _newRouteNameController = TextEditingController();

  int _userType = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });

    // Track changes
    _codeController.addListener(_onFieldChanged);
    _nameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _addressController.addListener(_onFieldChanged);
  }

  Future<void> _loadUserData() async {
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
    final userName = await StorageHelper.getUser();

    setState(() {
      _userType = userType;

      // If user is salesman (type 3), auto-select as salesman
      if (userType == 3) {
        _salesmanId = userId;
        _salesmanSt = userName;
      }
    });
  }

  Future<void> _loadInitialData() async {
    final provider = Provider.of<CustomersProvider>(context, listen: false);
    await provider.loadSalesmen();
    await provider.loadRoutes();
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _newRouteNameController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_hasChanges) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard Changes?'),
          content: const Text('Are you sure you want to discard your changes?'),
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
      return shouldDiscard ?? false;
    }
    return true;
  }

  void _showSalesmanBottomSheet() {
    if (_userType != 1) return; // Only admin can select salesman

    final provider = Provider.of<CustomersProvider>(context, listen: false);
    if (provider.salesmanList.isEmpty) {
      _showError('Salesman not found');
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => _SelectionBottomSheet(
        title: 'Select Salesman',
        items: provider.salesmanList.map((s) => _SelectionItem(
          id: s.userId,
          name: s.name,
        )).toList(),
        selectedId: _salesmanId,
        onSelected: (id, name) {
          setState(() {
            _salesmanId = id;
            _salesmanSt = name;
            _routeId = -1; // Reset route when salesman changes
            _routeSt = 'Select route';
            _hasChanges = true;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showRouteBottomSheet() {
    if (_salesmanId == -1) {
      _showError('Select salesman first.');
      return;
    }

    final provider = Provider.of<CustomersProvider>(context, listen: false);
    
    // Filter routes by selected salesman
    final routesForSalesman = provider.routeList
        .where((route) => route.salesmanId == _salesmanId)
        .toList();

    if (routesForSalesman.isEmpty) {
      _showError('Routes not found');
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => _SelectionBottomSheet(
        title: 'Select Route',
        items: routesForSalesman.map((r) => _SelectionItem(
          id: r.id,
          name: r.name,
        )).toList(),
        selectedId: _routeId,
        onSelected: (id, name) {
          setState(() {
            _routeId = id;
            _routeSt = name;
            _hasChanges = true;
          });
          Navigator.pop(context);
        },
        showAddButton: _userType == 1, // Only admin can add route
        onAdd: () {
          Navigator.pop(context);
          _showAddRouteDialog();
        },
      ),
    );
  }

  void _showAddRouteDialog() {
    _newRouteNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Route'),
        content: TextField(
          controller: _newRouteNameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = _newRouteNameController.text.trim();
              if (name.isEmpty) {
                _showError('Enter name');
                return;
              }

              Navigator.pop(context);
              await _createRoute(name);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _createRoute(String name) async {
    final provider = Provider.of<CustomersProvider>(context, listen: false);
    
    // Check if route name already exists
    final result = await provider.createRoute(
      name: name,
      salesmanId: _salesmanId,
    );

    if (result && mounted) {
      _showSuccess('Route saved successfully');
      // Reload routes to include the new one
      await provider.loadRoutes();
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_codeController.text.trim().isEmpty) {
      _showError('Enter code');
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      _showError('Enter name');
      return;
    }

    if (_routeId == -1) {
      _showError('Select Route');
      return;
    }

    final provider = Provider.of<CustomersProvider>(context, listen: false);
    
    final success = await provider.createCustomer(
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty 
          ? '0' 
          : _phoneController.text.trim(),
      address: _addressController.text.trim(),
      routeId: _routeId,
      salesmanId: _salesmanId,
      rating: _rating.toInt(),
    );

    if (success && mounted) {
      Navigator.of(context).pop(true); // Return true to indicate success
    } else if (mounted && provider.errorMessage != null) {
      _showError(provider.errorMessage!);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          final canPop = await _onWillPop();
          if (canPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Customer'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final canPop = await _onWillPop();
              if (canPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Code field
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.none,
                  onChanged: (value) {
                    // Remove spaces from code
                    if (value.contains(' ')) {
                      _codeController.value = TextEditingValue(
                        text: value.replaceAll(' ', ''),
                        selection: _codeController.selection,
                      );
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Name field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
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
                // Phone Number field
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                // Salesman selector
                const Text(
                  'Salesman',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: _userType == 1 ? _showSalesmanBottomSheet : null,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _salesmanSt,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (_userType == 1)
                          const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Route selector
                const Text(
                  'Route',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: _showRouteBottomSheet,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _routeSt,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (_userType == 1)
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              if (_salesmanId == -1) {
                                _showError('Select salesman first.');
                              } else {
                                _showAddRouteDialog();
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Address field
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                // Rating slider
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Customer Rating: ${_rating.toInt()}/10',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _rating,
                      onChanged: (value) {
                        setState(() {
                          _rating = value;
                          _hasChanges = true;
                        });
                      },
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: _rating.toInt().toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Save button (only show when required fields are filled)
                if (_codeController.text.trim().isNotEmpty &&
                    _nameController.text.trim().isNotEmpty &&
                    _routeId != -1)
                  Consumer<CustomersProvider>(
                    builder: (context, provider, _) {
                      return ElevatedButton(
                        onPressed: provider.isLoading ? null : _saveCustomer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
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
                            : const Text(
                                'Save',
                                style: TextStyle(fontSize: 16),
                              ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selection Item Model
class _SelectionItem {
  final int id;
  final String name;

  const _SelectionItem({
    required this.id,
    required this.name,
  });
}

/// Selection Bottom Sheet Widget
class _SelectionBottomSheet extends StatelessWidget {
  final String title;
  final List<_SelectionItem> items;
  final int selectedId;
  final void Function(int id, String name) onSelected;
  final bool showAddButton;
  final VoidCallback? onAdd;

  const _SelectionBottomSheet({
    required this.title,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.showAddButton = false,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (showAddButton && onAdd != null)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: onAdd,
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedId == item.id;
                return ListTile(
                  title: Text(item.name),
                  selected: isSelected,
                  selectedTileColor: Colors.blue.shade50,
                  leading: Radio<int>(
                    value: item.id,
                    groupValue: selectedId,
                    onChanged: (value) {
                      if (value != null) {
                        onSelected(value, item.name);
                      }
                    },
                  ),
                  onTap: () => onSelected(item.id, item.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

