// Dependency Injection Setup
// Using get_it package
// All dependencies should be registered here
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
import 'utils/dio_helper.dart';
import 'utils/push_notification_sender.dart';
import 'utils/push_notification_builder.dart';
import 'presentation/provider/auth_provider.dart';
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

final getIt = GetIt.instance;

/// Setup all dependencies
/// Call this in main.dart before runApp()
Future<void> setupDependencies() async {
  // Register database helper
  final databaseHelper = DatabaseHelper();
  await databaseHelper.initDatabase();
  getIt.registerSingleton<DatabaseHelper>(databaseHelper);

  // Register Dio instance from DioHelper (singleton with all interceptors configured)
  getIt.registerSingleton<Dio>(DioHelper.instance);

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
      pushNotificationSender: getIt<PushNotificationSender>(),
      salesManRepository: getIt<SalesManRepository>(),
      suppliersRepository: getIt<SuppliersRepository>(),
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

  // Register PushNotificationSender (after SalesMan and Suppliers, before UsersRepository)
  getIt.registerLazySingleton<PushNotificationSender>(
    () => PushNotificationSender(
      dio: getIt<Dio>(),
    ),
  );

  // Register PushNotificationBuilder (after UsersRepository)
  getIt.registerLazySingleton<PushNotificationBuilder>(
    () => PushNotificationBuilder(
      usersRepository: getIt<UsersRepository>(),
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
      suppliersRepository: getIt<SuppliersRepository>(),
    ),
  );

  getIt.registerLazySingleton<CustomersProvider>(
    () => CustomersProvider(
      customersRepository: getIt<CustomersRepository>(),
      routesRepository: getIt<RoutesRepository>(),
      salesManRepository: getIt<SalesManRepository>(),
      ordersRepository: getIt<OrdersRepository>(),
      pushNotificationSender: getIt<PushNotificationSender>(),
      pushNotificationBuilder: getIt<PushNotificationBuilder>(),
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
      packedSubsRepository: getIt<PackedSubsRepository>(),
    ),
  );

  getIt.registerLazySingleton<HomeProvider>(
    () => HomeProvider(
      ordersRepository: getIt<OrdersRepository>(),
      outOfStockRepository: getIt<OutOfStockRepository>(),
    ),
  );

  getIt.registerLazySingleton<UsersProvider>(
    () => UsersProvider(
      usersRepository: getIt<UsersRepository>(),
      userCategoryRepository: getIt<UserCategoryRepository>(),
    ),
  );

  getIt.registerLazySingleton<RoutesProvider>(
    () => RoutesProvider(
      routesRepository: getIt<RoutesRepository>(),
      salesManRepository: getIt<SalesManRepository>(),
    ),
  );

  getIt.registerLazySingleton<SalesmanProvider>(
    () => SalesmanProvider(
      salesManRepository: getIt<SalesManRepository>(),
    ),
  );

  getIt.registerLazySingleton<OutOfStockProvider>(
    () => OutOfStockProvider(
      outOfStockRepository: getIt<OutOfStockRepository>(),
      packedSubsRepository: getIt<PackedSubsRepository>(),
    ),
  );

  getIt.registerLazySingleton<SuppliersProvider>(
    () => SuppliersProvider(
      suppliersRepository: getIt<SuppliersRepository>(),
    ),
  );

  getIt.registerLazySingleton<UnitsProvider>(
    () => UnitsProvider(
      unitsRepository: getIt<UnitsRepository>(),
    ),
  );

  getIt.registerLazySingleton<CategoriesProvider>(
    () => CategoriesProvider(
      categoriesRepository: getIt<CategoriesRepository>(),
    ),
  );

  getIt.registerLazySingleton<SubCategoriesProvider>(
    () => SubCategoriesProvider(
      subCategoriesRepository: getIt<SubCategoriesRepository>(),
      categoriesRepository: getIt<CategoriesRepository>(),
    ),
  );

  getIt.registerLazySingleton<CarsProvider>(
    () => CarsProvider(
      carBrandRepository: getIt<CarBrandRepository>(),
      carNameRepository: getIt<CarNameRepository>(),
      carModelRepository: getIt<CarModelRepository>(),
      carVersionRepository: getIt<CarVersionRepository>(),
    ),
  );
}

