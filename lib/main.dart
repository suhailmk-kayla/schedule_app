import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/background_sync_worker.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:developer' as developer;
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
import 'presentation/common_widgets/sync_notification_widget.dart';
//TODO:change to production server before sending apk

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // final result = await createAdminAccount();
  // Initialize OneSignal for push notifications (must be before setupDependencies)
  try {
    await PushNotificationHelper.initialize();
    
  } catch (e) {
    // Log error but don't block app startup
    debugPrint('OneSignal initialization failed: $e');
  }
  // Initialize dependencies (database, dio, repositories, providers)
  await setupDependencies();
  // Initialize WorkManager for background sync
  try {
    await Workmanager().initialize(
      callbackDispatcher, // Imported from background_sync_worker.dart
      isInDebugMode: true,
    );
    await BackgroundSyncWorker.registerPeriodicTask();
     
  } catch (e) {
    // Log error but don't block app startup
  }
  // await BackgroundSyncWorker.registerTestTask();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App came to foreground from background
      // Process any stored notifications that were received while app was in background
      PushNotificationHelper.processStoredNotifications();
      
      // Optional enhancement: Retry failed syncs when app comes to foreground
      // This helps catch any missed notifications while app was in background
      // (KMP doesn't do this automatically, but it's a good practice for reliability)
      try {
        final syncProvider = getIt<SyncProvider>();
        syncProvider.syncFailedSyncs().catchError((e) {
           
        });
      } catch (e) {
         
      }
      
      // Check if background sync worker detected that sync is needed
      // If last sync is 12+ hours old, trigger sync automatically
      // _checkAndTriggerSyncIfNeeded();
    }
  }

  /// Check if sync is needed and trigger it automatically
  // void _checkAndTriggerSyncIfNeeded() {
  //   BackgroundSyncWorker.isSyncNeeded().then((isNeeded) {
  //     if (isNeeded) {
  //        
  //       try {
  //         final syncProvider = getIt<SyncProvider>();
  //         // Only trigger if not already syncing
  //         if (!syncProvider.isSyncing) {
  //           syncProvider.startSync().catchError((e) {
  //              
  //           });
  //         } else {
  //            
  //         }
  //       } catch (e) {
  //          
  //       }
  //     } else {
  //        
  //     }
  //   }).catchError((e) {
  //      
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // NotificationManager must be registered first so other providers can listen to it
        ChangeNotifierProvider(create: (_) => NotificationManager()),
        ChangeNotifierProvider(
          create: (_) => getIt<AuthProvider>()..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => getIt<ProductsProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<CustomersProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<OrdersProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<SyncProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<HomeProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<UsersProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<RoutesProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<SalesmanProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<OutOfStockProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<SuppliersProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<UnitsProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<CategoriesProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<SubCategoriesProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<CarsProvider>()),
      ],
      child: Consumer<NotificationManager>(
        builder: (context, notificationManager, _) {
          if (notificationManager.notificationLogoutTrigger) {
             
            WidgetsBinding.instance.addPostFrameCallback((_) {
              notificationManager.resetLogoutTrigger();
              _navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                (route) => false,
              );
            });
          }
          
          return MaterialApp(
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
                child: SyncNotificationWidget(
                  child: child!,
                ),
              );
            },
            navigatorKey: _navigatorKey,
            title: 'Schedule App',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
