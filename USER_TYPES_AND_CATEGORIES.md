# User Types and Categories (cat_id) Explanation

## What is `cat_id`?

**`cat_id`** (or `categoryId`) is the **User Category ID** that identifies the user's role/type in the system.

- **In Login Response**: The API returns `cat_id` in the login response
- **In Database**: Stored as `categoryId` in the `Users` table
- **In App**: Stored as `userType` in AppSettings/StorageHelper

---

## User Type Constants

From KMP's `UserType.kt`:

| Category ID | User Type | Constant Name |
|-------------|-----------|---------------|
| **1** | Admin | `UserType.ADMIN` |
| **2** | Storekeeper | `UserType.STOREKEEPER` |
| **3** | Salesman | `UserType.SALESMAN` |
| **4** | Supplier | `UserType.SUPPLIER` |
| **5** | Biller | `UserType.BILLER` |
| **6** | Checker | `UserType.CHECKER` |
| **7** | Driver | `UserType.DRIVER` |

---

## How It's Used

### 1. **Login Flow**
```kotlin
// Login response contains cat_id
val catId = data?.get("cat_id")?.jsonPrimitive?.content?:"0"
settings.setUserType(catId) // Stores as userType
```

### 2. **Database Structure**
- **Users Table**: Has `categoryId` field (references user category)
- **UsersCategory Table**: Stores category definitions with permissions

```sql
-- Users table
categoryId INTEGER DEFAULT -1 NOT NULL

-- UsersCategory table  
userCategoryId INTEGER NOT NULL UNIQUE
name TEXT (e.g., "Admin", "Salesman")
permissionJson TEXT (JSON with permissions)
```

### 3. **Access Control**
The `userType` (cat_id) controls:
- **Menu Items**: Which screens/features are visible
- **Sync Data**: What data gets synced based on role
- **Order Access**: Different order views for different roles
- **Permissions**: What actions each role can perform

---

## Role-Based Access Control

### **Admin (cat_id = 1)**
**Full Access:**
- ✅ Orders
- ✅ Out of Stock
- ✅ Products
- ✅ Customers
- ✅ Suppliers
- ✅ Users Management
- ✅ Salesman Management
- ✅ Routes
- ✅ Product Settings
- ✅ Sync All Data

**Sync Access:**
- Syncs all tables (Products, Orders, Customers, Users, etc.)

### **Storekeeper (cat_id = 2)**
**Access:**
- ✅ Orders
- ✅ Out of Stock
- ❌ Products (no access)
- ❌ Customers (no access)
- ❌ Suppliers (no access)
- ❌ Users Management (no access)

**Sync Access:**
- Syncs: Products, Categories, Units, Out of Stock
- Does NOT sync: Orders, Customers, Users (role-specific filtering)

### **Salesman (cat_id = 3)**
**Access:**
- ✅ Orders
- ✅ Products
- ✅ Customers
- ❌ Out of Stock (no access)
- ❌ Suppliers (no access)
- ❌ Users Management (no access)

**Sync Access:**
- Syncs: Products, Categories, Orders, Customers, Routes
- Does NOT sync: Out of Stock, Users, Suppliers

### **Supplier (cat_id = 4)**
**Access:**
- ❌ Orders (no access - uses "Out of Stock" screen instead)
- ✅ Out of Stock (shown as "Orders" for suppliers)
- ❌ Products (no access)
- ❌ Customers (no access)

**Sync Access:**
- Syncs: Products, Out of Stock (both master and products)
- Does NOT sync: Orders, Customers, Users

**Special Behavior:**
- Out of Stock screen is labeled as "Orders" for suppliers
- Different order details screen (OutOfStockSupplier)

### **Biller (cat_id = 5)**
**Access:**
- ✅ Orders (limited access)
- ❌ Most other features

**Sync Access:**
- Limited sync (needs verification from code)

### **Checker (cat_id = 6)**
**Access:**
- ✅ Orders (checking/verification access)
- ❌ Most other features

**Sync Access:**
- Limited sync (needs verification from code)

### **Driver (cat_id = 7)**
**Access:**
- ✅ Orders (delivery access)
- ❌ Most other features

**Sync Access:**
- Limited sync (needs verification from code)

---

## Menu Items by User Type

From `Home.kt` and `Drawar.kt`:

```kotlin
// Orders - All except Supplier
if (userType != 4) menuList.add(ORDERS)

// Out of Stock - Admin, Storekeeper, Supplier
if (userType == 4 || userType == 1 || userType == 2) menuList.add(OUT_OF_STOCK)

// Products - Admin, Salesman
if (userType == 1 || userType == 3) menuList.add(PRODUCTS)

// Customers - Admin, Salesman
if (userType == 1 || userType == 3) menuList.add(CUSTOMER)

// Suppliers - Admin only
if (userType == 1) menuList.add(SUPPLIERS)

// Users - Admin only
if (userType == 1) menuList.add(USERS)

// Salesman - Admin only
if (userType == 1) menuList.add(SALESMAN)

// Routes - Admin only
if (userType == 1) menuList.add(ROUTES)

// Product Settings - Admin only
if (userType == 1) menuList.add(PRODUCTS_SETTINGS)
```

---

## Sync Access by User Type

From `SyncViewModel.kt`:

### **Orders & OrderSubs**
- **Admin, Storekeeper, Salesman**: ✅ Sync
- **Supplier**: ❌ Skip (userType == 4)

### **Out of Stock Master**
- **Admin, Supplier**: ✅ Sync
- **Others**: ❌ Skip

### **Out of Stock Products**
- **Admin, Storekeeper, Supplier**: ✅ Sync
- **Others**: ❌ Skip

### **Customers**
- **Admin, Storekeeper, Salesman**: ✅ Sync
- **Supplier**: ❌ Skip (userType == 4)

### **Users, Salesman, Suppliers**
- **Admin, Storekeeper, Salesman**: ✅ Sync
- **Supplier**: ❌ Skip (userType == 4)

---

## Order Details Screens by User Type

Different user types see different order detail screens:

- **Admin (1)**: `OrderDetailsAdmin` - Full admin view
- **Storekeeper (2)**: `OrderDetailsStorekeeper` - Packing/warehouse view
- **Salesman (3)**: `OrderDetailsSalesman` - Sales view
- **Checker (6)**: `OrderDetailsChecker` - Verification view
- **Supplier (4)**: `OutOfStockDetailsSupplier` - Supplier order view

---

## Key Points

1. **`cat_id` = `categoryId` = `userType`** - All refer to the same thing
2. **Stored in 3 places:**
   - Login response: `cat_id`
   - Database: `Users.categoryId`
   - App storage: `userType` (in AppSettings/StorageHelper)

3. **Controls everything:**
   - Menu visibility
   - Data sync
   - Screen access
   - Order views
   - Permissions

4. **UsersCategory Table:**
   - Stores category names (e.g., "Admin", "Salesman")
   - Stores `permissionJson` for fine-grained permissions
   - Linked to Users via `categoryId`

---

## Example Flow

```
1. User logs in
   ↓
2. API returns: { "cat_id": 1 }  // Admin
   ↓
3. App stores: userType = 1
   ↓
4. App checks userType to:
   - Show/hide menu items
   - Control sync data
   - Show appropriate screens
   - Filter orders/customers
```

---

## Summary Table

| User Type | cat_id | Can See Orders | Can See Products | Can See Customers | Can Manage Users | Sync Orders |
|-----------|--------|----------------|------------------|-------------------|------------------|-------------|
| Admin | 1 | ✅ | ✅ | ✅ | ✅ | ✅ |
| Storekeeper | 2 | ✅ | ❌ | ❌ | ❌ | ✅ (filtered) |
| Salesman | 3 | ✅ | ✅ | ✅ | ❌ | ✅ (filtered) |
| Supplier | 4 | ❌ | ❌ | ❌ | ❌ | ❌ |
| Biller | 5 | ✅ | ❌ | ❌ | ❌ | ? |
| Checker | 6 | ✅ | ❌ | ❌ | ❌ | ? |
| Driver | 7 | ✅ | ❌ | ❌ | ❌ | ? |

---

## In Your Flutter Code

Currently in `AuthProvider`:
```dart
@JsonKey(name: 'cat_id', defaultValue: 0)
final int catId; // 1-Admin 2-Storekeeper 3-SalesMan 4-supplier 5-Biller 6-Checker
```

This is correct! The `cat_id` from login response becomes `userType` in your app, which you should use for:
- Menu visibility
- Sync filtering
- Screen access control
- Order filtering

