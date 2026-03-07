# Sync Flow Documentation

## Overview

The sync mechanism in this application uses a **recursive batch pagination pattern** to download data from the server in chunks of 500 items per request. The system sequentially processes each table, downloading all data in batches before moving to the next table.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Components](#core-components)
3. [Recursive Flow Pattern](#recursive-flow-pattern)
4. [Batch Pagination Mechanism](#batch-pagination-mechanism)
5. [State Management](#state-management)
6. [Complete Flow Example](#complete-flow-example)
7. [Error Handling](#error-handling)
8. [Termination Conditions](#termination-conditions)

---

## Architecture Overview

### Entry Point

```dart
Future<void> startSync() async {
  _isSyncing = true;
  _isStopped = false;
  await _startSyncDatabase(); // Recursive orchestrator
}
```

### Core Orchestrator

The `_startSyncDatabase()` method acts as the recursive coordinator that:
- Checks which table needs syncing (using boolean flags like `_isProductDownloaded`)
- Calls the appropriate `_download*()` method for that table
- Each download method calls `_startSyncDatabase()` again when done (recursive)

---

## Core Components

### 1. State Variables

#### Part Number Counters (One per table)
Each table has its own part number counter that tracks the current batch index:

```dart
int _productPart = 0;
int _categoryPart = 0;
int _subCategoryPart = 0;
int _orderPart = 0;
int _orderSubPart = 0;
int _orderSubSuggestionPart = 0;
int _outOfStockPart = 0;
int _outOfStockSubPart = 0;
int _customerPart = 0;
int _userPart = 0;
int _salesmanPart = 0;
int _supplierPart = 0;
int _routesPart = 0;
int _unitsPart = 0;
int _productUnitsPart = 0;
int _productCarPart = 0;
int _userCategoryPart = 0;
int _carBrandPart = 0;
int _carNamePart = 0;
int _carModelPart = 0;
int _carVersionPart = 0;
```

#### Completion Flags (One per table)
Boolean flags track whether each table has been fully downloaded:

```dart
bool _isProductDownloaded = false;
bool _isCategoryDownloaded = false;
bool _isSubCategoryDownloaded = false;
bool _isOrderDownloaded = false;
// ... etc for each table
```

#### Constants

```dart
static const int _limit = 500;  // Batch size - fixed at 500 items per request
```

### 2. Table Processing Order

The sync processes tables in a specific order (defined in `_startSyncDatabase()`):

1. Product
2. CarBrand
3. CarName
4. CarModel
5. CarVersion
6. Category
7. SubCategory
8. Orders (if userType != 4)
9. OrderSubs (if userType != 4)
10. OrderSubSuggestions (if userType != 4)
11. OutOfStock (if userType == 1 || userType == 4)
12. OutOfStockSub (if userType == 1 || userType == 2 || userType == 4)
13. Customers (if userType != 4)
14. Users
15. Salesmen (if userType != 4)
16. Suppliers (if userType != 4)
17. Routes
18. Units
19. ProductUnits
20. ProductCar
21. UserCategories

---

## Recursive Flow Pattern

### How Recursion Works

The sync uses recursion to:
1. **Download one batch** from the current table
2. **Save to local database**
3. **Increment part number**
4. **Call itself again** to download the next batch
5. **Repeat until empty response**, then move to next table

### Flow Diagram

```
_startSyncDatabase()
    ↓
Check: _isProductDownloaded? NO
    ↓
_downloadProducts(partNo: 0)
    ↓
API: GET products?part_no=0&limit=500
    ↓
Response: [500 products]
    ↓
Save to DB → _productPart++ (now 1)
    ↓
_startSyncDatabase() ← RECURSIVE CALL
    ↓
Check: _isProductDownloaded? NO (still downloading)
    ↓
_downloadProducts(partNo: 1)
    ↓
API: GET products?part_no=1&limit=500
    ↓
Response: [500 products]
    ↓
Save to DB → _productPart++ (now 2)
    ↓
_startSyncDatabase() ← RECURSIVE CALL
    ↓
... (continues until empty response)
    ↓
Response: [] (empty - all data downloaded)
    ↓
_isProductDownloaded = true
_productPart = 0 (reset)
    ↓
_startSyncDatabase() ← RECURSIVE CALL
    ↓
Check: _isProductDownloaded? YES
Check: _isCategoryDownloaded? NO
    ↓
_downloadCategory(partNo: 0)
    ↓
... (same pattern for categories)
```

---

## Batch Pagination Mechanism

### Part Number Purpose

The **part number** (`partNo`) represents the batch/page index:
- **Part 0**: Items 0-499 (first 500 items)
- **Part 1**: Items 500-999 (next 500 items)
- **Part 2**: Items 1000-1499 (next 500 items)
- **Part N**: Items (N*500) to ((N+1)*500 - 1

### Example: Category Download

#### Step 1: Initial Call
```dart
_downloadCategory() {
  partNo: _categoryPart = 0  // Start at part 0
  limit: 500                  // Request 500 items
}
```

#### Step 2: API Request
```
GET /api/category_downloads?
  part_no=0&
  limit=500&
  user_type=1&
  user_id=123&
  update_date=2024-01-01
```

#### Step 3: Response Handling

**Scenario A: Data Received (Non-Empty List)**
```dart
if (categories.isNotEmpty) {
  // 1. Save to local DB
  await _categoriesRepository.addCategories(categories);
  
  // 2. Increment part number for next batch
  _categoryPart++;  // Now becomes 1
  
  // 3. RECURSIVE CALL - Download next batch
  _startSyncDatabase();  // ← Calls itself again!
}
```

**Scenario B: Empty List (All Data Downloaded)**
```dart
if (categories.isEmpty) {
  // 1. Mark table as complete
  _isCategoryDownloaded = true;
  
  // 2. Reset part number for next full sync
  _categoryPart = 0;
  
  // 3. Save sync time (fire-and-forget)
  _syncTimeRepository.addSyncTime(
    tableName: 'Category',
    updateDate: categoryListApi.updatedDate,
  );
  
  // 4. RECURSIVE CALL - Move to next table
  _startSyncDatabase();  // ← Moves to next table!
}
```

### Increment Logic

```dart
// In _downloadCategory() or any _download*() method:
if (data.isNotEmpty) {
  await repository.addData(data);  // Save batch to DB
  _tablePart++;                    // Increment for next batch
  _startSyncDatabase();            // Recursive call
}
```

### Reset Logic

```dart
if (data.isEmpty) {
  _isTableDownloaded = true;  // Mark as complete
  _tablePart = 0;              // Reset for next full sync
  _startSyncDatabase();        // Move to next table
}
```

---

## State Management

### Initial State (Before Sync)

```dart
// All part numbers start at 0
_categoryPart = 0
_subCategoryPart = 0
// ... etc

// All completion flags are false
_isCategoryDownloaded = false
_isSubCategoryDownloaded = false
// ... etc

_isSyncing = false
_isStopped = false
```

### During Sync

```dart
_isSyncing = true
_isStopped = false

// Part numbers increment as batches are downloaded
_categoryPart = 0 → 1 → 2 → 3 → ...

// Completion flags change to true when table is done
_isCategoryDownloaded = false → true
```

### After Sync

```dart
_isSyncing = false
// All completion flags = true
// All part numbers = 0 (reset)
```

---

## Complete Flow Example

### Category Sync (Step-by-Step)

#### Initial State
```dart
_categoryPart = 0
_isCategoryDownloaded = false
```

#### Iteration 1
```dart
_downloadCategory(partNo: 0)
  → API Request: GET categories?part_no=0&limit=500
  → API Response: [500 categories]
  → Save to DB: await addCategories([500 items])
  → Increment: _categoryPart = 1
  → Recursive: _startSyncDatabase()
```

#### Iteration 2
```dart
_downloadCategory(partNo: 1)
  → API Request: GET categories?part_no=1&limit=500
  → API Response: [500 categories]
  → Save to DB: await addCategories([500 items])
  → Increment: _categoryPart = 2
  → Recursive: _startSyncDatabase()
```

#### Iteration 3
```dart
_downloadCategory(partNo: 2)
  → API Request: GET categories?part_no=2&limit=500
  → API Response: [200 categories] (last batch - partial)
  → Save to DB: await addCategories([200 items])
  → Increment: _categoryPart = 3
  → Recursive: _startSyncDatabase()
```

#### Iteration 4 (Termination)
```dart
_downloadCategory(partNo: 3)
  → API Request: GET categories?part_no=3&limit=500
  → API Response: [] (empty - done!)
  → Mark Complete: _isCategoryDownloaded = true
  → Reset: _categoryPart = 0
  → Save Sync Time: addSyncTime('Category', updatedDate)
  → Recursive: _startSyncDatabase() (moves to SubCategory)
```

### Full Sync Sequence

```
1. Products (part 0, 1, 2, ... until empty)
2. CarBrand (part 0, 1, 2, ... until empty)
3. CarName (part 0, 1, 2, ... until empty)
4. CarModel (part 0, 1, 2, ... until empty)
5. CarVersion (part 0, 1, 2, ... until empty)
6. Category (part 0, 1, 2, ... until empty)
7. SubCategory (part 0, 1, 2, ... until empty)
8. Orders (if applicable)
9. OrderSubs (if applicable)
... (continues through all tables)
```

---

## Error Handling

### Error Scenarios

#### 1. Network Error During Batch Download

```dart
result.fold(
  (failure) {
    if (id == -1) {  // Full sync mode
      _updateError(failure.message, true);
      _isSyncing = false;
      notifyListeners();
      // Sync stops - user can retry
    } else {  // Retry mode
      // Create FailedSync entry for later retry
      _failedSyncRepository.addFailedSync(
        tableId: NotificationId.CATEGORY,
        dataId: id,
      );
    }
  },
  (success) { /* ... */ }
);
```

#### 2. Database Error During Save

```dart
final addResult = await _categoriesRepository.addCategories(categories);
addResult.fold(
  (failure) {
    developer.log('Failed to add categories: ${failure.message}');
    _updateError('Failed to save categories: ${failure.message}', true);
    _isSyncing = false;
    notifyListeners();
    // Sync stops - prevents data corruption
  },
  (_) { /* Success - continue */ }
);
```

#### 3. User Stops Sync

```dart
Future<void> _startSyncDatabase() async {
  if (_isStopped) {
    _isSyncing = false;
    notifyListeners();
    return;  // Exit recursion
  }
  // ... continue sync
}
```

### Failed Sync Tracking

When a single record retry fails, it's stored in the `FailedSync` table:

```dart
await _failedSyncRepository.addFailedSync(
  tableId: 6,      // NotificationId.CATEGORY
  dataId: categoryId,  // The specific record ID that failed
);
```

These can be retried later using `syncFailedSyncs()`.

---

## Termination Conditions

The recursion stops when one of these conditions is met:

### 1. All Tables Downloaded (Success)

```dart
if (all tables have _is*Downloaded == true) {
  _isSyncing = false;
  _progress = 1.0;
  _currentTask = 'Sync completed';
  notifyListeners();
  // Recursion ends here
}
```

### 2. Error Occurs

```dart
catch (e, stackTrace) {
  _updateError('Database sync error: ${e.toString()}', true);
  _isSyncing = false;
  notifyListeners();
  // Recursion stops
}
```

### 3. User Stops Sync

```dart
if (_isStopped) {
  _isSyncing = false;
  notifyListeners();
  return;  // Exit recursion
}
```

---

## Why Recursive?

### Benefits

1. **Sequential Execution**: One batch at a time, no race conditions
2. **Simple State Management**: Part numbers and flags naturally track progress
3. **Automatic Progression**: Empty response automatically moves to next table
4. **Error Handling**: Errors naturally stop the chain without corrupting state
5. **Clean Code**: No complex loop management or callback chains

### Alternative Approaches (Not Used)

- **Parallel Batches**: Complex, risk of race conditions, harder to debug
- **Loop-Based**: Requires complex state management across iterations
- **Callback Chains**: Harder to read and maintain, callback hell

---

## Key Implementation Details

### 1. Sync Time Tracking

Each table stores its last sync time:

```dart
_syncTimeRepository.addSyncTime(
  tableName: 'Category',
  updateDate: categoryListApi.updatedDate,
);
```

This is used in subsequent syncs to only download updated records.

### 2. User Type Filtering

Some tables are skipped based on user type:

```dart
if (!_isOrderDownloaded && userType != 4) {
  await _downloadOrders();
}
```

- `userType == 4` (Supplier): Skips Orders, OrderSubs, Customers, etc.
- `userType == 5` (Biller): Downloads all tables

### 3. Fire-and-Forget Pattern

Sync time writes are fire-and-forget (non-blocking):

```dart
_syncTimeRepository.addSyncTime(...).then((result) {
  result.fold(
    (failure) => developer.log('Failed to add sync time'),
    (_) {},
  );
});
```

This prevents blocking the sync chain if sync time write fails.

### 4. Progress Tracking

Progress is updated after each batch:

```dart
_updateProgress();  // Calculates progress based on completed tables
```

---

## API Request Format

### Full Sync Mode (id == -1)

```
GET /api/{table}_downloads?
  part_no={currentPart}&
  limit=500&
  user_type={userType}&
  user_id={userId}&
  update_date={lastSyncDate}
```

### Single Record Retry Mode (id != -1)

```
GET /api/{table}_downloads?
  id={recordId}
```

---

## Database Operations

### Insert/Update Pattern

The repository uses a check-then-insert-or-update pattern:

```dart
// Check if record exists by server ID
final existing = await db.query(
  'Category',
  where: 'categoryId = ?',
  whereArgs: [category.categoryId],
  limit: 1,
);

if (existing.isEmpty) {
  // INSERT - don't include 'id' column (auto-increment)
  await db.insert('Category', category.toMap());
} else {
  // UPDATE - use server ID for WHERE clause
  await db.update(
    'Category',
    category.toMap(),
    where: 'categoryId = ?',
    whereArgs: [category.categoryId],
  );
}
```

This ensures:
- No duplicate records
- Updates existing records instead of creating duplicates
- Proper handling of server ID vs local DB primary key

---

## Summary

The sync mechanism uses a **recursive batch pagination pattern** where:

1. ✅ **Recursive**: `_startSyncDatabase()` calls itself after each batch
2. ✅ **Part Number Increments**: `_categoryPart++` after each successful batch
3. ✅ **Empty Response = Done**: Empty list signals completion and moves to next table
4. ✅ **Sequential**: One batch at a time, no parallel downloads
5. ✅ **State-Driven**: Boolean flags and part numbers control the flow
6. ✅ **Error-Safe**: Errors stop the chain without corrupting state

This pattern ensures reliable, sequential batch downloading with clear state management and automatic progression through all tables.

---

## Related Files

- **Sync Provider**: `lib/presentation/provider/sync_provider.dart`
- **Repositories**: `lib/repositories/{table}/{table}_repository.dart`
- **Models**: `lib/models/{table}_api.dart`
- **API Endpoints**: `lib/utils/api_endpoints.dart`

---

## Notes

- Batch size is fixed at **500 items** per request
- Sync time is stored per table for incremental syncs
- User type determines which tables are synced
- Failed individual records are tracked in `FailedSync` table
- All database operations use transactions for data integrity

