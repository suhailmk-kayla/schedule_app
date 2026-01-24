import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:schedule_frontend_flutter/presentation/features/home/home_drawer.dart';
import 'package:schedule_frontend_flutter/utils/notification_manager.dart';
import '../../provider/out_of_stock_provider.dart';
import '../../provider/home_provider.dart';
import '../../../models/master_data_api.dart';
import '../../../utils/storage_helper.dart';
import 'out_of_stock_details_admin_screen.dart';
import 'out_of_stock_details_supplier_screen.dart';

/// OutOfStock List Screen
/// Displays list of out of stock items with search and date filter
/// Converted from KMP's OutOfStockListScreen.kt
class OutOfStockListScreen extends StatefulWidget {
  const OutOfStockListScreen({super.key});

  @override
  State<OutOfStockListScreen> createState() => _OutOfStockListScreenState();
}

class _OutOfStockListScreenState extends State<OutOfStockListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;
  int _userType = 0;
  int _userId = 0;
  String _dateSt = 'Today';

  final List<String> _dateFilterList = const ['All', 'Today', 'Yesterday', 'Custom'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<OutOfStockProvider>(context, listen: false);
      provider.getAllOosp();
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

  String _getDBFormatDate() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  String _getYesterdayDBFormatDate() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
  }

  String _toReadableDate(String dateStr) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _handleDateFilter(int index) {
    final provider = Provider.of<OutOfStockProvider>(context, listen: false);
    String newDate = '';
    
    switch (index) {
      case 0: // All
        newDate = '';
        break;
      case 1: // Today
        newDate = _getDBFormatDate();
        break;
      case 2: // Yesterday
        newDate = _getYesterdayDBFormatDate();
        break;
      case 3: // Custom
        _showCustomDatePicker();
        return;
    }

    provider.dateFilterIndex = index;
    provider.date = newDate;
    provider.getAllOosp();
    
    setState(() {
      _dateSt = index == 3 ? provider.date : _dateFilterList[index];
    });
  }

  Future<void> _showCustomDatePicker() async {
    final provider = Provider.of<OutOfStockProvider>(context, listen: false);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selectedDate != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      
      provider.dateFilterIndex = 3;
      provider.date = dateStr;
      provider.getAllOosp();
      
      setState(() {
        _dateSt = _toReadableDate(dateStr);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OutOfStockProvider>(context);
    final isMenuIcon = _userType == 4; // Admin

    return Consumer<NotificationManager>(
      builder: (context, notificationManager, _) {
        if (notificationManager.notificationTrigger) {
          developer.log('OutOfStockListScreen: notificationTrigger: true');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final provider = Provider.of<OutOfStockProvider>(context, listen: false);
            provider.getAllOosp(searchKey: provider.searchKey, date: provider.date);
            notificationManager.resetTrigger();
          });
        }
        return Scaffold(
          drawer: _userType == 4 ? HomeDrawer() : null,
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
                      provider.searchKey = value;
                      provider.getAllOosp();
                    },
                  )
                :  Text(
                  _userType == 4 ? 'Orders' : 'Out of stocks',
                ),
            // leading: IconButton(
            //   icon: Icon(isMenuIcon ? Icons.menu : Icons.arrow_back),
            //   onPressed: () {
            //     if (isMenuIcon) {
                  
            //     } else {
            //       Navigator.of(context).pop();
            //     }
            //   },
            // ),
            actions: [
              IconButton(
                icon: Icon(_showSearchBar ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _showSearchBar = !_showSearchBar;
                    if (!_showSearchBar) {
                      _searchController.clear();
                      provider.searchKey = '';
                      provider.getAllOosp();
                    }
                  });
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              provider.getAllOosp();
            },
            child: Column(
              children: [
                // Date filter card
                Card(
                  margin: const EdgeInsets.all(8.0),
                  child: InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => _buildDateFilterBottomSheet(provider),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _dateSt,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // List
                Expanded(
                  child: Consumer<OutOfStockProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading && provider.oospList.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                    
                      if (provider.errorMessage != null && provider.oospList.isEmpty) {
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
                                onPressed: () => provider.getAllOosp(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }
                    
                      if (provider.oospList.isEmpty) {
                        final noText = _userType == 1 ? 'No products found' : 'No orders';
                        return Center(
                          child: Text(
                            noText,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }
                    
                      return ListView.builder(
                        itemCount: provider.oospList.length,
                        itemBuilder: (context, index) {
                          final item = provider.oospList[index];
                          return _OutOfStockListItem(
                            item: item,
                            userType: _userType,
                            userId: _userId,
                            onTap: () {
                              // Navigate to details screen based on user type
                              if (_userType == 1) {
                                // Admin
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OutOfStockDetailsAdminScreen(
                                      oospMasterId: item.oospMasterId,
                                    ),
                                  ),
                                ).then((_) {
                                  // Refresh badge counts when returning from detail screen
                                  // This ensures badge count updates after viewing an item
                                  final homeProvider = Provider.of<HomeProvider>(context, listen: false);
                                  homeProvider.refreshCounts();
                                });
                              } else if (_userType == 4) {
                                Navigator.push(context, 
                                MaterialPageRoute(builder: (_)=>OutOfStockDetailsSupplierScreen(oospId: item.oospMasterId)
                                )
                                );
                                // Supplier - need to get the sub ID from the master
                                // For supplier, we need to find the sub item for this supplier
                                // This will be handled differently - supplier sees their own list
                                // For now, navigate to supplier screen with master's first sub
                                // TODO: Implement supplier-specific navigation
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              // TODO: Navigate to add out of stock (products screen)
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (_) => const ProductsScreen(isOutOfStock: true),
              //   ),
              // );
            },
            backgroundColor: Colors.black,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      }
    );
  }

  Widget _buildDateFilterBottomSheet(OutOfStockProvider provider) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _dateFilterList.length,
      itemBuilder: (context, index) {
        final selected = provider.dateFilterIndex == index;
        return ListTile(
          title: Text(_dateFilterList[index]),
          trailing: selected ? const Icon(Icons.check) : null,
          onTap: () {
            Navigator.pop(context);
            _handleDateFilter(index);
          },
        );
      },
    );
  }
}

class _OutOfStockListItem extends StatelessWidget {
  final OutOfStockMasterWithDetails item;
  final int userType;
  final int userId;
  final VoidCallback onTap;

  const _OutOfStockListItem({
    required this.item,
    required this.userType,
    required this.userId,
    required this.onTap,
  });

  String _toReadableDate(String dateStr) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = item.isViewed == 0;
    final isComplete = item.isCompleteflag == 1;
    final isCancelled = item.isCompleteflag == 5;

    Color statusColor;
    String status;
    
    if (isComplete) {
      statusColor = Colors.green.shade700;
      status = 'Completed';
    } else if (isCancelled) {
      statusColor = Colors.red;
      status = 'Cancelled';
    } else {
      if (item.supplier.isNotEmpty) {
        statusColor = Colors.orange.shade700;
        status = 'Waiting for response from ${item.supplier}';
      } else {
        statusColor = Colors.red;
        status = 'Pending';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 4.0,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.oospMasterId.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    _toReadableDate(item.updatedDateTime),
                    style: TextStyle(
                      fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                item.productName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (userType == 1 && item.custId != -1) ...[
                const SizedBox(height: 4),
                Text(
                  'customer: ${item.customerName}',
                  style: TextStyle(
                    fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
              if (userType == 1 && item.salesmanId != -1) ...[
                const SizedBox(height: 4),
                Text(
                  'Salesman: ${userId == item.salesmanId ? item.salesman + "(SELF ORDER)" : item.salesman}',
                  style: TextStyle(
                    fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
              if (userType == 1 && item.salesmanId == -1 && item.custId == -1 && item.storekeeperId != -1) ...[
                const SizedBox(height: 4),
                Text(
                  'Storekeeper: ${item.storekeeper}',
                  style: TextStyle(
                    fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Status: ',
                    style: TextStyle(
                      fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      status,
                      style: TextStyle(
                        fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                        color: statusColor,
                      ),
                    ),
                  ),
                  Text(
                    'Qty:',
                    style: TextStyle(
                      fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                      color: Colors.black,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    item.qty.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

