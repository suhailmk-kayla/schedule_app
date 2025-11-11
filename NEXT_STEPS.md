# Next Steps - Development Plan

## ✅ What We've Completed

1. **Models** - All KMP models converted to Dart ✅
2. **Exceptions & Errors** - AppException hierarchy and Failure classes ✅
3. **Database Setup** - SQLite with all tables and migrations ✅
4. **Repositories** - All 20 repositories (local DB + API operations) ✅
5. **Dio Interceptors** - Auth, Logging, Retry interceptors ✅
6. **Providers** - ProductsProvider, CustomersProvider, OrdersProvider, SyncProvider ✅
7. **Dependency Injection** - get_it setup with all dependencies ✅

---

## 🎯 Next Steps (In Order)

### Phase 1: Foundation (Must Do First)

#### 1. **Authentication & Login Flow** 🔐
**Priority: HIGH** - Needed before any screens work

**What to create:**
- `lib/presentation/provider/auth_provider.dart`
  - Login method (calls API, stores token/user data)
  - Logout method (clears storage)
  - Check if user is logged in
  - Get current user info

- `lib/presentation/features/auth/login_screen.dart`
  - Login form (username/code, password)
  - Error handling
  - Loading states
  - Navigate to sync/home after login

- `lib/presentation/features/auth/splash_screen.dart`
  - Shows logo/splash
  - Checks if user is logged in
  - Routes to login or home

**KMP Reference:**
- `SplashLoginScreen.kt`
- Login API endpoint: `api/login`

---

#### 2. **Theme Setup** 🎨
**Priority: HIGH** - Needed for consistent UI

**What to create:**
- `lib/theme/app_theme.dart`
  - Colors (convert from KMP's `SharedColors.kt`)
  - Typography (text styles)
  - Spacing constants
  - Shape/radius constants
  - Material 3 ThemeData

**KMP Reference:**
- `SharedColors.kt`

---

#### 3. **Navigation & Routing** 🧭
**Priority: HIGH** - Needed to navigate between screens

**What to create:**
- `lib/utils/app_router.dart`
  - Route definitions (enum or class)
  - Route names matching KMP's `BaseScreen` enum
  - Navigation helper methods

**Routes needed:**
- `/` - Splash
- `/login` - Login screen
- `/home` - Home/Dashboard
- `/products` - Products list
- `/products/create` - Create product
- `/products/edit/:id` - Edit product
- `/products/details/:id` - Product details
- `/orders` - Orders list
- `/orders/create` - Create order
- `/customers` - Customers list
- `/customers/create` - Create customer
- `/sync` - Sync screen
- ... (all other screens from KMP)

**KMP Reference:**
- `BaseScreen.kt` enum

---

#### 4. **Main App Structure** 🏗️
**Priority: HIGH** - Wire everything together

**What to update:**
- `lib/main.dart`
  - Initialize dependencies (`setupDependencies()`)
  - Setup Provider (MultiProvider)
  - MaterialApp with routing
  - Theme setup
  - Initial route logic

**Structure:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies(); // Initialize DI
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => getIt<AuthProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<ProductsProvider>()),
        // ... all other providers
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        routes: AppRouter.routes,
      ),
    );
  }
}
```

---

### Phase 2: Common Components

#### 5. **Common Widgets** 🧩
**Priority: MEDIUM** - Reusable UI components

**What to create:**
- `lib/presentation/common_widgets/app_bar_widget.dart`
  - Custom AppBar with menu/drawer
  - Role-based menu items

- `lib/presentation/common_widgets/custom_button.dart`
  - Primary button
  - Secondary button
  - Loading states

- `lib/presentation/common_widgets/custom_text_field.dart`
  - Text input with validation
  - Error messages

- `lib/presentation/common_widgets/loading_indicator.dart`
  - Loading spinner
  - Progress indicators

- `lib/presentation/common_widgets/error_widget.dart`
  - Error display
  - Retry button

- `lib/presentation/common_widgets/drawer_menu.dart`
  - Navigation drawer
  - Role-based menu items (from KMP's `DashMenu`)

**KMP Reference:**
- `Drawar.kt`
- `DashMenu.kt`
- `MenuItems.kt`

---

### Phase 3: Feature Screens

#### 6. **Home/Dashboard Screen** 🏠
**Priority: MEDIUM**

**What to create:**
- `lib/presentation/features/home/home_screen.dart`
  - Dashboard with menu items
  - Role-based menu visibility
  - Navigation to different screens

**KMP Reference:**
- `Home.kt`
- `DashMenu.kt`

---

#### 7. **Products Screens** 📦
**Priority: MEDIUM**

**What to create:**
- `lib/presentation/features/products/products_list_screen.dart`
  - List of products
  - Search/filter
  - Create/Edit buttons

- `lib/presentation/features/products/create_product_screen.dart`
  - Product creation form
  - Image picker
  - Category/subcategory selection

- `lib/presentation/features/products/edit_product_screen.dart`
  - Edit existing product
  - Pre-filled form

- `lib/presentation/features/products/product_details_screen.dart`
  - Product details view
  - Full image view

**KMP Reference:**
- `ProductListScreen.kt`
- `CreateProductScreen.kt`
- `EditProductScreen.kt`
- `ProductDetails.kt`

---

#### 8. **Orders Screens** 📋
**Priority: MEDIUM**

**What to create:**
- `lib/presentation/features/orders/orders_list_screen.dart`
- `lib/presentation/features/orders/create_order_screen.dart`
- `lib/presentation/features/orders/edit_order_screen.dart`
- `lib/presentation/features/orders/order_details_screen.dart`
  - Role-based details (Admin, Storekeeper, Salesman, Checker)

**KMP Reference:**
- `OrderListScreen.kt`
- `CreateOrderScreen.kt`
- `EditOrder.kt`
- `OrderDetails*.kt` (multiple role-based screens)

---

#### 9. **Customers Screens** 👥
**Priority: MEDIUM**

**What to create:**
- `lib/presentation/features/customers/customers_list_screen.dart`
- `lib/presentation/features/customers/create_customer_screen.dart`
- `lib/presentation/features/customers/edit_customer_screen.dart`
- `lib/presentation/features/customers/customer_details_screen.dart`

**KMP Reference:**
- `CustomersScreen.kt`
- `CreateCustomerScreen.kt`
- `EditCustomerScreen.kt`
- `CustomerDetails.kt`

---

#### 10. **Sync Screen** 🔄
**Priority: MEDIUM**

**What to create:**
- `lib/presentation/features/sync/sync_screen.dart`
  - Progress indicator
  - Current task display
  - Progress bar
  - Error handling
  - Stop sync button

**KMP Reference:**
- `SyncScreen.kt`

---

#### 11. **Other Feature Screens** 📱
**Priority: LOW** (Can be done later)

- Out of Stock screens
- Product Settings screens (Units, Categories, Cars)
- Users screens
- Salesman screens
- Suppliers screens
- Routes screens
- About screen

---

## 📋 Recommended Order of Implementation

### Week 1: Foundation
1. ✅ Authentication & Login Flow
2. ✅ Theme Setup
3. ✅ Navigation & Routing
4. ✅ Main App Structure

### Week 2: Core Screens
5. ✅ Common Widgets
6. ✅ Home/Dashboard Screen
7. ✅ Sync Screen
8. ✅ Products Screens (List, Create, Edit, Details)

### Week 3: Main Features
9. ✅ Orders Screens
10. ✅ Customers Screens

### Week 4: Additional Features
11. ✅ Other feature screens (as needed)

---

## 🎯 Immediate Next Step

**Start with: Authentication & Login Flow**

This is the foundation - users need to log in before accessing any features.

**Files to create:**
1. `lib/presentation/provider/auth_provider.dart`
2. `lib/presentation/features/auth/login_screen.dart`
3. `lib/presentation/features/auth/splash_screen.dart`
4. Update `lib/di.dart` to register AuthProvider
5. Update `lib/main.dart` to use authentication flow

**After this, we can:**
- Test login flow
- Move to theme setup
- Then navigation
- Then main app structure
- Then start building screens

---

## 💡 Tips

1. **Follow KMP structure** - Keep screen names and navigation similar
2. **Use existing providers** - ProductsProvider, CustomersProvider, etc. are ready
3. **Test incrementally** - Build one screen at a time, test it
4. **Reuse common widgets** - Don't duplicate code
5. **Follow theme** - Use theme colors/spacing consistently

---

## ❓ Questions to Consider

1. **State Management:** Should we use Provider for all screens or mix with other patterns?
   - **Answer:** Use Provider + ChangeNotifier (already set up)

2. **Navigation:** Use go_router, auto_route, or basic Navigator?
   - **Answer:** Start with basic Navigator, upgrade to go_router if needed

3. **Image Handling:** How to handle product images?
   - **Answer:** Use image_picker for camera/gallery, store URLs in model

4. **Form Validation:** Use formz, built_value, or manual validation?
   - **Answer:** Start with manual validation, upgrade if needed

---

## 🚀 Ready to Start?

**Next command:** "Let's start with authentication and login flow"

This will create:
- AuthProvider
- Login screen
- Splash screen
- Wire everything together

