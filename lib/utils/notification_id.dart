/// Notification ID Constants
/// Maps table types to numeric IDs for push notifications
/// Converted from KMP's NotificationId.kt
class NotificationId {
  static const int product = 1;
  static const int carBrand = 2;
  static const int carName = 3;
  static const int carModel = 4;
  static const int carVersion = 5;
  static const int category = 6;
  static const int subCategory = 7;
  static const int order = 8;
  static const int orderSub = 9;
  static const int orderSubSuggestion = 10;
  static const int outOfStock = 11;
  static const int outOfStockSub = 12;
  static const int customer = 13;
  static const int user = 14;
  static const int salesman = 15;
  static const int supplier = 16;
  static const int routes = 17;
  static const int units = 18;
  static const int productUnits = 19;
  static const int productCar = 20;
  static const int updateStoreKeeper = 21;
  static const int logout = 22;

  /// Get table name from notification ID
  static String getTableName(int tableId) {
    switch (tableId) {
      case product:
        return 'Product';
      case carBrand:
        return 'CarBrand';
      case carName:
        return 'CarName';
      case carModel:
        return 'CarModel';
      case carVersion:
        return 'CarVersion';
      case category:
        return 'Category';
      case subCategory:
        return 'SubCategory';
      case order:
        return 'Order';
      case orderSub:
        return 'OrderSub';
      case orderSubSuggestion:
        return 'OrderSubSuggestion';
      case outOfStock:
        return 'OutOfStock';
      case outOfStockSub:
        return 'OutOfStockSub';
      case customer:
        return 'Customer';
      case user:
        return 'User';
      case salesman:
        return 'Salesman';
      case supplier:
        return 'Supplier';
      case routes:
        return 'Routes';
      case units:
        return 'Units';
      case productUnits:
        return 'ProductUnits';
      case productCar:
        return 'ProductCar';
      case updateStoreKeeper:
        return 'UpdateStoreKeeper';
      case logout:
        return 'Logout';
      default:
        return 'Unknown';
    }
  }
}

