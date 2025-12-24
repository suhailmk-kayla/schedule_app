import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import 'package:schedule_frontend_flutter/utils/push_notification_helper.dart';
import 'package:schedule_frontend_flutter/utils/storage_helper.dart';
import '../../provider/home_provider.dart';
import '../../provider/sync_provider.dart';
import '../../../utils/notification_manager.dart';
import '../products/products_screen.dart';
import '../users/users_screen.dart';
import '../routes/routes_screen.dart';
import '../salesman/salesman_screen.dart';
import '../customers/customers_screen.dart';
import '../product_settings/product_settings_screen.dart';
import '../orders/orders_screen.dart';
import '../out_of_stock/out_of_stock_list_screen.dart';
import '../suppliers/suppliers_screen.dart';
import 'home_drawer.dart';

/// Home Screen
/// Main dashboard screen
/// Converted from KMP's Home.kt
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Add observer to detect when app comes to foreground
    WidgetsBinding.instance.addObserver(this);
    
    // Load unviewed counts on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      homeProvider.loadUnviewedCounts();
      
      // Retry failed syncs on app start (matching KMP BaseScreen.kt line 176)
      // This ensures any missed push notifications are caught
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      syncProvider.syncFailedSyncs().then((_) {
        developer.log('HomeScreen: Completed retrying failed syncs');
      }).catchError((e) {
        developer.log('HomeScreen: Error retrying failed syncs: $e');
      });
    });
  }

  @override
  void dispose() {
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh badge counts when app comes to foreground
    // This catches cases when user returns from detail screens or app comes from background
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final homeProvider = Provider.of<HomeProvider>(context, listen: false);
        homeProvider.refreshCounts();
        developer.log('HomeScreen: Refreshed badge counts on app resume');
      });
    }
  }

  Future<void> _debugNotifications() async {
  print('=== PUSH NOTIFICATION DEBUG ===');
  
  // Check pending notifications
  final pending = await StorageHelper.getPendingNotifications();
  print('Pending notifications: ${pending.length}');
  for (final notif in pending) {
    print('  - Timestamp: ${notif['timestamp']}');
    print('  - Data: ${notif['data']}');
  }
  
  // Manually trigger processing (for testing)
  await PushNotificationHelper.processStoredNotifications();
  
  // Check again
  final after = await StorageHelper.getPendingNotifications();
  print('After processing: ${after.length}');
  print('==============================');
}

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationManager>(
      builder: (context, notificationManager, _) {
        // Listen to notification trigger and refresh data
        if (notificationManager.notificationTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final homeProvider = Provider.of<HomeProvider>(context, listen: false);
            homeProvider.refreshCounts();
            notificationManager.resetTrigger();
          });
        }

        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.bug_report),
                onPressed: _debugNotifications,
              ),
            ],
            title: const Text('Home'),
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
          ),
          drawer: const HomeDrawer(),
          body: Consumer<HomeProvider>(
            builder: (context, homeProvider, child) {
          if (homeProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (homeProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    homeProvider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      homeProvider.loadUnviewedCounts();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final menuItems = homeProvider.menuItems;

          if (menuItems.isEmpty) {
            return const Center(
              child: Text('No menu items available'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 1.4,
              ),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                return _MenuItemCard(
                  imagePath: menuItems[index].imagePath ?? '',
                  menuItem: menuItems[index],
                  onTap: () {
                    _handleMenuTap(context, menuItems[index].type);
                  },
                );
              },
            ),
          );
            },
          ),
        );
      },
    );
  }

  void _handleMenuTap(BuildContext context, MenuType menuType) {
    // TODO: Navigate to appropriate screen based on menu type
    switch (menuType) {
      case MenuType.orders:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OrdersScreen()),
        );
        break;
      case MenuType.outOfStock:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OutOfStockListScreen()),
        );
        break;
      case MenuType.products:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen()));
        break;
             case MenuType.customers:
               Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen()));
               break;
      case MenuType.suppliers:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SuppliersScreen()),
        );
        break;
      case MenuType.users:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen()));
        break;
      case MenuType.salesman:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesmanScreen()));
        break;
      case MenuType.routes:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutesScreen()));
        break;
      case MenuType.productSettings:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProductSettingsScreen(),
          ),
        );
        break;
      default:
        break;
    }
  }
}

/// Menu Item Card Widget
/// Converted from KMP's menuItem composable
class _MenuItemCard extends StatelessWidget {
  final MenuItem menuItem;
  final VoidCallback onTap;
  final String imagePath;

  const _MenuItemCard({
    required this.menuItem,
    required this.onTap,
    required this.imagePath
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Count badge
            if (menuItem.count > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                height: 20,
                width: 20,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      menuItem.count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(imagePath,width: 32,height: 32,),
                  const SizedBox(height: 8),
                  Text(
                    menuItem.title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

