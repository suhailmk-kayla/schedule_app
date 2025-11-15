import 'order_api.dart';

/// Order With Name Model
/// Contains order with related names (salesman, storekeeper, customer, etc.)
/// Converted from KMP's OrderWithName.kt
class OrderWithName {
  final Order order;
  final String salesManName;
  final String storeKeeperName;
  final String customerName;
  final String billerName;
  final String checkerName;
  final String route;

  const OrderWithName({
    required this.order,
    this.salesManName = '',
    this.storeKeeperName = '',
    this.customerName = '',
    this.billerName = '',
    this.checkerName = '',
    this.route = '',
  });

  /// Create OrderWithName from Order (for now, using order's customer name)
  /// TODO: Enhance repository to return OrderWithName with joined names
  factory OrderWithName.fromOrder(Order order) {
    return OrderWithName(
      order: order,
      customerName: order.orderCustName,
      salesManName: '',
      storeKeeperName: '',
      billerName: '',
      checkerName: '',
      route: '',
    );
  }
}

