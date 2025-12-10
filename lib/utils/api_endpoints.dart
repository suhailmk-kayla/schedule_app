/// API Endpoints
/// Converted from KMP's Urls.kt
/// All endpoints from KMP's Urls.kt should be added here
import 'config.dart';

class ApiEndpoints {
  // Auth
  static const String login = 'api/login';
  static const String logout = 'api/logout';
  static const String register = 'api/register';

  // Users
  static const String addUser = 'api/users/add';
  static const String deleteUser = 'api/users/delete';
  static const String updateUser = 'api/users/update_user';
  static const String changePassword = 'api/users/change_pass';
  static const String checkUserActive = 'api/users/check_is_active';
  static const String logoutUserDevice = 'api/users/logoutUserDevice';
  static const String logoutAllUserDevice = 'api/users/logoutAllUserDevice';

  // Customer
  static const String addCustomer = 'api/customer/add';
  static const String updateCustomer = 'api/customer/update';
  static const String updateCustomerFlag = 'api/customer/update_flag';

  // Category
  static const String addCategory = 'api/category/add';
  static const String updateCategory = 'api/category/update';

  // SubCategory
  static const String addSubCategory = 'api/sub_category/add';
  static const String updateSubCategory = 'api/sub_category/update';

  // UserCategory
  static const String addUserCategory = 'api/user_category/add';

  // Unit
  static const String addUnit = 'api/unit/add';
  static const String updateUnit = 'api/unit/update';

  // ProductUnit
  static const String addProductUnit = 'api/product_unit/add';

  // Route
  static const String addRoute = 'api/route/add';
  static const String updateRoute = 'api/route/update';

  // Product
  static const String addProduct = 'api/products/add';
  static const String updateProduct = 'api/products/update';

  // ProductCar
  static const String addProductCar = 'api/product_cars/add';
  static const String addCar = 'api/cars/add';

  // Car Brand
  static const String addCarBrand = 'api/cars/add_car_brand';
  static const String updateCarBrand = 'api/cars/update_car_brand';

  // Order
  static const String addOrder = 'api/orders/add';
  static const String updateOrder = 'api/orders/update_order';
  static const String updateOrderSub = 'api/orders/update_order_sub';
  static const String updateBillerOrChecker = 'api/orders/update_biller_adn_checker';
  static const String updateOrderApproveFlag = 'api/orders/update_order_flag';
  static const String updateStoreKeeper = 'api/orders/update_store_keeper';

  // OutOfStock
  static const String addOutOfStock = 'api/out_of_stocks/add';
  static const String addOutOfStockAll = 'api/out_of_stocks/add_all';
  static const String updateOutOfStockSub = 'api/out_of_stock_sub/update';
  static const String updateOutOfStockMasterFlag = 'api/out_of_stock/update_compleated_flag';

  // PushNotification
  // static const String pushNotification = 'api/push_notification/add';
    static const String pushNotification = 'api/push_notification/send_batched';

  // Downloads
  static const String usersDownload = 'api/users/download';
  static const String salesManDownload = 'api/sales_man/download';
  static const String supplierDownload = 'api/suppliers/download';
  static const String customerDownload = 'api/customer/download';
  static const String unitsDownload = 'api/units/download';
  static const String categoryDownloads = 'api/category/download';
  static const String subCategoryDownloads = 'api/sub_category/download';
  static const String userCategoryDownloads = 'api/user_category/download';
  static const String productUnitDownload = 'api/product_units/download';
  static const String productDownload = 'api/products/download';
  static const String productCarDownload = 'api/product_cars/download';
  static const String routesDownload = 'api/routes/download';
  static const String carBrandDownload = 'api/cars/download_car_brands';
  static const String carNameDownload = 'api/cars/download_car_names';
  static const String carModelDownload = 'api/cars/download_car_models';
  static const String carVersionDownload = 'api/cars/download_car_versions';
  static const String orderDownload = 'api/orders/download_orders';
  static const String orderSubDownload = 'api/orders/download_order_sub';
  static const String orderSubSuggestionDownload = 'api/orders/download_order_sub_suggestions';
  static const String outOfStockDownload = 'api/out_of_stock/download_out_of_stocks';
  static const String outOfStockSubDownload = 'api/out_of_stock/download_out_of_stock_sub';

  /// Helper method to build full URL
  static String buildUrl(String endpoint) => '${ApiConfig.baseUrl}$endpoint';
}

