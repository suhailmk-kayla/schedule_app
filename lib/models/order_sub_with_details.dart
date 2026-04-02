import 'order_api.dart';

/// Order Sub With Details Model
/// Contains OrderSub with product and unit names from JOIN queries
/// Converted from KMP's GetOrdersSubAndDetails
class OrderSubWithDetails {
  final String? unitName;
  final String? unitDispName;
  final String? productName;
  final String? productCode;
  final String? productBrand;
  final String? productSubBrand;
  final String? productPhoto; // Product image URL
  /// Catalog price from Product.price (JOIN). Compare to [OrderSub.orderSubUpdateRate].
  final double? productPrice;
  final OrderSub orderSub;

  const OrderSubWithDetails({
    this.unitName,
    this.unitDispName,
    this.productName,
    this.productCode,
    this.productBrand,
    this.productSubBrand,
    this.productPhoto,
    this.productPrice,
    required this.orderSub,
  });

  /// Convert from database map (from JOIN query)
  factory OrderSubWithDetails.fromMap(Map<String, dynamic> map) {
    return OrderSubWithDetails(
      unitName: map['unitName'] as String?,
      unitDispName: map['unitDispName'] as String?,
      productName: map['productName'] as String?,
      productCode: map['productCode'] as String?,
      productBrand: map['productBrand'] as String?,
      productSubBrand: map['productSubBrand'] as String?,
      productPhoto: map['productPhoto'] as String?,
      productPrice: (map['productPrice'] as num?)?.toDouble(),
      orderSub: OrderSub.fromMap(map),
    );
  }
}

