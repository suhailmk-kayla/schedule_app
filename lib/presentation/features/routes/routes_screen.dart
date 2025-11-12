import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/asset_images.dart';
import '../../provider/routes_provider.dart';
import '../../../models/master_data_api.dart';
import '../../../models/salesman_model.dart';

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
  bool _showAddRouteDialog = false;
  bool _showErrorAlert = false;
  String _errorMessage = '';
  bool _isEditClick = false;
  String _editRouteName = '';
  int _editRouteId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RoutesProvider>(context, listen: false);
      provider.loadRoutes();
      provider.loadSalesmen(); // Load salesmen for checker selection
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch(String searchKey) {
    final provider = Provider.of<RoutesProvider>(context, listen: false);
    provider.loadRoutes(searchKey: searchKey);
  }

  void _handleEditClick(RouteWithSalesman route) {
    setState(() {
      _isEditClick = true;
      _editRouteName = route.name;
      _editRouteId = route.routeId;
      _showAddRouteDialog = true;
    });
  }

  void _handleAddRoute() {
    setState(() {
      _isEditClick = false;
      _editRouteName = '';
      _editRouteId = 0;
      _showAddRouteDialog = true;
    });
  }

  void _handleDialogDismiss() {
    setState(() {
      _isEditClick = false;
      _editRouteName = '';
      _editRouteId = 0;
      _showAddRouteDialog = false;
    });
  }

  void _handleConfirmation(String name, int salesmanId) {
    final provider = Provider.of<RoutesProvider>(context, listen: false);

    if (_isEditClick) {
      // Update route
      provider.updateRoute(
        routeId: _editRouteId,
        name: name,
      ).then((result) {
        result.fold(
          (failure) {
            setState(() {
              _errorMessage = failure.message;
              _showErrorAlert = true;
            });
          },
          (_) {
            setState(() {
              _isEditClick = false;
              _editRouteName = '';
              _editRouteId = 0;
              _errorMessage = 'Route updated successfully';
              _showErrorAlert = true;
              _showAddRouteDialog = false;
            });
            provider.loadRoutes(searchKey: _searchController.text);
          },
        );
      });
    } else {
      // Create route
      provider.createRoute(
        name: name,
        salesmanId: salesmanId,
      ).then((result) {
        result.fold(
          (failure) {
            setState(() {
              _errorMessage = failure.message;
              _showErrorAlert = true;
            });
          },
          (_) {
            setState(() {
              _isEditClick = false;
              _editRouteName = '';
              _editRouteId = 0;
              _errorMessage = 'Route Added successfully';
              _showErrorAlert = true;
              _showAddRouteDialog = false;
            });
            provider.loadRoutes(searchKey: _searchController.text);
          },
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show dialogs when needed
    if (_showAddRouteDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => _AddRouteDialog(
            provider: Provider.of<RoutesProvider>(context, listen: false),
            isAddNew: !_isEditClick,
            name: _editRouteName,
            onDismissRequest: _handleDialogDismiss,
            onConfirmation: _handleConfirmation,
          ),
        ).then((_) {
          setState(() {
            _showAddRouteDialog = false;
          });
        });
      });
    }

    if (_showErrorAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Alert'),
            content: Text(_errorMessage),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _showErrorAlert = false;
                  });
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        ).then((_) {
          setState(() {
            _showErrorAlert = false;
          });
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route List'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Show search dialog or expand search bar
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Search'),
                  content: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Enter search key',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      Navigator.pop(context);
                      _handleSearch(value);
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleSearch(_searchController.text);
                      },
                      child: const Text('Search'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
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
              // Search bar
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search routes...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: _handleSearch,
                  onSubmitted: _handleSearch,
                ),
              ),
              // Routes list
              Expanded(
                child: ListView.separated(
                  itemCount: provider.routesList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
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
      elevation: 4,
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
  final VoidCallback onDismissRequest;
  final void Function(String name, int salesmanId) onConfirmation;

  const _AddRouteDialog({
    required this.provider,
    required this.isAddNew,
    required this.name,
    required this.onDismissRequest,
    required this.onConfirmation,
  });

  @override
  State<_AddRouteDialog> createState() => _AddRouteDialogState();
}

class _AddRouteDialogState extends State<_AddRouteDialog> {
  late TextEditingController _routeNameController;
  int _checkerId = -1;
  String _checkerSt = '';
  bool _showCheckerDialog = false;

  @override
  void initState() {
    super.initState();
    _routeNameController = TextEditingController(text: widget.name);
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
                title: const Text('Select Checker'),
                content: provider.salesmanList.isEmpty
                    ? const Text('No checker found')
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
                      'Checker',
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
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showCheckerDialog = true;
                      });
                    },
                    child: Text(
                      _checkerSt.isEmpty ? 'Select Checker' : _checkerSt,
                      style: TextStyle(
                        color: _checkerSt.isEmpty ? Colors.grey : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Route name field
                TextField(
                  controller: _routeNameController,
                  decoration: const InputDecoration(
                    labelText: 'name',
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
                if (_routeNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter name')),
                  );
                  return;
                }
                if (widget.isAddNew && _checkerId == -1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Select checker')),
                  );
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

