import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/helpers/admin_registration_helper.dart';
import 'di.dart';
import 'utils/push_notification_helper.dart';
import 'utils/notification_manager.dart';
import 'presentation/features/auth/splash_screen.dart';
import 'presentation/provider/auth_provider.dart';
import 'presentation/provider/products_provider.dart';
import 'presentation/provider/customers_provider.dart';
import 'presentation/provider/orders_provider.dart';
import 'presentation/provider/sync_provider.dart';
import 'presentation/provider/home_provider.dart';
import 'presentation/provider/users_provider.dart';
import 'presentation/provider/routes_provider.dart';
import 'presentation/provider/salesman_provider.dart';
import 'presentation/provider/out_of_stock_provider.dart';
import 'presentation/provider/suppliers_provider.dart';
import 'presentation/provider/units_provider.dart';
import 'presentation/provider/categories_provider.dart';
import 'presentation/provider/sub_categories_provider.dart';
import 'presentation/provider/cars_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // final result = await createAdminAccount();

  // Initialize OneSignal for push notifications (must be before setupDependencies)
  try {
    await PushNotificationHelper.initialize();
  }
   catch (e) {
    // Log error but don't block app startup
    debugPrint('OneSignal initialization failed: $e');
  }

  // Initialize dependencies (database, dio, repositories, providers)
  await setupDependencies();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // NotificationManager must be registered first so other providers can listen to it
        ChangeNotifierProvider(
          create: (_) => NotificationManager(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<AuthProvider>()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<ProductsProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<CustomersProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<OrdersProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<SyncProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<HomeProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<UsersProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<RoutesProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<SalesmanProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<OutOfStockProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<SuppliersProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<UnitsProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<CategoriesProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<SubCategoriesProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<CarsProvider>(),
        ),
      ],
      child: MaterialApp(
        title: 'Schedule App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
