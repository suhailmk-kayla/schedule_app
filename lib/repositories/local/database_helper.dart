import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../helpers/exceptions/database_exception.dart' as app_exceptions;

/// Database Helper
/// Manages SQLite database initialization, schema creation, and migrations
/// Converted from KMP's SQLDelight implementation
class DatabaseHelper {
  static const String _databaseName = 'Database.db';
  static const int _databaseVersion = 22; // 22 migrations in KMP project

  Database? _database;

  /// Get database instance (singleton)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
    );
  }

  /// Create database schema (for new installations)
  Future<void> _onCreate(Database db, int version) async {
    await _createAllTables(db);
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      await _runMigration(db, version);
    }
  }

  /// Handle database downgrades (should not happen in production)
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    // Downgrade not supported - would require data migration
    throw app_exceptions.DatabaseException(
      message: 'Database downgrade from version $oldVersion to $newVersion is not supported',
    );
  }

  /// Run migration for specific version
  Future<void> _runMigration(Database db, int version) async {
    switch (version) {
      case 1:
        await _migration1(db);
        break;
      case 2:
        await _migration2(db);
        break;
      case 3:
        await _migration3(db);
        break;
      case 4:
        await _migration4(db);
        break;
      case 5:
        await _migration5(db);
        break;
      case 6:
        await _migration6(db);
        break;
      case 7:
        await _migration7(db);
        break;
      case 8:
        await _migration8(db);
        break;
      case 9:
        await _migration9(db);
        break;
      case 10:
        await _migration10(db);
        break;
      case 11:
        await _migration11(db);
        break;
      case 12:
        await _migration12(db);
        break;
      case 13:
        await _migration13(db);
        break;
      case 14:
        await _migration14(db);
        break;
      case 15:
        await _migration15(db);
        break;
      case 16:
        await _migration16(db);
        break;
      case 17:
        await _migration17(db);
        break;
      case 18:
        await _migration18(db);
        break;
      case 19:
        await _migration19(db);
        break;
      case 20:
        await _migration20(db);
        break;
      case 21:
        await _migration21(db);
        break;
      case 22:
        await _migration22(db);
        break;
      default:
        throw app_exceptions.DatabaseException(
          message: 'Unknown migration version: $version',
        );
    }
  }

  /// Create all tables (final schema after all migrations)
  Future<void> _createAllTables(Database db) async {
    // Create all tables in dependency order
    await db.execute(_createSyncTimeTable);
    await db.execute(_createFailedSyncTable);
    await db.execute(_createUsersCategoryTable);
    await db.execute(_createUsersTable);
    await db.execute(_createSalesManTable);
    await db.execute(_createSuppliersTable);
    await db.execute(_createRoutesTable);
    await db.execute(_createCustomersTable);
    await db.execute(_createCategoryTable);
    await db.execute(_createSubCategoryTable);
    await db.execute(_createUnitsTable);
    await db.execute(_createProductTable);
    await db.execute(_createProductUnitsTable);
    await db.execute(_createProductCarTable);
    await db.execute(_createCarBrandTable);
    await db.execute(_createCarNameTable);
    await db.execute(_createCarModelTable);
    await db.execute(_createCarVersionTable);
    await db.execute(_createOrdersTable);
    await db.execute(_createOrderSubTable);
    await db.execute(_createOrderSubEditCacheTable);
    await db.execute(_createOrderSubSuggestionsTable);
    await db.execute(_createOutOfStockMasterTable);
    await db.execute(_createOutOfStockProductsTable);
    await db.execute(_createPackedSubsTable);
  }

  // ============================================================================
  // TABLE CREATION SQL (Final Schema)
  // ============================================================================

  static const String _createSyncTimeTable = '''
    CREATE TABLE SyncTime(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      table_name TEXT NOT NULL UNIQUE,
      update_date TEXT NOT NULL
    );
  ''';

  static const String _createFailedSyncTable = '''
    CREATE TABLE FailedSync (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      table_id INTEGER NOT NULL,
      data_id INTEGER NOT NULL
    );
  ''';

  static const String _createUsersCategoryTable = '''
    CREATE TABLE UsersCategory (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      userCategoryId INTEGER NOT NULL UNIQUE,
      name TEXT DEFAULT '' NOT NULL,
      permissionJson TEXT DEFAULT '{}' NOT NULL,
      flag INTEGER DEFAULT 1 NOT NULL
    );
  ''';

  static const String _createUsersTable = '''
    CREATE TABLE Users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      userId INTEGER NOT NULL UNIQUE,
      code TEXT DEFAULT '' NOT NULL,
      name TEXT DEFAULT '' NOT NULL,
      phone TEXT DEFAULT '' NOT NULL,
      address TEXT DEFAULT '' NOT NULL,
      categoryId INTEGER DEFAULT -1 NOT NULL,
      password TEXT DEFAULT '' NOT NULL,
      createdDateTime TEXT DEFAULT '' NOT NULL,
      updatedDateTime TEXT DEFAULT '' NOT NULL,
      deviceToken TEXT DEFAULT '' NOT NULL,
      multiDeviceLogin INTEGER DEFAULT 0 NOT NULL,
      flag INTEGER DEFAULT 1 NOT NULL
    );
  ''';

  static const String _createSalesManTable = '''
    CREATE TABLE SalesMan (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      salesManId INTEGER NOT NULL UNIQUE,
      userId INTEGER DEFAULT -1 NOT NULL,
      code TEXT DEFAULT '' NOT NULL,
      name TEXT DEFAULT '' NOT NULL,
      phone TEXT DEFAULT '' NOT NULL,
      address TEXT DEFAULT '' NOT NULL,
      deviceToken TEXT DEFAULT '' NOT NULL,
      createdDateTime TEXT DEFAULT '' NOT NULL,
      updatedDateTime TEXT DEFAULT '' NOT NULL,
      flag INTEGER DEFAULT 1 NOT NULL
    );
  ''';

  static const String _createSuppliersTable = '''
    CREATE TABLE Suppliers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      supplierId INTEGER NOT NULL UNIQUE,
      userId INTEGER DEFAULT -1 NOT NULL,
      code TEXT DEFAULT '' NOT NULL,
      name TEXT DEFAULT '' NOT NULL,
      phone TEXT DEFAULT '' NOT NULL,
      address TEXT DEFAULT '' NOT NULL,
      deviceToken TEXT DEFAULT '' NOT NULL,
      createdDateTime TEXT DEFAULT '' NOT NULL,
      updatedDateTime TEXT DEFAULT '' NOT NULL,
      flag INTEGER DEFAULT 1 NOT NULL
    );
  ''';

  static const String _createRoutesTable = '''
    CREATE TABLE Routes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      routeId INTEGER NOT NULL UNIQUE,
      code TEXT DEFAULT '' NOT NULL,
      name TEXT DEFAULT '' NOT NULL,
      salesmanId INTEGER DEFAULT -1 NOT NULL,
      createdDateTime TEXT DEFAULT '' NOT NULL,
      updatedDateTime TEXT DEFAULT '' NOT NULL,
      flag INTEGER DEFAULT 1 NOT NULL
    );
  ''';

  static const String _createCustomersTable = '''
    CREATE TABLE Customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customerId INTEGER NOT NULL UNIQUE,
      code TEXT DEFAULT '' NOT NULL,
      name TEXT DEFAULT '' NOT NULL,
      phone TEXT DEFAULT '' NOT NULL,
      address TEXT DEFAULT '' NOT NULL,
      routId INTEGER DEFAULT -1 NOT NULL,
      salesmanId INTEGER DEFAULT -1 NOT NULL,
      rating INTEGER DEFAULT 10 NOT NULL,
      deviceToken TEXT DEFAULT '' NOT NULL,
      createdDateTime TEXT DEFAULT '' NOT NULL,
      updatedDateTime TEXT DEFAULT '' NOT NULL,
      flag INTEGER DEFAULT 1 NOT NULL
    );
  ''';

  static const String _createCategoryTable = '''
    CREATE TABLE Category(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      categoryId INTEGER NOT NULL UNIQUE,
      name TEXT NOT NULL,
      remark TEXT NOT NULL,
      flag INTEGER DEFAULT 1 NOT NULL
    );
  ''';

  static const String _createSubCategoryTable = '''
    CREATE TABLE SubCategory(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subCategoryId INTEGER NOT NULL UNIQUE,
      parentId INTEGER NOT NULL,
      name TEXT NOT NULL,
      remark TEXT NOT NULL,
      flag INTEGER DEFAULT 1 NOT NULL
    );
  ''';

  static const String _createUnitsTable = '''
    CREATE TABLE Units (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      unitId INTEGER NOT NULL UNIQUE,
      code TEXT,
      name TEXT,
      displayName TEXT,
      type INTEGER,
      baseId INTEGER,
      baseQty REAL,
      comment TEXT,
      flag INTEGER
    );
  ''';

  static const String _createProductTable = '''
    CREATE TABLE Product (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      productId INTEGER NOT NULL UNIQUE,
      code TEXT DEFAULT '' NOT NULL,
      barcode TEXT DEFAULT '' NOT NULL,
      name TEXT DEFAULT '' NOT NULL,
      subName TEXT DEFAULT '' NOT NULL,
      brand TEXT DEFAULT '' NOT NULL,
      subBrand TEXT DEFAULT '' NOT NULL,
      categoryId INTEGER DEFAULT -1 NOT NULL,
      subCategoryId INTEGER DEFAULT -1 NOT NULL,
      defaultSuppId INTEGER DEFAULT -1 NOT NULL,
      autoSend INTEGER DEFAULT 0 NOT NULL,
      baseUnitId INTEGER DEFAULT -1 NOT NULL,
      defaultUnitId INTEGER DEFAULT -1 NOT NULL,
      photoUrl TEXT DEFAULT '' NOT NULL,
      price REAL DEFAULT 0.0 NOT NULL,
      mrp REAL DEFAULT 0.0 NOT NULL,
      retailPrice REAL DEFAULT 0.0 NOT NULL,
      fittingCharge REAL DEFAULT 0.0 NOT NULL,
      note TEXT DEFAULT '' NOT NULL,
      outtOfStockFlag INTEGER DEFAULT 1 NOT NULL,
      flag INTEGER DEFAULT 1 NOT NULL
    );
  ''';

  static const String _createProductUnitsTable = '''
    CREATE TABLE ProductUnits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      productUnitId INTEGER NOT NULL UNIQUE,
      productId INTEGER DEFAULT -1 NOT NULL,
      baseUnitId INTEGER DEFAULT -1 NOT NULL,
      derivedUnitId INTEGER DEFAULT -1 NOT NULL,
      flag INTEGER DEFAULT 1 NOT NULL
    );
  ''';

  static const String _createProductCarTable = '''
    CREATE TABLE ProductCar (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      productCarId INTEGER NOT NULL UNIQUE,
      productId INTEGER DEFAULT -1 NOT NULL,
      carBrandId INTEGER DEFAULT -1 NOT NULL,
      carNameId INTEGER DEFAULT -1 NOT NULL,
      carModelId INTEGER DEFAULT -1 NOT NULL,
      carVersionId INTEGER DEFAULT -1 NOT NULL,
      flag INTEGER DEFAULT 1 NOT NULL
    );
  ''';

  static const String _createCarBrandTable = '''
    CREATE TABLE CarBrand(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      carBrandId INTEGER NOT NULL UNIQUE,
      name TEXT NOT NULL,
      flag INTEGER DEFAULT 1 NOT NULL
    );
  ''';

  static const String _createCarNameTable = '''
    CREATE TABLE CarName(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      carNameId INTEGER NOT NULL UNIQUE,
      carBrandId INTEGER NOT NULL,
      name TEXT NOT NULL,
      flag INTEGER DEFAULT 1 NOT NULL
    );
  ''';

  static const String _createCarModelTable = '''
    CREATE TABLE CarModel(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      carModelId INTEGER NOT NULL UNIQUE,
      carNameId INTEGER NOT NULL,
      carBrandId INTEGER NOT NULL,
      name TEXT NOT NULL,
      flag INTEGER DEFAULT 1 NOT NULL
    );
  ''';

  static const String _createCarVersionTable = '''
    CREATE TABLE CarVersion(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      carVersionId INTEGER NOT NULL UNIQUE,
      carNameId INTEGER NOT NULL,
      carBrandId INTEGER NOT NULL,
      carModelId INTEGER NOT NULL,
      name TEXT NOT NULL,
      flag INTEGER DEFAULT 1 NOT NULL
    );
  ''';

  static const String _createOrdersTable = '''
    CREATE TABLE Orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      orderId INTEGER NOT NULL UNIQUE,
      invoiceNo TEXT DEFAULT '' NOT NULL,
      UUID TEXT DEFAULT '' NOT NULL,
      customerId INTEGER DEFAULT -1 NOT NULL,
      customerName TEXT DEFAULT '' NOT NULL,
      salesmanId INTEGER DEFAULT -1 NOT NULL,
      storeKeeperId INTEGER DEFAULT -1 NOT NULL,
      billerId INTEGER DEFAULT -1 NOT NULL,
      checkerId INTEGER DEFAULT -1 NOT NULL,
      dateAndTime TEXT DEFAULT '' NOT NULL,
      note TEXT DEFAULT '' NOT NULL,
      total REAL DEFAULT 0.0 NOT NULL,
      freightCharge REAL DEFAULT 0.0 NOT NULL,
      approveFlag INTEGER DEFAULT 0 NOT NULL,
      createdDateTime TEXT DEFAULT '' NOT NULL,
      updatedDateTime TEXT DEFAULT '' NOT NULL,
      flag INTEGER DEFAULT 0 NOT NULL,
      isProcessFinish INTEGER DEFAULT 0 NOT NULL
    );
  ''';

  static const String _createOrderSubTable = '''
    CREATE TABLE OrderSub (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      orderSubId INTEGER NOT NULL UNIQUE,
      orderId INTEGER DEFAULT -1 NOT NULL,
      invoiceNo TEXT DEFAULT '' NOT NULL,
      UUID TEXT DEFAULT '' NOT NULL,
      customerId INTEGER DEFAULT -1 NOT NULL,
      salesmanId INTEGER DEFAULT -1 NOT NULL,
      storeKeeperId INTEGER DEFAULT -1 NOT NULL,
      dateAndTime TEXT DEFAULT '' NOT NULL,
      productId INTEGER DEFAULT -1 NOT NULL,
      unitId INTEGER DEFAULT -1 NOT NULL,
      carId INTEGER DEFAULT -1 NOT NULL,
      rate REAL DEFAULT 0.0 NOT NULL,
      updateRate REAL DEFAULT 0.0 NOT NULL,
      quantity REAL DEFAULT 0.0 NOT NULL,
      availQty REAL DEFAULT 0.0 NOT NULL,
      unitBaseQty REAL DEFAULT 0.0 NOT NULL,
      note TEXT DEFAULT '' NOT NULL,
      narration TEXT DEFAULT '' NOT NULL,
      orderFlag INTEGER DEFAULT 0 NOT NULL,
      createdDateTime TEXT DEFAULT '' NOT NULL,
      updatedDateTime TEXT DEFAULT '' NOT NULL,
      isCheckedflag INTEGER DEFAULT 0 NOT NULL,
      flag INTEGER DEFAULT 0 NOT NULL
    );
  ''';

  static const String _createOrderSubEditCacheTable = '''
    CREATE TABLE OrderSubEditCache (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      orderSubId INTEGER NOT NULL UNIQUE,
      orderId INTEGER DEFAULT -1 NOT NULL,
      invoiceNo TEXT DEFAULT '' NOT NULL,
      UUID TEXT DEFAULT '' NOT NULL,
      customerId INTEGER DEFAULT -1 NOT NULL,
      salesmanId INTEGER DEFAULT -1 NOT NULL,
      storeKeeperId INTEGER DEFAULT -1 NOT NULL,
      dateAndTime TEXT DEFAULT '' NOT NULL,
      productId INTEGER DEFAULT -1 NOT NULL,
      unitId INTEGER DEFAULT -1 NOT NULL,
      carId INTEGER DEFAULT -1 NOT NULL,
      rate REAL DEFAULT 0.0 NOT NULL,
      updateRate REAL DEFAULT 0.0 NOT NULL,
      quantity REAL DEFAULT 0.0 NOT NULL,
      availQty REAL DEFAULT 0.0 NOT NULL,
      unitBaseQty REAL DEFAULT 0.0 NOT NULL,
      note TEXT DEFAULT '' NOT NULL,
      narration TEXT DEFAULT '' NOT NULL,
      orderFlag INTEGER DEFAULT 0 NOT NULL,
      createdDateTime TEXT DEFAULT '' NOT NULL,
      updatedDateTime TEXT DEFAULT '' NOT NULL,
      isCheckedflag INTEGER DEFAULT 0 NOT NULL,
      flag INTEGER DEFAULT 0 NOT NULL
    );
  ''';

  static const String _createOrderSubSuggestionsTable = '''
    CREATE TABLE OrderSubSuggestions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sugId INTEGER NOT NULL UNIQUE,
      orderSubId INTEGER DEFAULT -1 NOT NULL,
      productId INTEGER DEFAULT -1 NOT NULL,
      price REAL DEFAULT 0.0 NOT NULL,
      note TEXT DEFAULT '' NOT NULL,
      flag INTEGER DEFAULT 0 NOT NULL
    );
  ''';

  static const String _createOutOfStockMasterTable = '''
    CREATE TABLE OutOfStockMaster (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      oospMasterId INTEGER NOT NULL UNIQUE,
      orderSubId INTEGER DEFAULT -1 NOT NULL,
      custId INTEGER DEFAULT -1 NOT NULL,
      salesmanId INTEGER DEFAULT -1 NOT NULL,
      storekeeperId INTEGER DEFAULT -1 NOT NULL,
      dateAndTime TEXT DEFAULT '' NOT NULL,
      productId INTEGER DEFAULT -1 NOT NULL,
      unitId INTEGER DEFAULT -1 NOT NULL,
      carId INTEGER DEFAULT -1 NOT NULL,
      qty REAL DEFAULT 0.0 NOT NULL,
      availQty REAL DEFAULT 0.0 NOT NULL,
      baseQty REAL DEFAULT 0.0 NOT NULL,
      note TEXT DEFAULT '' NOT NULL,
      narration TEXT DEFAULT '' NOT NULL,
      createdDateTime TEXT DEFAULT '' NOT NULL,
      updatedDateTime TEXT DEFAULT '' NOT NULL,
      isCompleteflag INTEGER DEFAULT 0 NOT NULL,
      flag INTEGER DEFAULT 0 NOT NULL,
      UUID TEXT DEFAULT '' NOT NULL,
      isViewed INTEGER DEFAULT 0 NOT NULL
    );
  ''';

  static const String _createOutOfStockProductsTable = '''
    CREATE TABLE OutOfStockProducts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      oospId INTEGER NOT NULL UNIQUE,
      oospMasterId INTEGER DEFAULT -1 NOT NULL,
      orderSubId INTEGER DEFAULT -1 NOT NULL,
      custId INTEGER DEFAULT -1 NOT NULL,
      salesmanId INTEGER DEFAULT -1 NOT NULL,
      storekeeperId INTEGER DEFAULT -1 NOT NULL,
      dateAndTime TEXT DEFAULT '' NOT NULL,
      supplierId INTEGER DEFAULT -1 NOT NULL,
      productId INTEGER DEFAULT -1 NOT NULL,
      unitId INTEGER DEFAULT -1 NOT NULL,
      carId INTEGER DEFAULT -1 NOT NULL,
      rate REAL DEFAULT 0.0 NOT NULL,
      updateRate REAL DEFAULT 0.0 NOT NULL,
      qty REAL DEFAULT 0.0 NOT NULL,
      availQty REAL DEFAULT 0.0 NOT NULL,
      baseQty REAL DEFAULT 0.0 NOT NULL,
      note TEXT DEFAULT '' NOT NULL,
      narration TEXT DEFAULT '' NOT NULL,
      oospFlag INTEGER DEFAULT 0 NOT NULL,
      createdDateTime TEXT DEFAULT '' NOT NULL,
      updatedDateTime TEXT DEFAULT '' NOT NULL,
      isCheckedflag INTEGER DEFAULT 0 NOT NULL,
      flag INTEGER DEFAULT 0 NOT NULL,
      UUID TEXT DEFAULT '' NOT NULL,
      isViewed INTEGER DEFAULT 0 NOT NULL
    );
  ''';

  static const String _createPackedSubsTable = '''
    CREATE TABLE PackedSubs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      orderSubId INTEGER NOT NULL UNIQUE,
      quantity REAL DEFAULT 0.0 NOT NULL
    );
  ''';

  // ============================================================================
  // MIGRATION FUNCTIONS
  // ============================================================================
  // These will be implemented based on the .sqm files
  // For now, creating placeholder functions

  Future<void> _migration1(Database db) async {
    // Migration 1: Initial Product table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Product (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL UNIQUE,
        code TEXT,
        barcode TEXT,
        name TEXT,
        brand TEXT,
        subBrand TEXT,
        categoryId INTEGER,
        subCategoryId INTEGER,
        defaultSuppId INTEGER,
        baseUnitId INTEGER,
        defaultUnitId INTEGER,
        photoUrl TEXT,
        price REAL,
        type INTEGER,
        outtOfStockFlag INTEGER DEFAULT 1,
        flag INTEGER DEFAULT 1
      );
    ''');
  }

  Future<void> _migration2(Database db) async {
    // Migration 2: Add Units table
    await db.execute(_createUnitsTable);
  }

  Future<void> _migration3(Database db) async {
    // Migration 3: Add Category, SubCategory, Car tables
    await db.execute(_createCategoryTable);
    await db.execute(_createSubCategoryTable);
    await db.execute(_createCarBrandTable);
    await db.execute(_createCarNameTable);
    await db.execute(_createCarModelTable);
    await db.execute(_createCarVersionTable);
  }

  Future<void> _migration4(Database db) async {
    // Migration 4: Add UsersCategory, Users, Customers, Suppliers, Routes
    await db.execute(_createUsersCategoryTable);
    await db.execute(_createUsersTable);
    await db.execute(_createCustomersTable);
    await db.execute(_createSuppliersTable);
    await db.execute(_createRoutesTable);
  }

  Future<void> _migration5(Database db) async {
    // Migration 5: Add userId to Suppliers, create SalesMan table
    await db.execute('ALTER TABLE Suppliers ADD userId INTEGER DEFAULT -1 NOT NULL;');
    await db.execute(_createSalesManTable);
  }

  Future<void> _migration6(Database db) async {
    // Migration 6: Drop and recreate Product table with new schema
    await db.execute('DROP TABLE IF EXISTS Product;');
    await db.execute(_createProductTable);
  }

  Future<void> _migration7(Database db) async {
    // Migration 7: Add Orders and OrderSub tables (without isProcessFinish, billerId, checkerId)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER NOT NULL UNIQUE,
        invoiceNo TEXT DEFAULT '' NOT NULL,
        UUID TEXT DEFAULT '' NOT NULL,
        customerId INTEGER DEFAULT -1 NOT NULL,
        customerName TEXT DEFAULT '' NOT NULL,
        salesmanId INTEGER DEFAULT -1 NOT NULL,
        storeKeeperId INTEGER DEFAULT -1 NOT NULL,
        billerId INTEGER DEFAULT -1 NOT NULL,
        checkerId INTEGER DEFAULT -1 NOT NULL,
        dateAndTime TEXT DEFAULT '' NOT NULL,
        note TEXT DEFAULT '' NOT NULL,
        total REAL DEFAULT 0.0 NOT NULL,
        freightCharge REAL DEFAULT 0.0 NOT NULL,
        approveFlag INTEGER DEFAULT 0 NOT NULL,
        createdDateTime TEXT DEFAULT '' NOT NULL,
        updatedDateTime TEXT DEFAULT '' NOT NULL,
        flag INTEGER DEFAULT 0 NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS OrderSub (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderSubId INTEGER NOT NULL UNIQUE,
        orderId INTEGER DEFAULT -1 NOT NULL,
        invoiceNo TEXT DEFAULT '' NOT NULL,
        UUID TEXT DEFAULT '' NOT NULL,
        customerId INTEGER DEFAULT -1 NOT NULL,
        salesmanId INTEGER DEFAULT -1 NOT NULL,
        storeKeeperId INTEGER DEFAULT -1 NOT NULL,
        dateAndTime TEXT DEFAULT '' NOT NULL,
        productId INTEGER DEFAULT -1 NOT NULL,
        unitId INTEGER DEFAULT -1 NOT NULL,
        carId INTEGER DEFAULT -1 NOT NULL,
        rate REAL DEFAULT 0.0 NOT NULL,
        updateRate REAL DEFAULT 0.0 NOT NULL,
        quantity REAL DEFAULT 0.0 NOT NULL,
        unitBaseQty REAL DEFAULT 0.0 NOT NULL,
        note TEXT DEFAULT '' NOT NULL,
        orderFlag INTEGER DEFAULT 0 NOT NULL,
        createdDateTime TEXT DEFAULT '' NOT NULL,
        updatedDateTime TEXT DEFAULT '' NOT NULL,
        isCheckedflag INTEGER DEFAULT 0 NOT NULL,
        flag INTEGER DEFAULT 0 NOT NULL
      );
    ''');
  }

  Future<void> _migration8(Database db) async {
    // Migration 8: Add ProductCar table
    await db.execute(_createProductCarTable);
  }

  Future<void> _migration9(Database db) async {
    // Migration 9: Add ProductUnits table
    await db.execute(_createProductUnitsTable);
  }

  Future<void> _migration10(Database db) async {
    // Migration 10: Add OrderSubSuggestions and OutOfStockProducts tables
    await db.execute('''
      CREATE TABLE IF NOT EXISTS OrderSubSuggestions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sugId INTEGER NOT NULL UNIQUE,
        orderSubId INTEGER DEFAULT -1 NOT NULL,
        productId INTEGER DEFAULT -1 NOT NULL,
        price REAL DEFAULT 0.0 NOT NULL,
        flag INTEGER DEFAULT 0 NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS OutOfStockProducts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        oospId INTEGER NOT NULL UNIQUE,
        orderSubId INTEGER DEFAULT -1 NOT NULL,
        custId INTEGER DEFAULT -1 NOT NULL,
        salesmanId INTEGER DEFAULT -1 NOT NULL,
        storekeeperId INTEGER DEFAULT -1 NOT NULL,
        dateAndTime TEXT DEFAULT '' NOT NULL,
        supplierId INTEGER DEFAULT -1 NOT NULL,
        productId INTEGER DEFAULT -1 NOT NULL,
        unitId INTEGER DEFAULT -1 NOT NULL,
        carId INTEGER DEFAULT -1 NOT NULL,
        rate REAL DEFAULT 0.0 NOT NULL,
        updateRate REAL DEFAULT 0.0 NOT NULL,
        qty REAL DEFAULT 0.0 NOT NULL,
        availQty REAL DEFAULT 0.0 NOT NULL,
        baseQty REAL DEFAULT 0.0 NOT NULL,
        note TEXT DEFAULT '' NOT NULL,
        oospFlag TEXT DEFAULT 0 NOT NULL,
        createdDateTime TEXT DEFAULT '' NOT NULL,
        updatedDateTime TEXT DEFAULT '' NOT NULL,
        isCheckedflag INTEGER DEFAULT 0 NOT NULL,
        flag INTEGER DEFAULT 0 NOT NULL
      );
    ''');
    await db.execute('ALTER TABLE OrderSub ADD availQty REAL DEFAULT 0.0 NOT NULL;');
  }

  Future<void> _migration11(Database db) async {
    // Migration 11: Add note to OrderSubSuggestions
    await db.execute('ALTER TABLE OrderSubSuggestions ADD note TEXT DEFAULT \'\' NOT NULL;');
  }

  Future<void> _migration12(Database db) async {
    // Migration 12: Change isCheckedflag type in OrderSub (SQLite doesn't support DROP COLUMN)
    // We need to recreate the table with the correct type
    await db.execute('''
      CREATE TABLE OrderSub_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderSubId INTEGER NOT NULL UNIQUE,
        orderId INTEGER DEFAULT -1 NOT NULL,
        invoiceNo TEXT DEFAULT '' NOT NULL,
        UUID TEXT DEFAULT '' NOT NULL,
        customerId INTEGER DEFAULT -1 NOT NULL,
        salesmanId INTEGER DEFAULT -1 NOT NULL,
        storeKeeperId INTEGER DEFAULT -1 NOT NULL,
        dateAndTime TEXT DEFAULT '' NOT NULL,
        productId INTEGER DEFAULT -1 NOT NULL,
        unitId INTEGER DEFAULT -1 NOT NULL,
        carId INTEGER DEFAULT -1 NOT NULL,
        rate REAL DEFAULT 0.0 NOT NULL,
        updateRate REAL DEFAULT 0.0 NOT NULL,
        quantity REAL DEFAULT 0.0 NOT NULL,
        availQty REAL DEFAULT 0.0 NOT NULL,
        unitBaseQty REAL DEFAULT 0.0 NOT NULL,
        note TEXT DEFAULT '' NOT NULL,
        orderFlag INTEGER DEFAULT 0 NOT NULL,
        createdDateTime TEXT DEFAULT '' NOT NULL,
        updatedDateTime TEXT DEFAULT '' NOT NULL,
        isCheckedflag INTEGER DEFAULT 0 NOT NULL,
        flag INTEGER DEFAULT 0 NOT NULL
      );
    ''');
    await db.execute('''
      INSERT INTO OrderSub_new 
      SELECT id, orderSubId, orderId, invoiceNo, UUID, customerId, salesmanId, storeKeeperId,
             dateAndTime, productId, unitId, carId, rate, updateRate, quantity, availQty,
             unitBaseQty, note, orderFlag, createdDateTime, updatedDateTime,
             CAST(isCheckedflag AS INTEGER), flag
      FROM OrderSub;
    ''');
    await db.execute('DROP TABLE OrderSub;');
    await db.execute('ALTER TABLE OrderSub_new RENAME TO OrderSub;');
  }

  Future<void> _migration13(Database db) async {
    // Migration 13: Drop and recreate OutOfStockProducts with correct oospFlag type
    await db.execute('DROP TABLE IF EXISTS OutOfStockProducts;');
    await db.execute('''
      CREATE TABLE OutOfStockProducts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        oospId INTEGER NOT NULL UNIQUE,
        orderSubId INTEGER DEFAULT -1 NOT NULL,
        custId INTEGER DEFAULT -1 NOT NULL,
        salesmanId INTEGER DEFAULT -1 NOT NULL,
        storekeeperId INTEGER DEFAULT -1 NOT NULL,
        dateAndTime TEXT DEFAULT '' NOT NULL,
        supplierId INTEGER DEFAULT -1 NOT NULL,
        productId INTEGER DEFAULT -1 NOT NULL,
        unitId INTEGER DEFAULT -1 NOT NULL,
        carId INTEGER DEFAULT -1 NOT NULL,
        rate REAL DEFAULT 0.0 NOT NULL,
        updateRate REAL DEFAULT 0.0 NOT NULL,
        qty REAL DEFAULT 0.0 NOT NULL,
        availQty REAL DEFAULT 0.0 NOT NULL,
        baseQty REAL DEFAULT 0.0 NOT NULL,
        note TEXT DEFAULT '' NOT NULL,
        oospFlag INTEGER DEFAULT 0 NOT NULL,
        createdDateTime TEXT DEFAULT '' NOT NULL,
        updatedDateTime TEXT DEFAULT '' NOT NULL,
        isCheckedflag INTEGER DEFAULT 0 NOT NULL,
        flag INTEGER DEFAULT 0 NOT NULL
      );
    ''');
  }

  Future<void> _migration14(Database db) async {
    // Migration 14: Add OutOfStockMaster and recreate OutOfStockProducts with oospMasterId
    await db.execute('''
      CREATE TABLE IF NOT EXISTS OutOfStockMaster (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        oospMasterId INTEGER NOT NULL UNIQUE,
        orderSubId INTEGER DEFAULT -1 NOT NULL,
        custId INTEGER DEFAULT -1 NOT NULL,
        salesmanId INTEGER DEFAULT -1 NOT NULL,
        storekeeperId INTEGER DEFAULT -1 NOT NULL,
        dateAndTime TEXT DEFAULT '' NOT NULL,
        productId INTEGER DEFAULT -1 NOT NULL,
        unitId INTEGER DEFAULT -1 NOT NULL,
        carId INTEGER DEFAULT -1 NOT NULL,
        qty REAL DEFAULT 0.0 NOT NULL,
        availQty REAL DEFAULT 0.0 NOT NULL,
        baseQty REAL DEFAULT 0.0 NOT NULL,
        note TEXT DEFAULT '' NOT NULL,
        createdDateTime TEXT DEFAULT '' NOT NULL,
        updatedDateTime TEXT DEFAULT '' NOT NULL,
        isCompleteflag INTEGER DEFAULT 0 NOT NULL,
        flag INTEGER DEFAULT 0 NOT NULL
      );
    ''');
    await db.execute('DROP TABLE IF EXISTS OutOfStockProducts;');
    await db.execute('''
      CREATE TABLE OutOfStockProducts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        oospId INTEGER NOT NULL UNIQUE,
        orderSubId INTEGER DEFAULT -1 NOT NULL,
        custId INTEGER DEFAULT -1 NOT NULL,
        salesmanId INTEGER DEFAULT -1 NOT NULL,
        storekeeperId INTEGER DEFAULT -1 NOT NULL,
        dateAndTime TEXT DEFAULT '' NOT NULL,
        supplierId INTEGER DEFAULT -1 NOT NULL,
        productId INTEGER DEFAULT -1 NOT NULL,
        unitId INTEGER DEFAULT -1 NOT NULL,
        carId INTEGER DEFAULT -1 NOT NULL,
        rate REAL DEFAULT 0.0 NOT NULL,
        updateRate REAL DEFAULT 0.0 NOT NULL,
        qty REAL DEFAULT 0.0 NOT NULL,
        availQty REAL DEFAULT 0.0 NOT NULL,
        baseQty REAL DEFAULT 0.0 NOT NULL,
        note TEXT DEFAULT '' NOT NULL,
        oospFlag INTEGER DEFAULT 0 NOT NULL,
        createdDateTime TEXT DEFAULT '' NOT NULL,
        updatedDateTime TEXT DEFAULT '' NOT NULL,
        isCheckedflag INTEGER DEFAULT 0 NOT NULL,
        flag INTEGER DEFAULT 0 NOT NULL
      );
    ''');
  }

  Future<void> _migration15(Database db) async {
    // Migration 15: Add oospMasterId to OutOfStockProducts
    await db.execute('ALTER TABLE OutOfStockProducts ADD oospMasterId INTEGER DEFAULT -1 NOT NULL;');
  }

  Future<void> _migration16(Database db) async {
    // Migration 16: Add FailedSync table
    await db.execute(_createFailedSyncTable);
  }

  Future<void> _migration17(Database db) async {
    // Migration 17: Add isProcessFinish to Orders
    await db.execute('ALTER TABLE Orders ADD isProcessFinish INTEGER DEFAULT 0 NOT NULL;');
  }

  Future<void> _migration18(Database db) async {
    // Migration 18: Add address to Users
    await db.execute('ALTER TABLE Users ADD address TEXT DEFAULT \'\' NOT NULL;');
  }

  Future<void> _migration19(Database db) async {
    // Migration 19: Add isViewed to OutOfStockMaster and OutOfStockProducts
    await db.execute('ALTER TABLE OutOfStockMaster ADD isViewed INTEGER DEFAULT 0 NOT NULL;');
    await db.execute('ALTER TABLE OutOfStockProducts ADD isViewed INTEGER DEFAULT 0 NOT NULL;');
  }

  Future<void> _migration20(Database db) async {
    // Migration 20: Add SyncTime table
    await db.execute(_createSyncTimeTable);
  }

  Future<void> _migration21(Database db) async {
    // Migration 21: Add PackedSubs table and narration/UUID columns
    await db.execute(_createPackedSubsTable);
    await db.execute('ALTER TABLE OrderSub ADD narration TEXT DEFAULT \'\' NOT NULL;');
    await db.execute('ALTER TABLE OutOfStockProducts ADD narration TEXT DEFAULT \'\' NOT NULL;');
    await db.execute('ALTER TABLE OutOfStockProducts ADD UUID TEXT DEFAULT \'\' NOT NULL;');
    await db.execute('ALTER TABLE OutOfStockMaster ADD narration TEXT DEFAULT \'\' NOT NULL;');
    await db.execute('ALTER TABLE OutOfStockMaster ADD UUID TEXT DEFAULT \'\' NOT NULL;');
  }

  Future<void> _migration22(Database db) async {
    // Migration 22: Add OrderSubEditCache table
    await db.execute(_createOrderSubEditCacheTable);
  }

  /// Close database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

