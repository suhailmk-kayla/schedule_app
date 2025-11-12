import 'package:flutter/material.dart';
import '../../provider/home_provider.dart';
import '../../../utils/asset_images.dart';

/// Product Settings Screen
/// Displays menu items for product-related settings
/// Converted from KMP's ProductSettingsScreen.kt
class ProductSettingsScreen extends StatelessWidget {
  const ProductSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menuItems = _initMenu();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
            childAspectRatio: 1.4,
          ),
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            return _MenuItemCard(
              imagePath: menuItems[index].imagePath,
              menuItem: menuItems[index],
              onTap: () {
                _handleMenuTap(context, menuItems[index].type);
              },
            );
          },
        ),
      ),
    );
  }

  /// Initialize menu items
  /// Converted from KMP's initMenu function
  List<MenuItem> _initMenu() {
    final menuList = <MenuItem>[];
    
    menuList.add(MenuItem(
      type: MenuType.units,
      title: 'Units',
      icon: Icons.straighten,
      imagePath: AssetImages.imagesUnits,
    ));
    
    menuList.add(MenuItem(
      type: MenuType.category,
      title: 'Category',
      icon: Icons.category,
      imagePath: AssetImages.imagesCategory,
    ));
    
    menuList.add(MenuItem(
      type: MenuType.subCategory,
      title: 'Sub-Category',
      icon: Icons.category_outlined,
      imagePath: AssetImages.imagesSubCategory,
    ));
    
    menuList.add(MenuItem(
      type: MenuType.cars,
      title: 'Cars',
      icon: Icons.directions_car,
      imagePath: AssetImages.imagesCars,
    ));

    return menuList;
  }

  void _handleMenuTap(BuildContext context, MenuType menuType) {
    // TODO: Navigate to appropriate screen based on menu type
    switch (menuType) {
      case MenuType.units:
        // Navigator.push(context, MaterialPageRoute(builder: (_) => UnitsScreen()));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Units screen - Coming soon')),
        );
        break;
      case MenuType.category:
        // Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryScreen()));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category screen - Coming soon')),
        );
        break;
      case MenuType.subCategory:
        // Navigator.push(context, MaterialPageRoute(builder: (_) => SubCategoryScreen()));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sub-Category screen - Coming soon')),
        );
        break;
      case MenuType.cars:
        // Navigator.push(context, MaterialPageRoute(builder: (_) => CarsScreen()));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cars screen - Coming soon')),
        );
        break;
      default:
        break;
    }
  }
}

/// Menu Item Card Widget
/// Converted from KMP's menuItem composable
class _MenuItemCard extends StatelessWidget {
  final MenuItem menuItem;
  final VoidCallback onTap;
  final String imagePath;

  const _MenuItemCard({
    required this.menuItem,
    required this.onTap,
    required this.imagePath,
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                imagePath,
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
      ),
    );
  }
}

