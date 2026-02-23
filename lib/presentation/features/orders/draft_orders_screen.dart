import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:schedule_frontend_flutter/presentation/features/home/home_drawer.dart';
import 'package:schedule_frontend_flutter/presentation/features/orders/order_details_storekeeper_screen.dart';
import 'package:schedule_frontend_flutter/utils/notification_manager.dart';
import 'package:schedule_frontend_flutter/utils/toast_helper.dart';
import '../../provider/orders_provider.dart';
import '../../provider/home_provider.dart';
import '../../../models/order_api.dart';
import '../../../models/order_with_name.dart';
import '../../../utils/storage_helper.dart';
import 'create_order_screen.dart';
import 'order_details_checker_screen.dart';
import 'order_details_biller_screen.dart';

/// Draft Orders Screen
/// Displays list of draft orders (flag = 3) only
/// Converted from KMP's OrderListScreen.kt with flag filter
class DraftOrdersScreen extends StatefulWidget {
  final int? salesmanId; // If provided, filters orders by this salesman

  const DraftOrdersScreen({
    super.key,
    this.salesmanId,
  });

  @override
  State<DraftOrdersScreen> createState() => _DraftOrdersScreenState();
}

class _DraftOrdersScreenState extends State<DraftOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;
  int _userType = 0;
  int _userId = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
      ordersProvider.loadRoutes();
      
      // If salesmanId is provided, set it as filter
      if (widget.salesmanId != null) {
        ordersProvider.setSalesmanFilter(widget.salesmanId!);
      }
      
      // Load draft orders only (flag = 3)
      ordersProvider.loadDraftOrders();
    });
  }

  Future<void> _loadUserData() async {
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();
    setState(() {
      _userType = userType;
      _userId = userId;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersProvider = Provider.of<OrdersProvider>(context);

    return Consumer<NotificationManager>(
      builder: (context, notificationManager,_) {
        // Listen to notification trigger and refresh data
        if (notificationManager.notificationTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final provider = Provider.of<OrdersProvider>(context, listen: false);
            provider.loadDraftOrders(toRefresh: true);
            notificationManager.resetTrigger();
          });
        }

        return Scaffold(
          drawer: _userType == 5|| _userType == 6|| _userType == 7 ? HomeDrawer() : null,
      appBar: AppBar(
        title: _showSearchBar
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  ordersProvider.setSearchKey(value);
                  ordersProvider.loadDraftOrders();
                },
              )
            : Text(widget.salesmanId != null
                ? 'Salesman Draft Orders'
                : 'Draft Orders'),
     
        actions: [
          IconButton(
            icon: Icon(_showSearchBar ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchController.clear();
                  ordersProvider.setSearchKey('');
                  ordersProvider.loadDraftOrders();
                }
              });
            },
          ),
        ],
      ),
      body: Consumer<OrdersProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.orderList.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.errorMessage != null) {
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
                    onPressed: () => provider.loadDraftOrders(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Filter Row
              _FilterRow(
                routeSt: provider.routeSt,
                dateSt: _getDateDisplay(provider.date, provider.dateFilterIndex),
                onRouteTap: () => _showRouteFilter(context, provider),
                onDateTap: () => _showDateFilter(context, provider),
              ),
              // Order List
              Expanded(
                child: provider.orderList.isEmpty
                    ? const Center(
                        child: Text(
                          'No draft orders found',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: provider.orderList.length,
                        itemBuilder: (context, index) {
                          final orderWithName = provider.orderList[index];
                          return _OrderListItem(
                            orderWithName: orderWithName,
                            userType: _userType,
                            userId: _userId,
                            onTap: () async {
                              final order = orderWithName.order;
                              // For admin (userType == 1), navigate to CreateOrderScreen to edit draft
                              // Draft orders can be edited via CreateOrderScreen
                              if (_userType == 1) {
                                // Admin can view or edit draft orders
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CreateOrderScreen(
                                      orderId: order.orderId.toString(),
                                    ),
                                  ),
                                ).then((_) {
                                  // Refresh badge counts when returning
                                  final homeProvider = Provider.of<HomeProvider>(context, listen: false);
                                  homeProvider.refreshCounts();
                                  // Reload draft orders
                                  ordersProvider.loadDraftOrders();
                                });
                              } else if (_userType == 2) {
                                // Storekeeper flow: claim if unassigned, otherwise validate ownership
                                if (order.orderStockKeeperId == -1) {
                                  final success = await provider.claimOrderAsStorekeeper(
                                    orderId: order.orderId,
                                    storekeeperId: _userId,
                                  );
                                  if (!success) {
                                    final msg = provider.errorMessage ??
                                        'Failed to claim order. Please try again.';
                                    if (context.mounted) {
                                      ToastHelper.showError(msg);
                                    }
                                    return;
                                  }
                                } else if (order.orderStockKeeperId != _userId) {
                                  if (context.mounted) {
                                    ToastHelper.showSuccess('Another storekeeper is checking this order.');
                                  }
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        OrderDetailsStorekeeperScreen(orderId: order.orderId),
                                  ),
                                ).then((_) {
                                  // Refresh badge counts when returning
                                  final homeProvider = Provider.of<HomeProvider>(context, listen: false);
                                  homeProvider.refreshCounts();
                                  // Reload draft orders
                                  ordersProvider.loadDraftOrders();
                                });
                              } else if (_userType == 3) {
                                // Salesman can edit their draft orders
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CreateOrderScreen(orderId: order.orderId.toString()),
                                  ),
                                ).then((_) {
                                  // Refresh badge counts when returning
                                  final homeProvider = Provider.of<HomeProvider>(context, listen: false);
                                  homeProvider.refreshCounts();
                                  // Reload draft orders
                                  ordersProvider.loadDraftOrders();
                                });
                              } else if (_userType == 6) {
                                // Checker flow: claim if unassigned, otherwise validate ownership
                                if (order.orderCheckerId < 1 && order.orderCheckerId != _userId) {
                                  final success = await provider.claimOrderAsChecker(
                                    orderId: order.orderId,
                                    checkerId: _userId,
                                  );
                                  if (!success) {
                                    final msg = provider.errorMessage ??
                                        'Failed to claim order for checking. Please try again.';
                                    if (context.mounted) {
                                      ToastHelper.showSuccess(msg);
                                      // ScaffoldMessenger.of(context).showSnackBar(
                                      //   SnackBar(content: Text(msg)),
                                      // );
                                    }
                                    return;
                                  }
                                } else if (order.orderCheckerId != _userId) {
                                  if (context.mounted) {
                                   ToastHelper.showSuccess('Another checker is currently working on this order.');
                                   return;
                                  }
                                  return;
                                }

                                // Navigate to checker order details
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderDetailsCheckerScreen(orderId: order.orderId),
                                  ),
                                ).then((_) {
                                  // Refresh badge counts when returning
                                  final homeProvider = Provider.of<HomeProvider>(context, listen: false);
                                  homeProvider.refreshCounts();
                                  // Reload draft orders
                                  ordersProvider.loadDraftOrders();
                                });
                              } else if (_userType == 5) {
                                _handleBillerOrderTap(context, order);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Order details for this role will be available soon.'),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: (_userType == 3 || _userType == 1)
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateOrderScreen(),
                  ),
                ).then((_) {
                  // Reload draft orders after creating new one
                  ordersProvider.loadDraftOrders();
                });
              },
              backgroundColor: Colors.black,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
        );
      },
    );
  }

  String _getDateDisplay(String date, int dateFilterIndex) {
    const dateFilterList = ['All', 'Today', 'Yesterday', 'Custom'];
    if (dateFilterIndex < 3) {
      return dateFilterList[dateFilterIndex];
    }
    if (date.isNotEmpty) {
      try {
        final dateTime = DateFormat('yyyy-MM-dd').parse(date);
        return DateFormat('MMM dd, yyyy').format(dateTime);
      } catch (e) {
        return date;
      }
    }
    return 'Custom';
  }

  void _showRouteFilter(BuildContext context, OrdersProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _RouteFilterBottomSheet(
        routeList: provider.routeList,
        selectedRouteId: provider.routeId,
        onRouteSelected: (routeId, routeName) {
          provider.setRouteFilter(routeId, routeName);
          provider.loadDraftOrders();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDateFilter(BuildContext context, OrdersProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _DateFilterBottomSheet(
        selectedDateIndex: provider.dateFilterIndex,
        selectedDate: provider.date,
        onDateSelected: (index, date) {
          provider.setDateFilterIndex(index);
          provider.setDate(date);
          provider.loadDraftOrders();
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _handleBillerOrderTap(BuildContext context, Order order) async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Biller can claim order if not already assigned (matches KMP line 290)
    // Check for both 0 and -1 (KMP checks: order.billerId == 0L || order.billerId == -1L)
    if (order.orderBillerId == -1 || order.orderBillerId == 0) {
      final success = await ordersProvider.sendToBillerOrChecker(
        isBiller: true,
        userId: _userId,
        order: order,
        // No approvalFlag - preserves current order state (matches KMP line 292)
      );

      if (!mounted) return;
      if (!success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              ordersProvider.errorMessage ??
                  'Failed to claim order for billing.',
            ),
          ),
        );
        return;
      }
    } else if (order.orderBillerId != _userId) {
      // Another biller is working on this order
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Another biller is currently working on this order.'),
        ),
      );
      return;
    }

    // Navigate to biller-specific order details screen with Estimated/Final Bill tabs
    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => OrderDetailsBillerScreen(orderId: order.orderId),
      ),
    ).then((_) {
      // Refresh badge counts when returning
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      homeProvider.refreshCounts();
    });

    // Refresh draft orders list after returning
    if (!mounted) return;
    ordersProvider.loadDraftOrders();
  }
}

/// Filter Row Widget
/// Shows route and date filter buttons
class _FilterRow extends StatelessWidget {
  final String routeSt;
  final String dateSt;
  final VoidCallback onRouteTap;
  final VoidCallback onDateTap;

  const _FilterRow({
    required this.routeSt,
    required this.dateSt,
    required this.onRouteTap,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: InkWell(
              onTap: onRouteTap,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  routeSt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: InkWell(
              onTap: onDateTap,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  dateSt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Order List Item Widget
/// Displays order card with details
/// Converted from KMP's ListItem composable
class _OrderListItem extends StatelessWidget {
  final OrderWithName orderWithName;
  final int userType;
  final int userId;
  final VoidCallback onTap;

  const _OrderListItem({
    required this.orderWithName,
    required this.userType,
    required this.userId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final order = orderWithName.order;
    final isPending = order.orderFlag == 1 && order.orderApproveFlag == 0;

    return Card(
      elevation: isPending ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Invoice No and Date
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderInvNo.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isPending ? FontWeight.bold : FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatDate(order.updatedAt),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isPending ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Customer
              Text(
                'customer: ${orderWithName.customerName.isNotEmpty ? orderWithName.customerName : order.orderCustName}',
                style: TextStyle(
                  fontWeight: isPending ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              // Salesman (if exists and not salesman user)
              if (order.orderSalesmanId != -1 && userType != 3) ...[
                const SizedBox(height: 4),
                //  
                Text(
                  // 'Salesman: ${orderWithName.salesManName.isNotEmpty ? orderWithName.salesManName : "N/A"}',
                  'Salesman: ${_getSalesmanName(orderWithName, userType, userId)}',
                  style: TextStyle(
                    fontWeight: isPending ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
              // Storekeeper (if exists)
              if (order.orderStockKeeperId != -1) ...[
                const SizedBox(height: 4),
                Text(
                  'Storekeeper: ${orderWithName.storeKeeperName.isNotEmpty ? orderWithName.storeKeeperName : "N/A"}',
                  style: TextStyle(
                    fontWeight: isPending ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
              // Route (if exists)
              if (orderWithName.route.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Route: ${orderWithName.route}',
                  style: TextStyle(
                    fontWeight: isPending ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
              // Status
              if (userType != 5) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text(
                      'Status: ',
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _getOrderStatus(order, userType, userId),
                      style: TextStyle(
                        fontWeight: isPending ? FontWeight.bold : FontWeight.normal,
                        fontStyle: FontStyle.italic,
                        color: _getStatusColor(order, userType, userId),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getSalesmanName(OrderWithName orderWithName, int userType, int userId) {
    if (userType == 1 && orderWithName.order.orderSalesmanId == userId) {
      return '${orderWithName.salesManName}(SELF ORDER)';
    }
     
    return orderWithName.salesManName.isNotEmpty
        ? orderWithName.salesManName
        : 'N/A';
  }

  String _getOrderStatus(Order order, int userType, int userId) {
    if (order.orderFlag != 1) {
      return 'Draft';
    }

    switch (order.orderApproveFlag) {
      case 0: // NEW
        return 'Draft';
      case 1: // SEND_TO_STOREKEEPER
        if (userType == 3 || (userType == 1 && order.orderSalesmanId == userId)) {
          return order.orderStockKeeperId == -1
              ? 'Order Sent to storekeeper'
              : 'Storekeeper checking';
        } else {
          if (order.orderStockKeeperId == -1 || order.orderStockKeeperId == userId) {
            return 'Pending';
          } else {
            return 'Checking';
          }
        }
      case 2: // VERIFIED_BY_STOREKEEPER
        switch (userType) {
          case 1:
            return 'Verified by Storekeeper';
          case 2:
            return 'Checked';
          case 3:
            return 'Verified by Storekeeper';
          default:
            return 'Pending';
        }
      case 3: // COMPLETED
        return 'Order Completed';
      case 4: // REJECTED
        return 'Order Rejected';
      case 5: // CANCELLED
        return 'Order Cancelled';
      case 6: // SEND_TO_CHECKER
        switch (userType){
          case 5:
            return 'Pending';
          case 3:
            return 'Send to Biller and Checker';
          case 6:
            return 'Pending';
          default:
            return 'Pending in Checker';
        }
        // if (userType == 5) {
        //   return 'Pending';
        // } else {
        //   return 'Pending in Checker';
        // }
      case 7: // CHECKER_IS_CHECKING
        switch (userType){
          case 5:
          return 'Pending';
          case 6:
          if(order.orderCheckerId == userId){
            return 'Waiting for your submission';
          }else{
            return 'Pending in Checker';
          }
          default:
          return 'Checker is checking';
        }
        // if (userType == 5) {
        //   return 'Pending';
        
        // } else {
        //   return 'Checker is checking';
        // }
      default:
        return 'Error 404';
    }
  }

  Color _getStatusColor(Order order, int userType, int userId) {
    if (order.orderFlag != 1) {
      return Colors.red;
    }

    switch (order.orderApproveFlag) {
      case 0: // NEW
        return Colors.red;
      case 1: // SEND_TO_STOREKEEPER
        if (userType == 3 || (userType == 1 && order.orderSalesmanId == userId)) {
          return Colors.red;
        } else {
          if (order.orderStockKeeperId == -1 || order.orderStockKeeperId == userId) {
            return Colors.red;
          } else {
            return Colors.orange;
          }
        }
      case 2: // VERIFIED_BY_STOREKEEPER
        if (userType == 1 || userType == 2 || userType == 3) {
          return Colors.green.shade700;
        } else {
          return Colors.red;
        }
      case 3: // COMPLETED
        return Colors.green.shade700;
      case 4: // REJECTED
        return Colors.red;
      case 5: // CANCELLED
        return Colors.red;
      case 6: // SEND_TO_CHECKER
        if (userType == 5) {
          return Colors.red;
        } else {
          return Colors.orange;
        }
      case 7: // CHECKER_IS_CHECKING
        if (userType == 5) {
          return Colors.red;
        } else {
          return Colors.orange;
        }
      default:
        return Colors.red;
    }
  }

  String _formatDate(String dateTime) {
    if (dateTime.isEmpty) return '';
    try {
      final date = DateTime.parse(dateTime);
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return dateTime;
    }
  }
}

/// Route Filter Bottom Sheet
class _RouteFilterBottomSheet extends StatelessWidget {
  final List<dynamic> routeList;
  final int selectedRouteId;
  final Function(int routeId, String routeName) onRouteSelected;

  const _RouteFilterBottomSheet({
    required this.routeList,
    required this.selectedRouteId,
    required this.onRouteSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('All Routes'),
            leading: Radio<int>(
              value: -1,
              groupValue: selectedRouteId,
              onChanged: (value) {
                onRouteSelected(-1, 'All Routes');
              },
            ),
            onTap: () => onRouteSelected(-1, 'All Routes'),
          ),
          ...routeList.map((route) {
            final routeId = route.routeId ?? -1;
            final routeName = route.name;
            return ListTile(
              title: Text(routeName),
              leading: Radio<int>(
                value: routeId,
                groupValue: selectedRouteId,
                onChanged: (value) {
                  onRouteSelected(routeId, routeName);
                },
              ),
              onTap: () => onRouteSelected(routeId, routeName),
            );
          }),
        ],
      ),
    );
  }
}

/// Date Filter Bottom Sheet
class _DateFilterBottomSheet extends StatelessWidget {
  final int selectedDateIndex;
  final String selectedDate;
  final Function(int index, String date) onDateSelected;

  const _DateFilterBottomSheet({
    required this.selectedDateIndex,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    const dateFilterList = ['All', 'Today', 'Yesterday', 'Custom'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...dateFilterList.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          return ListTile(
            title: Text(label),
            leading: Radio<int>(
              value: index,
              groupValue: selectedDateIndex,
              onChanged: (value) {
                String date = '';
                if (index == 1) {
                  // Today
                  date = DateFormat('yyyy-MM-dd').format(DateTime.now());
                } else if (index == 2) {
                  // Yesterday
                  date = DateFormat('yyyy-MM-dd')
                      .format(DateTime.now().subtract(const Duration(days: 1)));
                } else if (index == 3) {
                  // Custom - show date picker
                  _showDatePicker(context);
                  return;
                }
                onDateSelected(index, date);
              },
            ),
            onTap: () {
              String date = '';
              if (index == 1) {
                date = DateFormat('yyyy-MM-dd').format(DateTime.now());
              } else if (index == 2) {
                date = DateFormat('yyyy-MM-dd')
                    .format(DateTime.now().subtract(const Duration(days: 1)));
              } else if (index == 3) {
                _showDatePicker(context);
                return;
              }
              onDateSelected(index, date);
            },
          );
        }),
      ],
    );
  }

  void _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isNotEmpty
          ? (DateTime.tryParse(selectedDate) ?? DateTime.now())
          : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      final date = DateFormat('yyyy-MM-dd').format(picked);
      onDateSelected(3, date);
    }
  }
}

