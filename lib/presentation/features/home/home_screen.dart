import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/home_provider.dart';
import '../../provider/auth_provider.dart';
import '../auth/splash_screen.dart';
import '../products/products_screen.dart';
import '../users/users_screen.dart';

/// Home Screen
/// Main dashboard screen
/// Converted from KMP's Home.kt
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load unviewed counts on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      homeProvider.loadUnviewedCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            // TODO: Open drawer
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (!mounted) return;
              // Navigate to SplashScreen which will show LoginScreen
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const SplashScreen(),
                ),
                (route) => false, // Remove all previous routes
              );
            },
          ),
        ],
      ),
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
  }

  void _handleMenuTap(BuildContext context, MenuType menuType) {
    // TODO: Navigate to appropriate screen based on menu type
    switch (menuType) {
      case MenuType.orders:
        // Navigator.push(context, MaterialPageRoute(builder: (_) => OrdersScreen()));
        break;
      case MenuType.outOfStock:
        // Navigator.push(context, MaterialPageRoute(builder: (_) => OutOfStockScreen()));
        break;
      case MenuType.products:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen()));
        break;
      case MenuType.customers:
        // Navigator.push(context, MaterialPageRoute(builder: (_) => CustomersScreen()));
        break;
      case MenuType.suppliers:
        // Navigator.push(context, MaterialPageRoute(builder: (_) => SuppliersScreen()));
        break;
      case MenuType.users:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen()));
        break;
      case MenuType.salesman:
        // Navigator.push(context, MaterialPageRoute(builder: (_) => SalesmanScreen()));
        break;
      case MenuType.routes:
        // Navigator.push(context, MaterialPageRoute(builder: (_) => RoutesScreen()));
        break;
      case MenuType.productSettings:
        // Navigator.push(context, MaterialPageRoute(builder: (_) => ProductSettingsScreen()));
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

  const _MenuItemCard({
    required this.menuItem,
    required this.onTap,
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
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      menuItem.count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
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
                  Icon(
                    menuItem.icon,
                    size: 32,
                    color: Colors.black,
                  ),
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

