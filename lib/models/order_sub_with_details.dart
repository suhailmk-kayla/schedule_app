import 'order_api.dart';

/// Order Sub With Details Model
/// Contains OrderSub with product and unit names from JOIN queries
/// Converted from KMP's GetOrdersSubAndDetails
class OrderSubWithDetails {
  final String? unitName;
  final String? unitDispName;
  final String? productName;
  final String? productBrand;
  final String? productSubBrand;
  final String? productPhoto; // Product image URL
  final OrderSub orderSub;

  const OrderSubWithDetails({
    this.unitName,
    this.unitDispName,
    this.productName,
    this.productBrand,
    this.productSubBrand,
    this.productPhoto,
    required this.orderSub,
  });

  /// Convert from database map (from JOIN query)
  factory OrderSubWithDetails.fromMap(Map<String, dynamic> map) {
    return OrderSubWithDetails(
      unitName: map['unitName'] as String?,
      unitDispName: map['unitDispName'] as String?,
      productName: map['productName'] as String?,
      productBrand: map['productBrand'] as String?,
      productSubBrand: map['productSubBrand'] as String?,
      productPhoto: map['productPhoto'] as String?,
      orderSub: OrderSub.fromMap(map),
    );
  }
}

