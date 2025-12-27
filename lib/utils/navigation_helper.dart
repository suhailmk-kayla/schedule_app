import 'package:flutter/material.dart';
import 'package:schedule_frontend_flutter/presentation/features/out_of_stock/out_of_stock_list_supplier_screen.dart';
import '../presentation/features/home/home_screen.dart';
import '../presentation/features/orders/orders_screen.dart';
import 'storage_helper.dart';

/// Navigation Helper
/// Provides role-based navigation routing
/// Matches KMP's BaseScreen.kt navigation logic (lines 263-270)
class NavigationHelper {
  /// Get the initial screen widget based on user type
  /// Matches KMP logic:
  /// - ADMIN (1), STOREKEEPER (2), SALESMAN (3) -> HomeScreen
  /// - SUPPLIER (4) -> OutOfStockListSupplierScreen
  /// - BILLER (5), CHECKER (6), DRIVER (7) -> OrdersScreen
  static Future<Widget> getInitialScreen() async {
    final userType = await StorageHelper.getUserType();
    final userId = await StorageHelper.getUserId();

    switch (userType) {
      case 1: // ADMIN
      case 2: // STOREKEEPER
      case 3: // SALESMAN
        return const HomeScreen();

      case 4: // SUPPLIER
        // In KMP: BaseScreen.OutOfStockSupplier.name+"/${AppSettings().getUserId()}"
        return OutOfStockListSupplierScreen(userId: userId);
      case 5: // BILLER
      case 6: // CHECKER
      case 7: // DRIVER
      default:
        // else -> BaseScreen.Orders.name
        return const OrdersScreen();
    }
  }

  /// Navigate to initial screen based on user type
  /// Used after login/sync completion
  static Future<void> navigateToInitialScreen(BuildContext context) async {
    final screen = await getInitialScreen();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => screen),
      );
    }
  }
}

