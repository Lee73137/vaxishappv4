class InvoiceLineItem {
  const InvoiceLineItem({
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
  /// amount but a real quantity.
  bool get isFreeLine => rate == 0 && amount == 0 && quantity > 0;

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItem(
      itemname: json['itemname']?.toString().trim() ?? '',
      quantity: int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      rate: double.tryParse(json['orrate']?.toString() ?? '') ?? 0,
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
    );
  }
}
