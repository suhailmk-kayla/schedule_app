/// Dependency Injection Setup
/// Using get_it package
/// All dependencies should be registered here
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:schedule_frontend_flutter/presentation/provider/customers_provider.dart';
import 'package:schedule_frontend_flutter/presentation/provider/orders_provider.dart';
import 'package:schedule_frontend_flutter/presentation/provider/products_provider.dart';
import 'package:schedule_frontend_flutter/presentation/provider/sync_provider.dart';
import 'repositories/local/database_helper.dart';
import 'repositories/products/products_repository.dart';
import 'repositories/categories/categories_repository.dart';
import 'repositories/orders/orders_repository.dart';
import 'repositories/customers/customers_repository.dart';
import 'repositories/units/units_repository.dart';
import 'repositories/sub_categories/sub_categories_repository.dart';
import 'repositories/routes/routes_repository.dart';
import 'repositories/users/users_repository.dart';
import 'repositories/cars/car_brand_repository.dart';
import 'repositories/cars/car_name_repository.dart';
import 'repositories/cars/car_model_repository.dart';
import 'repositories/cars/car_version_repository.dart';
import 'repositories/user_category/user_category_repository.dart';
import 'repositories/salesman/salesman_repository.dart';
import 'repositories/suppliers/suppliers_repository.dart';
import 'repositories/sync_time/sync_time_repository.dart';
import 'repositories/failed_sync/failed_sync_repository.dart';
import 'repositories/order_sub_suggestions/order_sub_suggestions_repository.dart';
import 'repositories/packed_subs/packed_subs_repository.dart';
import 'repositories/out_of_stock/out_of_stock_repository.dart';
import 'utils/config.dart';
import 'utils/interceptors/auth_interceptor.dart';
import 'utils/interceptors/logging_interceptor.dart';
import 'utils/interceptors/retry_interceptor.dart';
import 'presentation/provider/auth_provider.dart';
import 'presentation/provider/home_provider.dart';
import 'presentation/provider/users_provider.dart';

final getIt = GetIt.instance;

/// Setup all dependencies
/// Call this in main.dart before runApp()
Future<void> setupDependencies() async {
  // Register database helper
  final databaseHelper = DatabaseHelper();
  await databaseHelper.initDatabase();
  getIt.registerSingleton<DatabaseHelper>(databaseHelper);

  // Register Dio with base URL
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));
  
  // Add interceptors (order matters: auth first, then logging, then retry)
  dio.interceptors.add(AuthInterceptor());
  dio.interceptors.add(LoggingInterceptor(enabled: !ApiConfig.isProductionMode));
  dio.interceptors.add(RetryInterceptor(
    dio: dio, // Pass Dio instance for retry
    maxRetries: 3,
    retryDelay: const Duration(seconds: 1),
  ));
  
  getIt.registerSingleton<Dio>(dio);

  // Register repositories
  getIt.registerLazySingleton<ProductsRepository>(
    () => ProductsRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<CategoriesRepository>(
    () => CategoriesRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<OrdersRepository>(
    () => OrdersRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<CustomersRepository>(
    () => CustomersRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<UnitsRepository>(
    () => UnitsRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<SubCategoriesRepository>(
    () => SubCategoriesRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<RoutesRepository>(
    () => RoutesRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<UsersRepository>(
    () => UsersRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<CarBrandRepository>(
    () => CarBrandRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<CarNameRepository>(
    () => CarNameRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<CarModelRepository>(
    () => CarModelRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<CarVersionRepository>(
    () => CarVersionRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<UserCategoryRepository>(
    () => UserCategoryRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<SalesManRepository>(
    () => SalesManRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<SuppliersRepository>(
    () => SuppliersRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<SyncTimeRepository>(
    () => SyncTimeRepository(
      databaseHelper: getIt<DatabaseHelper>(),
    ),
  );

  getIt.registerLazySingleton<FailedSyncRepository>(
    () => FailedSyncRepository(
      databaseHelper: getIt<DatabaseHelper>(),
    ),
  );

  getIt.registerLazySingleton<OrderSubSuggestionsRepository>(
    () => OrderSubSuggestionsRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<PackedSubsRepository>(
    () => PackedSubsRepository(
      databaseHelper: getIt<DatabaseHelper>(),
    ),
  );

  getIt.registerLazySingleton<OutOfStockRepository>(
    () => OutOfStockRepository(
      databaseHelper: getIt<DatabaseHelper>(),
      dio: getIt<Dio>(),
    ),
  );

  // Register Providers
  getIt.registerLazySingleton<AuthProvider>(
    () => AuthProvider(
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<ProductsProvider>(
    () => ProductsProvider(
      productsRepository: getIt<ProductsRepository>(),
      categoriesRepository: getIt<CategoriesRepository>(),
      subCategoriesRepository: getIt<SubCategoriesRepository>(),
      unitsRepository: getIt<UnitsRepository>(),
    ),
  );

  getIt.registerLazySingleton<CustomersProvider>(
    () => CustomersProvider(
      customersRepository: getIt<CustomersRepository>(),
      routesRepository: getIt<RoutesRepository>(),
      salesManRepository: getIt<SalesManRepository>(),
      ordersRepository: getIt<OrdersRepository>(),
    ),
  );

  getIt.registerLazySingleton<OrdersProvider>(
    () => OrdersProvider(
      ordersRepository: getIt<OrdersRepository>(),
      routesRepository: getIt<RoutesRepository>(),
      packedSubsRepository: getIt<PackedSubsRepository>(),
    ),
  );

  getIt.registerLazySingleton<SyncProvider>(
    () => SyncProvider(
      productsRepository: getIt<ProductsRepository>(),
      unitsRepository: getIt<UnitsRepository>(),
      categoriesRepository: getIt<CategoriesRepository>(),
      subCategoriesRepository: getIt<SubCategoriesRepository>(),
      carBrandRepository: getIt<CarBrandRepository>(),
      carNameRepository: getIt<CarNameRepository>(),
      carModelRepository: getIt<CarModelRepository>(),
      carVersionRepository: getIt<CarVersionRepository>(),
      usersRepository: getIt<UsersRepository>(),
      userCategoryRepository: getIt<UserCategoryRepository>(),
      routesRepository: getIt<RoutesRepository>(),
      salesManRepository: getIt<SalesManRepository>(),
      suppliersRepository: getIt<SuppliersRepository>(),
      customersRepository: getIt<CustomersRepository>(),
      ordersRepository: getIt<OrdersRepository>(),
      outOfStockRepository: getIt<OutOfStockRepository>(),
      orderSubSuggestionsRepository: getIt<OrderSubSuggestionsRepository>(),
      failedSyncRepository: getIt<FailedSyncRepository>(),
      syncTimeRepository: getIt<SyncTimeRepository>(),
    ),
  );

  getIt.registerLazySingleton<HomeProvider>(
    () => HomeProvider(
      ordersRepository: getIt<OrdersRepository>(),
      outOfStockRepository: getIt<OutOfStockRepository>(),
    ),
  );

  getIt.registerLazySingleton<UsersProvider>(
    () => UsersProvider(usersRepository: getIt<UsersRepository>()),
  );
}

