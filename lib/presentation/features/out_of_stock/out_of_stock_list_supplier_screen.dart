import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:schedule_frontend_flutter/presentation/common_widgets/sync_refresh_button.dart';
import '../../provider/out_of_stock_provider.dart';
import '../../../models/master_data_api.dart';
import '../../../utils/storage_helper.dart';
import '../../../utils/notification_manager.dart';
import 'package:schedule_frontend_flutter/presentation/features/home/home_drawer.dart';
import 'out_of_stock_details_supplier_screen.dart';

/// OutOfStock List Supplier Screen
/// Displays list of out of stock items for a specific supplier
/// Converted from KMP's OutOfStockListSupplierScreen.kt
class OutOfStockListSupplierScreen extends StatefulWidget {
  final int userId; // Supplier userId

  const OutOfStockListSupplierScreen({
    super.key,
    required this.userId,
  });

  @override
  State<OutOfStockListSupplierScreen> createState() =>
      _OutOfStockListSupplierScreenState();
}

class _OutOfStockListSupplierScreenState
    extends State<OutOfStockListSupplierScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;
  int _userType = 0;
  String _dateSt = 'Today';
  int _statusFilterIndex = 0; // 0=All, 1=Packed, 2=Confirmed, 3=Pending, 4=Not Initialized, 5=Cancelled
  String _statusSt = 'All';

  final List<String> _dateFilterList = const ['All', 'Today', 'Yesterday', 'Custom'];
  static const List<String> _statusFilterList = [
    'All',
    'Packed',
    'Confirmed',
    'Pending',
    'Not Initialized',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<OutOfStockProvider>(context, listen: false);
      provider.dateFilterIndex = 1; // Today
      provider.date = _getDBFormatDate();
      provider.getAllOospSub(
        supplierId: widget.userId,
        searchKey: '',
        date: provider.date,
      );
    });
  }

  Future<void> _loadUserData() async {
    final userType = await StorageHelper.getUserType();
    setState(() {
      _userType = userType;
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
      // Try parsing as full datetime first
      final formats = [
        DateFormat('yyyy-MM-dd HH:mm:ss'),
        DateFormat('yyyy-MM-dd'),
      ];
      for (final format in formats) {
        try {
          final date = format.parse(dateStr);
          return DateFormat('dd MMM yyyy').format(date);
        } catch (_) {
          // Continue to next format
        }
      }
      return dateStr;
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
    provider.getAllOospSub(
      supplierId: widget.userId,
      searchKey: provider.searchKey,
      date: newDate,
    );
    
    setState(() {
      _dateSt = index == 3 ? provider.date : _dateFilterList[index];
    });
  }

  /// Filters oospSubList by selected status (client-side)
  List<OutOfStockSubWithDetails> _filterListByStatus(
    List<OutOfStockSubWithDetails> list,
  ) {
    if (_statusFilterIndex == 0) return list;
    switch (_statusFilterIndex) {
      case 1: // Packed
        return list.where((item) => item.isPacked == 1).toList();
      case 2: // Confirmed
        return list.where((item) => item.oospFlag == 2).toList();
      case 3: // Pending
        return list.where((item) => item.oospFlag == 1).toList();
      case 4: // Not Initialized
        return list.where((item) => item.oospFlag == 0).toList();
      case 5: // Cancelled
        return list.where((item) {
          if (item.oospFlag == 5) return true;
          if (item.oospFlag == 3 && item.availQty <= 0) return true;
          return false;
        }).toList();
      default:
        return list;
    }
  }

  void _handleStatusFilter(int index) {
    setState(() {
      _statusFilterIndex = index;
      _statusSt = _statusFilterList[index];
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
      provider.getAllOospSub(
        supplierId: widget.userId,
        searchKey: provider.searchKey,
        date: dateStr,
      );
      
      setState(() {
        _dateSt = _toReadableDate(dateStr);
      });
    }
  }

  /// Shows a dialog with estimate in bill format: only packed items, product list with qty and grand total
  Future<void> _showEstimate() async {
    final provider = Provider.of<OutOfStockProvider>(context, listen: false);
    // Refresh list so isPacked is up to date from DB (PackedSubs join)
    await provider.getAllOospSub(
      supplierId: widget.userId,
      searchKey: provider.searchKey,
      date: provider.date,
    );
    if (!mounted) return;
    // Only include items marked as packed (isPacked == 1)
    final packedItems = provider.oospSubList
        .where((item) => item.isPacked == 1)
        .toList();
    final grandTotal = packedItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.updateRate * item.qty),
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Packed Items Estimate',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: packedItems.isEmpty
                  ? const Center(
                      child: Text(
                        'No packed products',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Bill header row
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Product',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  'Qty',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 72,
                                child: Text(
                                  'Amount',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          // Product rows
                          ...packedItems.map((item) {
                            final lineAmount = item.updateRate * item.qty;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      item.productName.isNotEmpty
                                          ? item.productName
                                          : '—',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 56,
                                    child: Text(
                                      item.qty.toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 72,
                                    child: Text(
                                      '₹ ${lineAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 20),
                          // Grand total row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text(
                                'Grand Total: ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '₹ ${grandTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OutOfStockProvider>(context);
    final isStorekeeper = _userType == 2;

    return Consumer<NotificationManager>(
      builder: (context, notificationManager, _) {
        if (notificationManager.notificationTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final provider = Provider.of<OutOfStockProvider>(context, listen: false);
            provider.getAllOospSub(
              supplierId: widget.userId,
              searchKey: provider.searchKey,
              date: provider.date,
            );
            notificationManager.resetTrigger();
          });
        }

        return Scaffold(
          drawer: const HomeDrawer(), // Add drawer for suppliers
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
                      provider.getAllOospSub(
                        supplierId: widget.userId,
                        searchKey: value,
                        date: provider.date,
                      );
                    },
                  )
                : Text(isStorekeeper ? 'Out of Stock' : 'Orders'),
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(_showSearchBar ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _showSearchBar = !_showSearchBar;
                    if (!_showSearchBar) {
                      _searchController.clear();
                      provider.searchKey = '';
                      provider.getAllOospSub(
                        supplierId: widget.userId,
                        searchKey: '',
                        date: provider.date,
                      );
                    }
                  });
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showEstimate,
            icon: const Icon(Icons.assessment),
            label: const Text('Get Estimate'),
          ),
          body: Column(
            children: [
              // Sync refresh button (for supplier who doesn't have HomeScreen)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: SyncRefreshButton(),
              ),
              // Date and status filter row
              Row(
                children: [
                  Expanded(
                    child: Card(
                      margin: const EdgeInsets.all(8.0),
                      child: InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) =>
                                _buildDateFilterBottomSheet(provider),
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
                  ),
                  Expanded(
                    child: Card(
                      margin: const EdgeInsets.all(8.0),
                      child: InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) =>
                                _buildStatusFilterBottomSheet(),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _statusSt,
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
                  ),
                ],
              ),
              // List
              Expanded(
                child: Consumer<OutOfStockProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading && provider.oospSubList.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (provider.errorMessage != null && provider.oospSubList.isEmpty) {
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
                              onPressed: () => provider.getAllOospSub(
                                supplierId: widget.userId,
                                searchKey: provider.searchKey,
                                date: provider.date,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final filteredList =
                        _filterListByStatus(provider.oospSubList);

                    if (filteredList.isEmpty) {
                      return Center(
                        child: Text(
                          provider.oospSubList.isEmpty
                              ? 'No orders'
                              : 'No orders match "$_statusSt" filter',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final item = filteredList[index];
                        return _OutOfStockSupplierListItem(
                          item: item,
                          userType: _userType,
                          onTap: () {
                             
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OutOfStockDetailsSupplierScreen(
                                  oospId: item.oospId,
                                ),
                              ),
                            ).then((_){
                               // Refresh list when returning
  final provider = Provider.of<OutOfStockProvider>(context, listen: false);
  provider.getAllOospSub(
    supplierId: widget.userId,
    searchKey: provider.searchKey,
    date: provider.date,
  );
                            });
                          },
                          onPackedChanged: (isPacked) {
                            if (isPacked) {
                              provider.addPackedSub(item.oospId, item.qty);
                            } else {
                              provider.deletePackedSub(item.oospId);
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
        );
      },
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

  Widget _buildStatusFilterBottomSheet() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _statusFilterList.length,
      itemBuilder: (context, index) {
        final selected = _statusFilterIndex == index;
        return ListTile(
          title: Text(_statusFilterList[index]),
          trailing: selected ? const Icon(Icons.check) : null,
          onTap: () {
            Navigator.pop(context);
            _handleStatusFilter(index);
          },
        );
      },
    );
  }
}

class _OutOfStockSupplierListItem extends StatefulWidget {
  final OutOfStockSubWithDetails item;
  final int userType;
  final VoidCallback onTap;
  final ValueChanged<bool> onPackedChanged;

  const _OutOfStockSupplierListItem({
    required this.item,
    required this.userType,
    required this.onTap,
    required this.onPackedChanged,
  });

  @override
  State<_OutOfStockSupplierListItem> createState() =>
      _OutOfStockSupplierListItemState();
}

class _OutOfStockSupplierListItemState
    extends State<_OutOfStockSupplierListItem> {
  late bool _isPacked;

  @override
  void initState() {
    super.initState();
    _isPacked = widget.item.isPacked == 1;
  }

  @override
  void didUpdateWidget(_OutOfStockSupplierListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.oospId != widget.item.oospId ||
        oldWidget.item.isPacked != widget.item.isPacked) {
      _isPacked = widget.item.isPacked == 1;
    }
  }

  String _toReadableDate(String dateStr) {
    try {
      final formats = [
        DateFormat('yyyy-MM-dd HH:mm:ss'),
        DateFormat('yyyy-MM-dd'),
      ];
      for (final format in formats) {
        try {
          final date = format.parse(dateStr);
          return DateFormat('dd MMM yyyy').format(date);
        } catch (_) {
          // Continue
        }
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  String _getStatusText() {
    if (widget.userType == 4) {
      // Supplier
      if (widget.item.isCheckedflag == 1) {
        switch (widget.item.oospFlag) {
          case 0:
            return 'Not Initialized';
          case 1:
            return 'Pending';
          case 2:
            return 'Confirmed';
          case 3:
            if (widget.item.availQty > 0) {
              return 'Only ${widget.item.availQty.toInt()} is left (Waiting for response)';
            } else {
              return 'Cancelled';
            }
          case 5:
            return 'Order Cancelled';
          default:
            return 'Cancelled';
        }
      } else {
        return 'Not Checked';
      }
    } else {
      // Storekeeper or other users
      switch (widget.item.oospFlag) {
        case 0:
          return 'Pending in Admin';
        case 1:
          return 'Waiting for response from supplier';
        case 2:
          return 'Available';
        case 3:
          if (widget.item.availQty > 0) {
            return 'Only ${widget.item.availQty.toInt()} is left';
          } else {
            return 'Out of Stock';
          }
        case 5:
          return 'Order Cancelled';
        default:
          return 'Not Available';
      }
    }
  }

  Color _getStatusColor() {
    if (widget.userType == 4) {
      // Supplier
      if (widget.item.isCheckedflag == 1) {
        switch (widget.item.oospFlag) {
          case 2:
            return Colors.green.shade700;
          case 0:
          case 1:
          case 3:
          case 5:
          default:
            return Colors.red;
        }
      } else {
        return Colors.red;
      }
    } else {
      // Storekeeper or other users
      switch (widget.item.oospFlag) {
        case 2:
          return Colors.green.shade700;
        case 1:
          return Colors.orange.shade700;
        case 0:
        case 3:
        case 5:
        default:
          return Colors.red;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.item.isViewed == 0;
    final statusText = _getStatusText();
    final statusColor = _getStatusColor();
    final showPacking = widget.userType == 4 && 
        widget.item.isCheckedflag == 1 && 
        widget.item.oospFlag == 2;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 4.0,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.oospMasterId.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    _toReadableDate(widget.item.updatedDateTime),
                    style: TextStyle(
                      fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                widget.item.productName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (widget.userType == 2 && widget.item.supplierId != -1) ...[
                const SizedBox(height: 4),
                Text(
                  'Supplier : ${widget.item.supplierName}',
                  style: TextStyle(
                    fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
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
                      fontSize: 12,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                        color: statusColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    'Qty:',
                    style: TextStyle(
                      fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    widget.item.qty.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              if (showPacking) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilterChip(
                      selected: _isPacked,
                      onSelected: (selected) {
                        setState(() {
                          _isPacked = selected;
                        });
                        widget.onPackedChanged(selected);
                      },
                      label: Text(
                        _isPacked ? 'Packed' : 'Mark as Packed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isPacked 
                              ? Colors.green.shade700 
                              : Colors.blue,
                        ),
                      ),
                      avatar: _isPacked
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.green.shade700,
                            )
                          : Icon(
                              Icons.shopping_cart,
                              size: 16,
                              color: Colors.blue,
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
}

