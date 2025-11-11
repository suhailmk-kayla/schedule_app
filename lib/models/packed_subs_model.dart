/// PackedSubs Model
/// Simple model for tracking packed order subs
class PackedSubs {
  final int id;
  final int orderSubId;
  final double quantity;

  const PackedSubs({
    required this.id,
    required this.orderSubId,
    required this.quantity,
  });

  factory PackedSubs.fromMap(Map<String, dynamic> map) {
    return PackedSubs(
      id: map['id'] as int? ?? 0,
      orderSubId: map['orderSubId'] as int? ?? -1,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderSubId': orderSubId,
      'quantity': quantity,
    };
  }
}

