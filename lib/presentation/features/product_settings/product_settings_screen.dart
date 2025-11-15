import 'package:flutter/material.dart';
import '../../../utils/asset_images.dart';
import '../../provider/home_provider.dart';
import 'units/units_list_screen.dart';
import 'category/category_list_screen.dart';
import 'sub_category/sub_category_list_screen.dart';
import 'cars/cars_list_screen.dart';

/// Product Settings Screen
/// Converted from KMP's ProductSettingsScreen.kt
/// Displays a grid of product-related settings: Units, Category, Sub-Category, and Cars
class ProductSettingsScreen extends StatelessWidget {
  const ProductSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menuList = _initMenu();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  childAspectRatio: 1.4,
                ),
                itemCount: menuList.length,
                itemBuilder: (context, index) {
                  return _ProductSettingMenuItemCard(
                    menuItem: menuList[index],
                    onTap: () {
                      _handleMenuTap(context, menuList[index].type);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Initialize menu items for Product Settings
  /// Converted from KMP's initMenu function in ProductSettingsScreen.kt
  List<MenuItem> _initMenu() {
    final menuList = <MenuItem>[];
    menuList.add(MenuItem(
      imagePath: AssetImages.imagesUnits,
      type: MenuType.units,
      title: 'Units',
      icon: Icons.straighten,
      count: 0,
    ));
    menuList.add(MenuItem(
      imagePath: AssetImages.imagesCategory,
      type: MenuType.category,
      title: 'Category',
      icon: Icons.category,
      count: 0,
    ));
    menuList.add(MenuItem(
      imagePath: AssetImages.imagesSubCategory,
      type: MenuType.subCategory,
      title: 'Sub-Category',
      icon: Icons.subdirectory_arrow_right,
      count: 0,
    ));
    menuList.add(MenuItem(
      imagePath: AssetImages.imagesCars,
      type: MenuType.cars,
      title: 'Cars',
      icon: Icons.directions_car,
      count: 0,
    ));
    return menuList;
  }

  /// Handle menu item tap navigation
  /// Converted from KMP's menuSelect function for Product Settings menu items
  void _handleMenuTap(BuildContext context, MenuType menuType) {
    switch (menuType) {
      case MenuType.units:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const UnitsListScreen(),
          ),
        );
        break;
      case MenuType.category:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CategoryListScreen(),
          ),
        );
        break;
      case MenuType.subCategory:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SubCategoryListScreen(),
          ),
        );
        break;
      case MenuType.cars:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CarsListScreen(),
          ),
        );
        break;
      default:
        break;
    }
  }
}

/// Product Setting Menu Item Card Widget
/// Reuses the same card style as home screen menu items
/// Converted from KMP's menuItem composable
class _ProductSettingMenuItemCard extends StatelessWidget {
  final MenuItem menuItem;
  final VoidCallback onTap;

  const _ProductSettingMenuItemCard({
    required this.menuItem,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Count badge (not used in Product Settings, but keeping structure consistent)
            if (menuItem.count > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      menuItem.count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    menuItem.imagePath ?? '',
                    width: 32,
                    height: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    menuItem.title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

