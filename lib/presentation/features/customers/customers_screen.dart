import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/asset_images.dart';
import 'package:schedule_frontend_flutter/utils/notification_manager.dart';
import '../../provider/customers_provider.dart';
import '../../provider/orders_provider.dart';
import '../../../models/master_data_api.dart';
import '../../../utils/storage_helper.dart';
import 'create_customer_screen.dart';
import 'customer_details_screen.dart';

/// Customers Screen
/// Displays list of customers with search, route filter, and order creation
/// Converted from KMP's CustomersScreen.kt
class CustomersScreen extends StatefulWidget {
  final String? orderId; // If provided, this is selection mode for order

  const CustomersScreen({
    super.key,
    this.orderId,
  });

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CustomersProvider>(context, listen: false);
      provider.loadRoutes();
      provider.loadCustomers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch(String searchKey) {
    final provider = Provider.of<CustomersProvider>(context, listen: false);
    provider.setSearchKey(searchKey);
    provider.loadCustomers();
  }

  void _handleRouteFilter(int routeId, String routeName) {
    final provider = Provider.of<CustomersProvider>(context, listen: false);
    provider.setRouteFilter(routeId, routeName);
    provider.loadCustomers();
  }

  void _showRouteBottomSheetDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _RouteBottomSheet(
        provider: Provider.of<CustomersProvider>(context, listen: false),
        currentRouteId: Provider.of<CustomersProvider>(context).routeId,
        onRouteSelected: _handleRouteFilter,
      ),
    );
  }

  Future<void> _handleItemClick(CustomerWithNames customer) async {
    if (widget.orderId == null || widget.orderId!.isEmpty) {
      // Navigate to customer details
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerDetailsScreen(customerId: customer.customerId),
        ),
      );
    } else {
      // Selection mode - update order customer and navigate back
      // Converted from KMP's select callback (BaseScreen.kt line 913-919)
      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
      await ordersProvider.updateCustomer(customer.customerId, customer.name);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleOrderClick(CustomerWithNames customer) async {
    final provider = Provider.of<CustomersProvider>(context, listen: false);
    final order = await provider.getOrderByCustomer(customer);
    if (order != null && mounted) {
      // TODO: Navigate to order screen
      // Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(order: order)));
    }
  }

  void _handleAddNew() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateCustomerScreen(),
      ),
    ).then((result) {
      // Refresh customers list if customer was created successfully
      if (result == true && mounted) {
        final provider = Provider.of<CustomersProvider>(context, listen: false);
        provider.loadCustomers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isShowAddOrder = widget.orderId == null || widget.orderId!.isEmpty;

    return Consumer<NotificationManager>(
      builder: (context, notificationManager, _) {
        // Listen to notification trigger and refresh data
        if (notificationManager.notificationTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final provider = Provider.of<CustomersProvider>(context, listen: false);
            provider.loadCustomers();
            notificationManager.resetTrigger();
          });
        }

        return Scaffold(
      appBar: AppBar(
        title: const Text('Customers List'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
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
      body: Column(
        children: [
          // Route filter card
          Consumer<CustomersProvider>(
            builder: (context, provider, _) {
              return Card(
                margin: const EdgeInsets.all(8),
                child: InkWell(
                  onTap: _showRouteBottomSheetDialog,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.route, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.routeSt,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Customers list
          Expanded(
            child: Consumer<CustomersProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.customers.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null && provider.customers.isEmpty) {
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
                          onPressed: () => provider.loadCustomers(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.customers.isEmpty) {
                  return const Center(
                    child: Text(
                      'No customers found',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: provider.customers.length,
                  // separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final customer = provider.customers[index];
                    return _CustomerListItem(
                      customer: customer,
                      isShowAddOrder: isShowAddOrder,
                      onOrderClick: () => _handleOrderClick(customer),
                      onItemClick: () => _handleItemClick(customer),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // Add customer FAB (only for admin and not in selection mode)
      floatingActionButton: FutureBuilder<int>(
        future: StorageHelper.getUserType(),
        builder: (context, snapshot) {
          final isAdmin = snapshot.data == 1;
          if (isShowAddOrder && isAdmin) {
            return FloatingActionButton(
              onPressed: _handleAddNew,
              backgroundColor: Colors.black,
              child: const Icon(Icons.add, color: Colors.white),
            );
          }
          return const SizedBox.shrink();
        },
      ),
        );
      },
    );
  }
}

/// Customer List Item Widget
/// Converted from KMP's ListItem composable
class _CustomerListItem extends StatelessWidget {
  final CustomerWithNames customer;
  final bool isShowAddOrder;
  final VoidCallback onOrderClick;
  final VoidCallback onItemClick;

  const _CustomerListItem({
    required this.customer,
    required this.isShowAddOrder,
    required this.onOrderClick,
    required this.onItemClick,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate rating out of 5 (KMP: ratingOutOf5 = rating / 2)
    final ratingOutOf5 = (customer.rating / 2).clamp(0.0, 5.0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onItemClick,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const SizedBox(width: 10),
              // Customer icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(image: AssetImage(AssetImages.imagesCustomer)),
                  color: Colors.white,
                  // borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(5),
                
              ),
              const SizedBox(width: 6),
              // Customer details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.name.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  const Text(
                                    ' Code:',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    customer.code,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Text(
                                    ' Salesman:',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    customer.saleman ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isShowAddOrder)
                          IconButton(
                            iconSize: 36,
                            padding: const EdgeInsets.all(5),
                            icon: ImageIcon(
                              color: Colors.black,
                              AssetImage(AssetImages.imagesOrder
                              )),
                            onPressed: onOrderClick,
                          ),
                      ],
                    ),
                    // Route and status (admin) or route and rating (non-admin)
                    // Route and status/rating (admin shows status, non-admin shows route)
                    FutureBuilder<int>(
                      future: StorageHelper.getUserType(),
                      builder: (context, snapshot) {
                        final isAdmin = snapshot.data == 1;
                        if (isAdmin) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    ' Route:',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    customer.route ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Text(
                                    ' Status:',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    customer.flag == 1 ? 'Active' : 'Suspended',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: customer.flag == 1
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Star rating
                                  _StarRating(rating: ratingOutOf5),
                                ],
                              ),
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              const Text(
                                ' Route:',
                                style: TextStyle(fontSize: 12),
                              ),
                              Text(
                                customer.route ?? '',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const Spacer(),
                              // Star rating
                              _StarRating(rating: ratingOutOf5),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Star Rating Widget
/// Displays 5 stars based on rating (0-5)
/// Converted from KMP's star rating logic
class _StarRating extends StatelessWidget {
  final double rating;

  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        Color color;
        final starIndex = index + 1;
        IconData icon;
        if (rating >= starIndex) {
          icon = Icons.star; // Full star
          color = Colors.black;
        } else if (rating >= starIndex - 0.5) {
          icon = Icons.star_half; // Half star
          color = Colors.black;
        } else {
          icon = Icons.star_border; // Empty star
          color = Colors.grey;
        }
        return Icon(
          icon,
          size: 20,
          color: color,
        );
      }),
    );
  }
}

/// Route Bottom Sheet
/// Shows list of routes for filtering
/// Converted from KMP's ModalBottomSheetLayout
class _RouteBottomSheet extends StatelessWidget {
  final CustomersProvider provider;
  final int currentRouteId;
  final void Function(int routeId, String routeName) onRouteSelected;

  const _RouteBottomSheet({
    required this.provider,
    required this.currentRouteId,
    required this.onRouteSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
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
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select Route',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                // "All Routes" option
                ListTile(
                  title: const Text('All Routes'),
                  selected: currentRouteId == -1,
                  selectedTileColor: Colors.blue.shade50,
                  onTap: () {
                    onRouteSelected(-1, 'All Routes');
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                // Route list
                ...provider.routeList.map((route) {
                  final isSelected = currentRouteId == route.id;
                  return ListTile(
                    title: Text(route.name),
                    selected: isSelected,
                    selectedTileColor: Colors.blue.shade50,
                    onTap: () {
                      onRouteSelected(route.id, route.name);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

