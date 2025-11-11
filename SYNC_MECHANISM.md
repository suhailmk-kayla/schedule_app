# Sync Mechanism Explanation

## Overview
This app uses an **offline-first architecture** where all data is stored locally and sync happens separately from regular operations.

---

## 🔄 How Data Flow Works

### 1. **READ Operations (Display Data)**
```
User Opens Screen
    ↓
Provider calls Repository.getAllProducts()
    ↓
Repository reads from LOCAL DATABASE (sqflite)
    ↓
Data displayed to user
```

**Key Points:**
- ✅ **Always reads from local DB first** - No API calls for displaying data
- ✅ **Works offline** - App functions even without internet
- ✅ **Fast** - No network latency for reads
- ✅ **All queries work on local DB** - Search, filter, get by ID, etc.

**Example:**
```dart
// ProductsProvider.loadProducts() calls:
final result = await _productsRepository.getAllProducts(searchKey: searchKey);
// This reads from local SQLite database, NOT from API
```

---

### 2. **SYNC Operations (Download Fresh Data)**
```
User Triggers Sync (or scheduled sync)
    ↓
SyncProvider.startSync()
    ↓
For each table (Products, Categories, Orders, etc.):
    ├─ Download batch 1 (offset=0, limit=500) from API
    ├─ Store in local DB (INSERT OR REPLACE)
    ├─ Download batch 2 (offset=500, limit=500) from API
    ├─ Store in local DB
    ├─ ... continues until empty response
    └─ Update SyncTime table with last sync date
    ↓
Move to next table
```

**Key Points:**
- ✅ **Separate from regular reads** - Sync doesn't block UI
- ✅ **Batch downloading** - 500 items per batch
- ✅ **Replaces all data** - Uses `INSERT OR REPLACE` to update local DB
- ✅ **Tracks sync time** - Stores last sync date in `SyncTime` table
- ✅ **Sequential** - Syncs tables one by one in order

**Example:**
```dart
// SyncProvider downloads products:
1. Call API: GET /api/products/download?offset=0&limit=500
2. Receive 500 products
3. Store in local DB (replaces existing)
4. Call API: GET /api/products/download?offset=500&limit=500
5. Receive 500 more products
6. Store in local DB
7. Continue until API returns empty array
8. Update SyncTime table: "Product" -> "2024-01-15 10:30:00"
```

---

### 3. **WRITE Operations (Create/Update)**
```
User Creates/Updates Product
    ↓
Provider calls Repository.createProduct()
    ↓
1. Call API: POST /api/products/add
    ↓
2. API returns created/updated product
    ↓
3. Store in local DB (INSERT OR REPLACE)
    ↓
Done - Local DB now has fresh data
```

**Key Points:**
- ✅ **API first** - Always calls API before updating local DB
- ✅ **Updates local DB** - Keeps local DB in sync with server
- ✅ **Optimistic updates** - Local DB updated immediately after API success

**Example:**
```dart
// ProductsProvider.createProduct() calls:
1. await _productsRepository.createProduct(product)
   ├─ Calls API: POST /api/products/add
   ├─ Receives created product from API
   └─ Stores in local DB
2. loadProducts() // Reloads from local DB (now has new product)
```

---

## 📊 SyncTime Table - How We Track Fresh Data

### What is SyncTime?
The `SyncTime` table stores the **last sync date** for each table:

| table_name | update_date |
|------------|-------------|
| Product | 2024-01-15 10:30:00 |
| Category | 2024-01-15 10:31:00 |
| Orders | 2024-01-15 10:32:00 |

### How It Works:
1. **After successful sync**, we store the `updated_date` from API response
2. **This date comes from the server** - It's the server's timestamp of when data was last updated
3. **We can use this to check if sync is needed** (future enhancement)

**Current Implementation:**
- ✅ Sync always downloads **all data** (doesn't check if stale)
- ✅ Uses `INSERT OR REPLACE` - Replaces old data with new
- ✅ SyncTime is stored for tracking purposes

**Future Enhancement (Not Currently Implemented):**
```dart
// Could check if sync is needed:
final syncTime = await syncTimeRepository.getSyncTime('Product');
if (syncTime != null) {
  // Check if server has newer data
  // Only sync if needed
}
```

---

## 🔄 How to Keep Data Fresh

### Current Approach (Full Sync):
1. **Manual Sync**: User taps "Sync" button → Downloads all data
2. **Scheduled Sync**: Background task syncs periodically
3. **Full Replacement**: All data is downloaded and replaced

### Sync Process:
```
startSync()
  ↓
Download Products (all batches)
  ↓
Download Categories (all batches)
  ↓
Download Orders (all batches)
  ↓
... continues for all tables
  ↓
All data is now fresh in local DB
```

### When to Sync:
- ✅ **On app launch** (optional - check if first time)
- ✅ **Manual sync** (user-triggered)
- ✅ **Background sync** (scheduled, e.g., every hour)
- ✅ **After login** (to get latest data)
- ✅ **Pull to refresh** (user-triggered)

---

## 🚫 What We DON'T Do

### ❌ We DON'T:
1. **Check local DB first, then API if fails** - We always read from local DB
2. **Compare sync times before syncing** - We download everything
3. **Incremental sync** - We replace all data, not just changes
4. **Real-time sync** - Sync is manual/scheduled, not automatic

### ✅ What We DO:
1. **Always read from local DB** - UI never waits for API
2. **Full sync replaces all data** - Ensures consistency
3. **Track sync times** - For future enhancements
4. **Handle failed syncs** - Stores in `FailedSync` table for retry

---

## 📝 Summary

### Data Flow Diagram:
```
┌─────────────────────────────────────────────────────────┐
│                    USER INTERACTION                     │
└─────────────────────────────────────────────────────────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
        ▼                               ▼
┌───────────────┐              ┌───────────────┐
│   READ DATA   │              │  WRITE DATA   │
│  (Display)    │              │ (Create/Edit) │
└───────────────┘              └───────────────┘
        │                               │
        │                               │
        ▼                               ▼
┌───────────────┐              ┌───────────────┐
│  LOCAL DB     │              │  API CALL     │
│  (sqflite)    │              │  (dio)        │
└───────────────┘              └───────────────┘
                                        │
                                        ▼
                                ┌───────────────┐
                                │  LOCAL DB     │
                                │  (Update)     │
                                └───────────────┘

┌─────────────────────────────────────────────────────────┐
│                    SYNC OPERATION                        │
│  (Separate from regular reads/writes)                   │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
                ┌───────────────┐
                │  API CALL     │
                │  (Batch 500)  │
                └───────────────┘
                        │
                        ▼
                ┌───────────────┐
                │  LOCAL DB     │
                │  (Replace)    │
                └───────────────┘
                        │
                        ▼
                ┌───────────────┐
                │  SyncTime     │
                │  (Update)     │
                └───────────────┘
```

### Key Takeaways:
1. **UI always reads from local DB** - Fast, offline-capable
2. **Sync is separate** - Downloads fresh data in batches
3. **Writes go API → Local** - Keeps local DB in sync
4. **Full replacement sync** - Ensures data consistency
5. **SyncTime tracking** - For future incremental sync support

---

## 🔍 Example Scenarios

### Scenario 1: User Opens Products Screen
```
1. ProductsProvider.loadProducts() called
2. Repository.getAllProducts() reads from LOCAL DB
3. Products displayed immediately (no API call)
4. User sees data instantly (even offline)
```

### Scenario 2: User Creates New Product
```
1. ProductsProvider.createProduct() called
2. Repository.createProduct() calls API: POST /api/products/add
3. API returns created product
4. Repository stores in LOCAL DB
5. Provider reloads products from LOCAL DB
6. User sees new product in list
```

### Scenario 3: User Triggers Sync
```
1. SyncProvider.startSync() called
2. Downloads Products (batches of 500)
3. Stores in LOCAL DB (replaces old data)
4. Updates SyncTime table
5. Moves to next table (Categories)
6. Continues until all tables synced
7. All data is now fresh in LOCAL DB
```

### Scenario 4: User Uses App Offline
```
1. All reads work from LOCAL DB ✅
2. Writes fail (no API) ❌
3. User can view/search/filter all data ✅
4. When online, sync updates local DB ✅
```

---

## 💡 Future Enhancements (Not Currently Implemented)

1. **Incremental Sync**: Only download data changed since last sync
2. **Smart Sync**: Check SyncTime before syncing
3. **Background Sync**: Automatic periodic sync
4. **Conflict Resolution**: Handle conflicts when offline edits exist
5. **Delta Sync**: Only download changed records, not all data

