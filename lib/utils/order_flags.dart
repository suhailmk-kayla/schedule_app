/// Order approval workflow flags (converted from KMP's OrderApprovalFlag.kt)
class OrderApprovalFlag {
  static const int newOrder = 0;
  static const int sendToStorekeeper = 1;
  static const int verifiedByStorekeeper = 2;
  static const int completed = 3;
  static const int rejected = 4;
  static const int cancelled = 5;
  static const int sendToChecker = 6;
  static const int checkerIsChecking = 7;
}

/// Order sub workflow flags (converted from KMP's OrderSubFlag.kt)
class OrderSubFlag {
  static const int newItem = 0;
  static const int notChecked = 1;
  static const int inStock = 2;
  static const int outOfStock = 3;
  static const int reported = 4;
  static const int notAvailable = 5;
  static const int cancelled = 6;
  static const int replaced = 7;
}

class OrderFlags {
  static const int deleted = 0;
  static const int active = 1;
  static const int temp = 2;
  static const int draft = 3;
}

class OrderSubFlags {
  static const int deleted = 0;
  static const int active = 1;
  static const int temp = 2;
}


