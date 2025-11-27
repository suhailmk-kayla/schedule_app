import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:schedule_frontend_flutter/presentation/features/orders/orders_screen.dart';
import 'package:schedule_frontend_flutter/presentation/features/product_settings/product_settings_screen.dart';
import '../../provider/home_provider.dart';
import '../../provider/auth_provider.dart';
import '../../provider/sync_provider.dart';
import '../../../utils/storage_helper.dart';
import '../../../utils/asset_images.dart';
import '../../../helpers/user_type_helper.dart';
import '../auth/splash_screen.dart';
import '../sync/sync_screen.dart';
import '../products/products_screen.dart';
import '../customers/customers_screen.dart';
import '../users/users_screen.dart';
import '../salesman/salesman_screen.dart';
import '../routes/routes_screen.dart';
import '../about/about_screen.dart';

/// Home Drawer
/// Displays user info, menu items, and logout
/// Converted from KMP's DrawerScreen.kt
class HomeDrawer extends StatefulWidget {
  const HomeDrawer({super.key});

  @override
  State<HomeDrawer> createState() => _HomeDrawerState();
}

class _HomeDrawerState extends State<HomeDrawer> {
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  void _handleMenuTap(MenuType menuType) {
    Navigator.pop(context); // Close drawer first
    
    switch (menuType) {
      case MenuType.orders:
        // TODO: Navigate to OrdersScreen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OrdersScreen()),
        );
        break;
      case MenuType.outOfStock:
        // TODO: Navigate to OutOfStockScreen
        break;
      case MenuType.products:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductsScreen()),
        );
        break;
      case MenuType.customers:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CustomersScreen()),
        );
        break;
      case MenuType.suppliers:
        // TODO: Navigate to SuppliersScreen
        break;
      case MenuType.users:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UsersScreen()),
        );
        break;
      case MenuType.salesman:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SalesmanScreen()),
        );
        break;
      case MenuType.routes:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RoutesScreen()),
        );
        break;
      case MenuType.productSettings:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductSettingsScreen()),
        );
        // TODO: Navigate to ProductSettingsScreen
        break;
      case MenuType.syncDetails:
        // Navigate to SyncScreen - it will automatically start syncing
        // Matching KMP's behavior: SyncScreen auto-starts sync on initState
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SyncScreen()),
        );
        break;
      case MenuType.about:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutScreen()),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _handleLogout() async {
    Navigator.pop(context); // Close dialog first

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Call logout API first (matching KMP's logoutApi)
      // Note: authProvider.logout() already clears storage, but we need to clear tables first
      // Clear all tables (matching KMP's clearAllTable before AppSettings().clear())
      await syncProvider.clearAllTable();

      // Call logout API (this will clear storage via authProvider.logout())
      await authProvider.logout();

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      // Navigate to splash screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const SplashScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              // Navigator.pop(context);
              _handleLogout();
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              // User Avatar
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: Image.asset(
                    AssetImages.imagesPngegg,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.blue,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // User Name
              FutureBuilder<String>(
                future: StorageHelper.getUser(),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 2),
              // User Type
              FutureBuilder<int>(
                future: StorageHelper.getUserType(),
                builder: (context, snapshot) {
                  final userType = snapshot.data ?? 0;
                  return Text(
                    UserTypeHelper.nameFromCatId(userType),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 20),
              // Logout Button
              OutlinedButton(
                onPressed: _showLogoutConfirmationDialog,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 1),
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(
                      Icons.logout,
                      size: 22,
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              // App Version
              Text(
                'Version ${_appVersion ?? '1.0.0'}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              // Divider
              const Divider(
                color: Colors.black,
                thickness: 1,
                indent: 40,
                endIndent: 40,
              ),
              const SizedBox(height: 16),
              // Menu Items
              FutureBuilder<List<MenuItem>>(
                future: _getDrawerMenuItems(
                  Provider.of<HomeProvider>(context, listen: false),
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final menuItems = snapshot.data!;
                  return Column(
                    children: menuItems.map((menuItem) {
                      return _DrawerMenuItem(
                        menuItem: menuItem,
                        onTap: () => _handleMenuTap(menuItem.type),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  /// Get drawer menu items (same as home screen but always includes Force Sync and About)
  /// Converted from KMP's initMenu function in Drawar.kt
  Future<List<MenuItem>> _getDrawerMenuItems(HomeProvider homeProvider) async {
    final menuList = <MenuItem>[];
    final userType = await StorageHelper.getUserType();

    // Orders - All except Supplier (userType != 4)
    if (userType != 4) {
      menuList.add(MenuItem(
        type: MenuType.orders,
        title: 'Orders',
        icon: Icons.shopping_cart,
        imagePath: AssetImages.imagesOrder,
      ));
    }

    // Out of Stock - Admin (1), Storekeeper (2), Supplier (4)
    if (userType == 4 || userType == 1 || userType == 2) {
      final outOfStockText = userType == 4 ? 'Orders' : 'Out of Stock';
      final outOfStockImage = userType == 4
          ? AssetImages.imagesOrder
          : AssetImages.imagesOutofstock;
      menuList.add(MenuItem(
        type: MenuType.outOfStock,
        title: outOfStockText,
        icon: Icons.inventory_2,
        imagePath: outOfStockImage,
      ));
    }

    // Products - Admin (1), Salesman (3)
    if (userType == 1 || userType == 3) {
      menuList.add(MenuItem(
        type: MenuType.products,
        title: 'Products',
        icon: Icons.inventory,
        imagePath: AssetImages.imagesProducts,
      ));
    }

    // Customers - Admin (1), Salesman (3)
    if (userType == 1 || userType == 3) {
      menuList.add(MenuItem(
        type: MenuType.customers,
        title: 'Customers',
        icon: Icons.people,
        imagePath: AssetImages.imagesCustomer,
      ));
    }

    // Suppliers - Admin only (1)
    if (userType == 1) {
      menuList.add(MenuItem(
        type: MenuType.suppliers,
        title: 'Suppliers',
        icon: Icons.local_shipping,
        imagePath: AssetImages.imagesSupplier,
      ));
    }

    // Users - Admin only (1)
    if (userType == 1) {
      menuList.add(MenuItem(
        type: MenuType.users,
        title: 'Users',
        icon: Icons.person,
        imagePath: AssetImages.imagesUsers,
      ));
    }

    // Salesman - Admin only (1)
    if (userType == 1) {
      menuList.add(MenuItem(
        type: MenuType.salesman,
        title: 'Sales Man',
        icon: Icons.person_outline,
        imagePath: AssetImages.imagesSalesman,
      ));
    }

    // Routes - Admin only (1)
    if (userType == 1) {
      menuList.add(MenuItem(
        type: MenuType.routes,
        title: 'Routes',
        icon: Icons.route,
        imagePath: AssetImages.imagesRoute,
      ));
    }

    // Product Settings - Admin only (1)
    if (userType == 1) {
      menuList.add(MenuItem(
        type: MenuType.productSettings,
        title: 'Product Settings',
        icon: Icons.settings,
        imagePath: AssetImages.imagesProductSetting,
      ));
    }

    // Always add Force Sync and About (matching KMP)
    menuList.add(MenuItem(
      type: MenuType.syncDetails,
      title: 'Force Sync',
      icon: Icons.sync,
      // imagePath: AssetImages.imagesDatastrategy, // Using data-strategy as sync icon
    ));
    menuList.add(MenuItem(
      type: MenuType.about,
      title: 'About',
      icon: Icons.info_outline,
      // imagePath: AssetImages.imagesDatastrategy, // Using placeholder
    ));

    return menuList;
  }
}

/// Drawer Menu Item Widget
/// Converted from KMP's MenuRow composable
class _DrawerMenuItem extends StatelessWidget {
  final MenuItem menuItem;
  final VoidCallback onTap;

  const _DrawerMenuItem({
    required this.menuItem,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 50,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                // Icon/Image
                Image.asset(
                  menuItem.imagePath ?? '',
                  width: 36,
                  height: 36,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      menuItem.icon,
                      size: 36,
                      color: Colors.black,
                    );
                  },
                ),
                const SizedBox(width: 16),
                // Title
                Text(
                  menuItem.title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Divider
        Divider(
          color: Colors.grey.shade300,
          thickness: 1,
          indent: 40,
          endIndent: 40,
        ),
      ],
    );
  }
}

