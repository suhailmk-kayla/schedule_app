/// Helper to convert cat_id (user type) to category name
/// Matches KMP's UserType mapping:
/// 1-Admin, 2-Storekeeper, 3-SalesMan, 4-Supplier, 5-Biller, 6-Checker, 7-Driver

class UserTypeHelper {
  static const Map<int, String> _catIdToName = {
    1: 'Admin',
    2: 'Storekeeper',
    3: 'Sales Man',
    4: 'Supplier',
    5: 'Biller',
    6: 'Checker',
    7: 'Driver',
  };

  static String nameFromCatId(int? catId) {
    if (catId == null) return 'Unknown';
    return _catIdToName[catId] ?? 'Unknown';
  }
}
