import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/asset_images.dart';
import '../../provider/routes_provider.dart';
import '../../../models/master_data_api.dart';
import '../../../utils/toast_helper.dart';

/// Routes Screen
/// Displays list of routes with search, add, and edit functionality
/// Converted from KMP's RoutesScreen.kt
class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RoutesProvider>(context, listen: false);
      provider.loadRoutes();
      provider.loadSalesmen(); 
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearch(String searchKey) {
    final provider = Provider.of<RoutesProvider>(context, listen: false);
    provider.loadRoutes(searchKey: searchKey);
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        // Clear search when closing
        _searchController.clear();
        _handleSearch('');
      }
    });
    // Focus search field when opened
    if (_showSearchBar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  void _handleEditClick(RouteWithSalesman route) {
    final provider = Provider.of<RoutesProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => _AddRouteDialog(
        provider: provider,
        isAddNew: false,
        name: route.name,
        routeId: route.routeId,
        salesmanId: route.route.salesmanId, // Pass existing salesman ID
        salesmanName: route.salesman, // Pass existing salesman name
        onDismissRequest: () => Navigator.pop(context),
        onConfirmation: (name, salesmanId) {
          Navigator.pop(context); // Close dialog first
          _performUpdateRoute(route.routeId, name);
        },
      ),
    );
  }

  void _handleAddRoute() {
    final provider = Provider.of<RoutesProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => _AddRouteDialog(
        provider: provider,
        isAddNew: true,
        name: '',
        routeId: -1,
        salesmanId: -1, // No existing salesman for new route
        salesmanName: '', // No existing salesman name for new route
        onDismissRequest: () => Navigator.pop(context),
        onConfirmation: (name, salesmanId) {
          Navigator.pop(context); // Close dialog first
          _performCreateRoute(name, salesmanId);
        },
      ),
    );
  }

  Future<void> _performCreateRoute(String name, int salesmanId) async {
    final provider = Provider.of<RoutesProvider>(context, listen: false);
    final result = await provider.createRoute(
      name: name,
      salesmanId: salesmanId,
    );

    result.fold(
      (failure) {
        if (mounted) {
          ToastHelper.showError(failure.message);
        }
      },
      (_) {
        if (mounted) {
          ToastHelper.showSuccess('Route added successfully');
          provider.loadRoutes(searchKey: _searchController.text);
        }
      },
    );
  }

  Future<void> _performUpdateRoute(int routeId, String name) async {
    final provider = Provider.of<RoutesProvider>(context, listen: false);
    final result = await provider.updateRoute(
      routeId: routeId,
      name: name,
    );

    result.fold(
      (failure) {
        if (mounted) {
          ToastHelper.showError(failure.message);
        }
      },
      (_) {
        if (mounted) {
          ToastHelper.showSuccess('Route updated successfully');
          provider.loadRoutes(searchKey: _searchController.text);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _showSearchBar
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  _handleSearch(value);
                },
              )
            : const Text('Route List'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_showSearchBar ? Icons.close : Icons.search),
            onPressed: _toggleSearchBar,
          ),
        ],
      ),
      body: Consumer<RoutesProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.routesList.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null && provider.routesList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadRoutes(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.routesList.isEmpty) {
            return const Center(
              child: Text(
                'No routes found',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            );
          }

          return Column(
            children: [
              // Routes list
              Expanded(
                child: ListView.builder(
                  itemCount: provider.routesList.length,
                  itemBuilder: (context, index) {
                    final route = provider.routesList[index];
                    return _RouteListItem(
                      route: route,
                      onEditClick: () => _handleEditClick(route),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleAddRoute,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

/// Route List Item Widget
/// Converted from KMP's ListItem composable
class _RouteListItem extends StatelessWidget {
  final RouteWithSalesman route;
  final VoidCallback onEditClick;

  const _RouteListItem({
    required this.route,
    required this.onEditClick,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            const SizedBox(width: 10),
            // Route icon
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                image: DecorationImage(image: AssetImage(AssetImages.imagesRoute),fit: BoxFit.cover),
                // color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(10),
             
            ),
            const SizedBox(width: 10),
            // Route name
            Expanded(
              child: Text(
                route.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Edit button
            IconButton(
              icon: const Icon(Icons.edit, size: 24),
              onPressed: onEditClick,
            ),
          ],
        ),
      ),
    );
  }
}

/// Add/Edit Route Dialog
/// Converted from KMP's AddDialog composable
class _AddRouteDialog extends StatefulWidget {
  final RoutesProvider provider;
  final bool isAddNew;
  final String name;
  final int routeId;
  final int salesmanId; // Existing salesman ID (for edit mode)
  final String salesmanName; // Existing salesman name (for edit mode)
  final VoidCallback onDismissRequest;
  final void Function(String name, int salesmanId) onConfirmation;

  const _AddRouteDialog({
    required this.provider,
    required this.isAddNew,
    required this.name,
    required this.routeId,
    required this.salesmanId,
    required this.salesmanName,
    required this.onDismissRequest,
    required this.onConfirmation,
  });

  @override
  State<_AddRouteDialog> createState() => _AddRouteDialogState();
}

class _AddRouteDialogState extends State<_AddRouteDialog> {
  late TextEditingController _routeNameController;
  late int _checkerId;
  late String _checkerSt;
  bool _showCheckerDialog = false;

  @override
  void initState() {
    super.initState();
    _routeNameController = TextEditingController(text: widget.name);
    // Initialize with existing salesman if editing, otherwise default to -1
    _checkerId = widget.salesmanId;
    _checkerSt = widget.salesmanName;
    // Always load salesmen when dialog opens (like KMP's LaunchedEffect)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.provider.loadSalesmen();
    });
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show checker selection dialog if needed
    if (_showCheckerDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => Consumer<RoutesProvider>(
            builder: (context, provider, _) {
              return AlertDialog(
                title: const Text('Select Salesman'),
                content: provider.salesmanList.isEmpty
                    ? const Text('No Salesman found')
                    : SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: provider.salesmanList.length,
                          itemBuilder: (context, index) {
                            final salesman = provider.salesmanList[index];
                            return RadioListTile<int>(
                              title: Text(salesman.name),
                              value: salesman.userId,
                              groupValue: _checkerId,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _checkerId = value;
                                    _checkerSt = salesman.name;
                                    _showCheckerDialog = false;
                                  });
                                  Navigator.pop(context);
                                }
                              },
                            );
                          },
                        ),
                      ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showCheckerDialog = false;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          ),
        ).then((_) {
          setState(() {
            _showCheckerDialog = false;
          });
        });
      });
    }

    return Consumer<RoutesProvider>(
      builder: (context, provider, _) {
        return AlertDialog(
          title: Text(widget.isAddNew ? 'Add Route' : 'Update Route'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // Checker selection
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Salesman',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                    color: widget.isAddNew ? null : Colors.grey[100], // Disabled appearance for edit mode
                  ),
                  child: InkWell(
                    onTap: widget.isAddNew
                        ? () {
                            setState(() {
                              _showCheckerDialog = true;
                            });
                          }
                        : null, // Disable tap in edit mode
                    child: Text(
                      _checkerSt.isEmpty ? 'Select Salesman' : _checkerSt,
                      style: TextStyle(
                        color: _checkerSt.isEmpty ? Colors.grey : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Route name field
                TextFormField(
                  controller: _routeNameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Route name cannot be empty';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Route name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.none,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onDismissRequest();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Validation 1: Route name cannot be empty
                if (_routeNameController.text.trim().isEmpty) {
                  ToastHelper.showWarning('Route name cannot be empty');
                  return;
                }
                // Validation 2: Salesman cannot be empty
                if (_checkerId == -1) {
                  ToastHelper.showWarning('Please select salesman');
                  return;
                }
                Navigator.pop(context);
                widget.onConfirmation(
                  _routeNameController.text.trim(),
                  _checkerId,
                );
              },
              child: Text(widget.isAddNew ? 'Add' : 'Update'),
            ),
          ],
        );
      },
    );
  }
}

