import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get_it/get_it.dart';
import '../../provider/out_of_stock_provider.dart';
import '../../provider/products_provider.dart';
import '../../../repositories/users/users_repository.dart';
import '../../../models/master_data_api.dart';
import '../../../models/product_api.dart';
import '../../../utils/toast_helper.dart';
import '../../../utils/notification_manager.dart';

/// OutOfStock Details Admin Screen
/// Shows product details and allows admin to select/change supplier and handle availability
/// Converted from KMP's OutOfStockDetailsAdminScreen.kt
class OutOfStockDetailsAdminScreen extends StatefulWidget {
  final int oospMasterId;

  const OutOfStockDetailsAdminScreen({
    super.key,
    required this.oospMasterId,
  });

  @override
  State<OutOfStockDetailsAdminScreen> createState() =>
      _OutOfStockDetailsAdminScreenState();
}

class _OutOfStockDetailsAdminScreenState
    extends State<OutOfStockDetailsAdminScreen> {
  OutOfStockMasterWithDetails? _masterWithDetails;
  bool _isLoading = false;
  String? _errorMessage;
  int? _selectedSupplierId;
  OutOfStockSubWithDetails? _selectedSubItem;
  String _confirmMessage = '';
  int _confirmDialogFlag = 1; // 1=accept, 2=reject, 3=not available

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _loadSuppliers();
    });
  }

  void _loadData() async {
    final provider = Provider.of<OutOfStockProvider>(context, listen: false);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Get master details
    final master = await provider.getOopsMaster(widget.oospMasterId);
    if (master == null) {
      setState(() {
        _errorMessage = 'Out of stock item not found';
        _isLoading = false;
      });
      return;
    }

    // Mark as viewed if not already
    if (master.isViewed == 0) {
      await provider.updateIsMasterViewedFlag(
        oospMasterId: widget.oospMasterId,
        isViewed: 1,
      );
    }

    // Load subs
    await provider.getOopsSub(widget.oospMasterId);

    // Load product details
    final productsProvider =
        Provider.of<ProductsProvider>(context, listen: false);
    await productsProvider.loadProductByIdWithDetails(master.productId);
    await productsProvider.loadProductCars(master.productId);

    setState(() {
      _masterWithDetails = master;
      _isLoading = false;
    });
  }

  void _loadSuppliers() async {
    // Suppliers will be loaded when dialog is shown
    // No need to pre-load here
  }

  void _handleSelectSupplier(OutOfStockSubWithDetails subItem) {
    setState(() {
      _selectedSubItem = subItem;
      _selectedSupplierId = null;
    });
    _showSupplierDialog();
  }

  void _showSupplierDialog() {
    showDialog(
      context: context,
      builder: (_) => _buildSupplierDialog(),
    ).then((_) {
      setState(() {
        _selectedSupplierId = null;
        _selectedSubItem = null;
      });
    });
  }

  void _handleSendToSupplier(OutOfStockSubWithDetails subItem) {
    final provider = Provider.of<OutOfStockProvider>(context, listen: false);
    setState(() => _isLoading = true);

    provider.sendOrderToSupplier(
      subItem: subItem,
      onFailure: (error) {
        setState(() => _isLoading = false);
        ToastHelper.showError(error);
      },
      onSuccess: () {
        setState(() => _isLoading = false);
        ToastHelper.showInfo('Order sent to supplier');
        _loadData(); // Reload to refresh status
      },
    );
  }

  void _handleAcceptAvailable(OutOfStockSubWithDetails subItem) {
    setState(() {
      _selectedSubItem = subItem;
      _confirmDialogFlag = 1;
      _confirmMessage =
          'Do you want to ACCEPT the available quantity ${subItem.availQty.toInt()} ${subItem.unitDispName}?';
    });
    _showConfirmDialog();
  }

  void _handleRejectAvailable(OutOfStockSubWithDetails subItem) {
    setState(() {
      _selectedSubItem = subItem;
      _confirmDialogFlag = 2;
      _confirmMessage =
          'Do you want to REJECT the available quantity ${subItem.availQty.toInt()} ${subItem.unitDispName}?';
    });
    _showConfirmDialog();
  }

  void _handleNotAvailable(OutOfStockSubWithDetails subItem) {
    setState(() {
      _selectedSubItem = subItem;
      _confirmDialogFlag = 3;
      _confirmMessage = 'Do you want to mark it as NOT AVAILABLE?';
    });
    _showConfirmDialog();
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (_) => _buildConfirmDialog(),
    ).then((_) {
      setState(() {
        _confirmMessage = '';
        _selectedSubItem = null;
      });
    });
  }

  void _confirmAction() {
    if (_selectedSubItem == null) return;

    final provider = Provider.of<OutOfStockProvider>(context, listen: false);
    setState(() => _isLoading = true);

    switch (_confirmDialogFlag) {
      case 1: // Accept
        provider.acceptAvailableQty(
          subItem: _selectedSubItem!,
          note: '',
          onFailure: (error) {
            setState(() => _isLoading = false);
            ToastHelper.showError(error);
          },
          onSuccess: () {
            setState(() {
              _isLoading = false;
            });
            ToastHelper.showInfo('Available quantity accepted');
            _loadData();
          },
        );
        break;

      case 2: // Reject
        provider.rejectAvailableQty(
          subItem: _selectedSubItem!,
          note: '',
          onFailure: (error) {
            setState(() => _isLoading = false);
            ToastHelper.showError(error);
          },
          onSuccess: () {
            setState(() {
              _isLoading = false;
            });
            ToastHelper.showInfo('Available quantity rejected');
            _loadData();
          },
        );
        break;

      case 3: // Not Available
        // Match KMP behavior: if orderSubId != -1, use notAvailable + informSalesman
        // If orderSubId == -1, use notAvailableQty (full API workflow)
        if (_selectedSubItem!.orderSubId != -1) {
          // Has order sub: use notAvailable (calls API), then informSalesman
          provider.notAvailable(
            oospId: _selectedSubItem!.oospId,
            masterId: _selectedSubItem!.oospMasterId,
            subItem: _selectedSubItem!,
            onFailure: (error) {
              setState(() => _isLoading = false);
              ToastHelper.showError(error);
            },
            onSuccess: () async {
              // After marking as not available, inform salesman
              // This reads from local DB (now synced with server) and updates ORDER SUB
              if (_masterWithDetails != null) {
                // Calculate available qty from subs with flag 2 (available)
                double availableQty = 0.0;
                for (final sub in provider.oospSubList) {
                  if (sub.oospFlag == 2) {
                    availableQty += sub.qty;
                  }
                }

                provider.informSalesman(
                  master: _masterWithDetails!,
                  availableQty: availableQty,
                  onFailure: (error) {
                    setState(() => _isLoading = false);
                    ToastHelper.showError(error);
                  },
                  onSuccess: () {
                    setState(() {
                      _isLoading = false;
                    });
                    ToastHelper.showInfo('Informed successfully');
                    _loadData();
                  },
                );
              } else {
                setState(() {
                  _isLoading = false;
                });
                ToastHelper.showInfo('Marked as not available');
                _loadData();
              }
            },
          );
        } else {
          // No order sub: use notAvailableQty (full API workflow)
          provider.notAvailableQty(
            subItem: _selectedSubItem!,
            note: '',
            onFailure: (error) {
              setState(() => _isLoading = false);
              ToastHelper.showError(error);
            },
            onSuccess: () {
              setState(() {
                _isLoading = false;
                _selectedSubItem = null;
              });
              ToastHelper.showInfo('Informed successfully');
              _loadData();
            },
          );
        }
        break;
    }
  }

  void _handleSupplierSelected(int supplierId) {
    if (_selectedSubItem == null) return;

    final provider = Provider.of<OutOfStockProvider>(context, listen: false);
    setState(() => _isLoading = true);

     provider.updateSupplier(
      oospId: _selectedSubItem!.oospId,
      supplierId: supplierId,
    ).then((success) {
      setState(() {
        _isLoading = false;
        _selectedSubItem = null;
        _selectedSupplierId = null;
      });

      if (success) {
        Navigator.of(context).pop(); // Close dialog
        ToastHelper.showInfo('Supplier updated');
        _loadData();
      } else {
        ToastHelper.showError(provider.errorMessage ?? 'Failed to update supplier');
      }
    });
  }

  void _handleComplete(OutOfStockProvider provider) {
    if (_masterWithDetails == null) return;

    setState(() => _isLoading = true);

    // Calculate available qty from all subs with flag 2 (Available)
    double availableQty = 0.0;
    for (final sub in provider.oospSubList) {
      if (sub.oospFlag == 2) {
        availableQty += sub.qty;
      }
    }

    if (_masterWithDetails!.orderSubId != -1) {
      // Inform salesman
      provider.informSalesman(
        master: _masterWithDetails!,
        availableQty: availableQty,
        onFailure: (error) {
          setState(() => _isLoading = false);
          ToastHelper.showError(error);
        },
        onSuccess: () {
          setState(() => _isLoading = false);
          ToastHelper.showInfo('Salesman informed');
          Navigator.of(context).pop();
        },
      );
    } else {
      // Update complete flag and inform
      provider.updateCompleteFlagAndInform(
        master: _masterWithDetails!,
        onFailure: (error) {
          setState(() => _isLoading = false);
          ToastHelper.showError(error);
        },
        onSuccess: () {
          setState(() => _isLoading = false);
          ToastHelper.showInfo('Completed');
          Navigator.of(context).pop();
        },
      );
    }
  }

  bool _isAllSubsFinished(OutOfStockProvider provider) {
    for (final sub in provider.oospSubList) {
      if (sub.oospFlag == 0 || sub.oospFlag == 1 || sub.oospFlag == 3) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<OutOfStockProvider, ProductsProvider, NotificationManager>(
      builder: (context, oospProvider, productsProvider, notificationManager, _) {
        // Listen to notification triggers
        if (notificationManager.notificationTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadData();
            notificationManager.resetTrigger();
          });
        }

        if (_isLoading && _masterWithDetails == null) {
          return Scaffold(
            appBar: AppBar(title: Text('Out of Stocks')),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_errorMessage != null && _masterWithDetails == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Out of Stocks')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (_masterWithDetails == null) {
          return  Scaffold(
            appBar: AppBar(title: Text('Out of Stocks')),
            body: Center(child: Text('Not found')),
          );
        }

        final productWithDetails = productsProvider.currentProductWithDetails;
        final isAllFinished = _isAllSubsFinished(oospProvider);
        final isCompleted = _masterWithDetails!.isCompleteflag == 1;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Out of Stocks'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image
                      _buildProductImage(productWithDetails),
                      const SizedBox(height: 16),

                      // Product Details Card
                      _buildProductDetailsCard(productWithDetails),
                      const SizedBox(height: 16),

                      // Compatible Cars
                      // _buildCompatibleCars(productsProvider),
                      const SizedBox(height: 16),

                      // Sub Items List
                      ...oospProvider.oospSubList.map((subItem) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _SubItemCard(
                              subItem: subItem,
                              onSelectSupplier: () => _handleSelectSupplier(subItem),
                              onSendToSupplier: () => _handleSendToSupplier(subItem),
                              onAcceptAvailable: () => _handleAcceptAvailable(subItem),
                              onRejectAvailable: () => _handleRejectAvailable(subItem),
                              onNotAvailable: () => _handleNotAvailable(subItem),
                            ),
                          )),
                      const SizedBox(height: 80), // Space for bottom button
                    ],
                  ),
                ),
          bottomNavigationBar: isAllFinished && !isCompleted
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => _handleComplete(oospProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _masterWithDetails!.orderSubId != -1
                          ? 'Inform Salesman'
                          : _masterWithDetails!.storekeeperId != -1
                              ? 'Inform Storekeeper'
                              : 'Complete',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildProductImage(ProductWithDetails? productWithDetails) {
    final imageUrl = productWithDetails?.product.photo ?? '';
    return Center(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: imageUrl.isEmpty
            ? const Center(child: Text('No Image', style: TextStyle(color: Colors.grey)))
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Text('No Image', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProductDetailsCard(ProductWithDetails? productWithDetails) {
    if (productWithDetails == null) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Loading product...')));
    }

    final product = productWithDetails.product;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                product.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Code:', product.code),
            if (product.sub_name.isNotEmpty) _buildDetailRow('Sub Name:', product.sub_name),
            if (product.brand.isNotEmpty) _buildDetailRow('Brand:', product.brand),
            if (product.sub_brand.isNotEmpty) _buildDetailRow('Sub Brand:', product.sub_brand),
            if (productWithDetails.categoryName?.isNotEmpty ?? false)
              _buildDetailRow('Category:', productWithDetails.categoryName ?? ''),
            if (productWithDetails.subCategoryName?.isNotEmpty ?? false)
              _buildDetailRow('Sub-Category:', productWithDetails.subCategoryName ?? ''),
            if (productWithDetails.baseUnitName?.isNotEmpty ?? false)
              _buildDetailRow('Base Unit:', productWithDetails.baseUnitName ?? ''),
            _buildDetailRow('Price:', product.price.toStringAsFixed(2)),
            _buildDetailRow('MRP:', product.mrp.toStringAsFixed(2)),
            if (product.note.isNotEmpty) _buildDetailRow('Note:', product.note),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildCompatibleCars(ProductsProvider productsProvider) {
  //   final productCars = productsProvider.productCars;
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       const Text('Compatible cars', style: TextStyle(fontSize: 14)),
  //       const SizedBox(height: 8),
  //       Card(
  //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //         elevation: 4,
  //         child: Padding(
  //           padding: const EdgeInsets.all(12),
  //           child: productCars.isEmpty
  //               ? const Center(
  //                   child: Padding(
  //                     padding: EdgeInsets.all(8),
  //                     child: Text('All Cars Compatible', style: TextStyle(color: Colors.grey)),
  //                   ),
  //                 )
  //               : Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: _buildCarList(productCars),
  //                 ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  List<Widget> _buildCarList(Map<String, Map<String, Map<String, List<String>>>> cars) {
    final widgets = <Widget>[];
    cars.forEach((brand, nameMap) {
      nameMap.forEach((name, modelMap) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$brand $name',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...modelMap.entries.map((modelEntry) {
                  final model = modelEntry.key;
                  final versions = modelEntry.value;
                  final versionsText = versions.isEmpty
                      ? 'All Versions'
                      : versions.join(', ');
                  return Text(
                    '$model: $versionsText',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      });
    });
    return widgets;
  }

  // Supplier Selection Dialog
  Widget _buildSupplierDialog() {
    return FutureBuilder<List<User>>(
      future: _loadSuppliersList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AlertDialog(
            content: Center(child: CircularProgressIndicator()),
          );
        }

        final suppliers = snapshot.data ?? [];
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Supplier'),
              content: suppliers.isEmpty
                  ? const Text('No Supplier found')
                  : SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: suppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = suppliers[index];
                          final isSelected = _selectedSupplierId == supplier.userId;
                          return ListTile(
                            title: Text(supplier.name),
                            trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                            onTap: () {
                              setDialogState(() {
                                _selectedSupplierId = supplier.userId ?? -1;
                              });
                            },
                          );
                        },
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _selectedSupplierId != null && 
                             _selectedSupplierId! != -1 && 
                             _selectedSubItem != null
                      ? () => _handleSupplierSelected(_selectedSupplierId!)
                      : null,
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<User>> _loadSuppliersList() async {
    // Use repository directly to get suppliers (category 4)
    final usersRepository = GetIt.instance<UsersRepository>();
    final result = await usersRepository.getUsersByCategory(4);
    return result.fold(
      (_) => <User>[],
      (suppliers) => suppliers,
    );
  }

  // Confirm Dialog
  Widget _buildConfirmDialog() {
    return AlertDialog(
      title: const Text('Confirm'),
      content: Text(_confirmMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _confirmAction();
          },
          child: Text(
            _confirmDialogFlag == 1
                ? 'Accept'
                : _confirmDialogFlag == 2
                    ? 'Reject'
                    : 'Not Available',
          ),
        ),
      ],
    );
  }
}

class _SubItemCard extends StatelessWidget {
  final OutOfStockSubWithDetails subItem;
  final VoidCallback onSelectSupplier;
  final VoidCallback onSendToSupplier;
  final VoidCallback onAcceptAvailable;
  final VoidCallback onRejectAvailable;
  final VoidCallback onNotAvailable;

  const _SubItemCard({
    required this.subItem,
    required this.onSelectSupplier,
    required this.onSendToSupplier,
    required this.onAcceptAvailable,
    required this.onRejectAvailable,
    required this.onNotAvailable,
  });

  String _getStatusText() {
    switch (subItem.oospFlag) {
      case 0:
        return 'Not Initialized';
      case 1:
        return 'Waiting for response';
      case 2:
        return 'Available';
      case 3:
        return subItem.availQty > 0
            ? 'Only ${subItem.availQty.toInt()} is left'
            : 'Out of Stock';
      case 5:
        return 'Order Cancelled';
      default:
        return 'Not Available';
    }
  }

  Color _getStatusColor() {
    switch (subItem.oospFlag) {
      case 0:
      case 3:
      case 5:
        return Colors.red;
      case 1:
        return Colors.orange.shade700;
      case 2:
        return Colors.green.shade700;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canShowActions = subItem.oospFlag == 0 || subItem.oospFlag == 3;
    final supplierName = subItem.supplierName.isEmpty ? 'Not selected' : subItem.supplierName.toUpperCase();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Supplier
            Row(
              children: [
                const Text('Supplier:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    supplierName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                  ),
                ),
                if (subItem.supplierId != -1 && (subItem.oospFlag == 0 || subItem.oospFlag == 3))
                  TextButton(
                    onPressed: onSelectSupplier,
                    child: const Text('Change', style: TextStyle(color: Colors.green)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Quantity and Unit
            Row(
              children: [
                const Text('Quantity:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                Text(
                  subItem.qty.toString(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(width: 16),
                const Text('Unit:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                Text(
                  subItem.unitDispName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            // Note
            if (subItem.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Note:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subItem.note,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],

            // Status
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Status:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusText(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(),
                    ),
                  ),
                ),
              ],
            ),

            // Action Buttons
            if (canShowActions) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: subItem.oospFlag == 3 && subItem.availQty > 0
                          ? onRejectAvailable
                          : onNotAvailable,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: Text(
                        subItem.oospFlag == 3 && subItem.availQty > 0 ? 'Reject' : 'Not Available',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                           fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: subItem.supplierId == -1
                          ? onSelectSupplier
                          : subItem.oospFlag == 3
                              ? (subItem.availQty > 0 ? onAcceptAvailable : onSelectSupplier)
                              : onSendToSupplier,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                      child: Text(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        subItem.supplierId == -1
                            ? 'Select Supplier'
                            : subItem.oospFlag == 3
                                ? (subItem.availQty > 0 ? 'Accept' : 'Change Supplier')
                                : 'Send to Supplier',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                           fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

