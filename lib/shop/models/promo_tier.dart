/// A quantity-based pricing/deal tier for one item, e.g. "buy 18+ at ₱395
/// each" (amount > 0) or "buy 10+, get 1 free" (freeQuantity > 0). A single
/// item can have both kinds of tiers active at once.
class PromoTier {
  const PromoTier({
    required this.itemcode,
    required this.minQty,
    required this.freeQuantity,
    required this.amount,
  });

  final String itemcode;
  final int minQty;
  final int freeQuantity;
  final double amount;

  /// The live API returns `minqty` (lowercase, no underscore) — confirmed by
  /// hitting /api/apppromotier directly. Not `minvalue`.
  factory PromoTier.fromJson(Map<String, dynamic> json) {
    return PromoTier(
      itemcode: json['itemcode']?.toString() ?? '',
      minQty: int.tryParse(json['minqty']?.toString() ?? '') ?? 1,
      freeQuantity: int.tryParse(json['freequantity']?.toString() ?? '') ?? 0,
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
    );
  }
}
