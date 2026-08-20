import 'promo_tier.dart';

class DealCalculation {
  const DealCalculation({
    required this.freeQuantity,
    required this.appliedUnitPrice,
  });

  final int freeQuantity;
  final double appliedUnitPrice;
}

/// Works out the free-quantity and per-unit price for buying [quantity] of
/// an item given its [tiers], falling back to [basePrice] if no tier
/// applies. Free-quantity tiers stack (applied highest-minQty-first, then
/// repeatedly for any remaining quantity); price tiers don't stack — only
/// the single highest-minQty tier that [quantity] qualifies for applies.
DealCalculation calculateDealBreakdown(
  List<PromoTier> tiers,
  double basePrice,
  int quantity,
) {
  if (quantity <= 0 || tiers.isEmpty) {
    return DealCalculation(freeQuantity: 0, appliedUnitPrice: basePrice);
  }

  final freeTiers = tiers.where((t) => t.freeQuantity > 0).toList()
    ..sort((a, b) => b.minQty.compareTo(a.minQty));

  int remaining = quantity;
  int totalFree = 0;
  for (final tier in freeTiers) {
    if (remaining >= tier.minQty && tier.minQty > 0) {
      final applications = remaining ~/ tier.minQty;
      totalFree += applications * tier.freeQuantity;
      remaining -= applications * tier.minQty;
    }
  }

  final priceTiers = tiers.where((t) => t.amount > 0).toList()
    ..sort((a, b) => b.minQty.compareTo(a.minQty));

  double appliedPrice = basePrice;
  for (final tier in priceTiers) {
    if (quantity >= tier.minQty) {
      appliedPrice = tier.amount;
      break;
    }
  }

  return DealCalculation(
    freeQuantity: totalFree,
    appliedUnitPrice: appliedPrice,
  );
}
