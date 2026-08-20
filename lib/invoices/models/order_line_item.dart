class OrderLineItem {
  const OrderLineItem({
    required this.itemname,
    required this.quantity,
    required this.rate,
    required this.amount,
  });

  final String itemname;
  final int quantity;
  final double rate;
  final double amount;

  /// Free-quantity lines (from bulk-deal tiers) post with a zero rate and
  /// amount but a real quantity — same convention as InvoiceLineItem.
  bool get isFreeLine => rate == 0 && amount == 0 && quantity > 0;

  factory OrderLineItem.fromJson(Map<String, dynamic> json) {
    return OrderLineItem(
      itemname: json['itemname']?.toString().trim() ?? '',
      quantity: int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      rate: double.tryParse(json['rate']?.toString() ?? '') ?? 0,
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
    );
  }
}
