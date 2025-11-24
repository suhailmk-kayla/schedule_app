import 'order_api.dart';
import 'order_sub_with_details.dart';

/// Combined view model for order detail items
class OrderItemDetail {
  final OrderSubWithDetails details;
  final List<OrderSubSuggestion> suggestions;
  final bool isPacked;

  const OrderItemDetail({
    required this.details,
    this.suggestions = const [],
    this.isPacked = false,
  });

  OrderSub get orderSub => details.orderSub;
  String get productName => details.productName ?? '';
  String get productBrand => details.productBrand ?? '';
  String get productSubBrand => details.productSubBrand ?? '';
  String get unitName => details.unitName ?? '';
  String get unitDisplayName =>
      details.unitDispName?.isNotEmpty == true ? details.unitDispName! : unitName;
}


