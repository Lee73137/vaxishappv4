import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../widgets/glossy_widgets.dart';
import '../models/deal_calculation.dart';
import '../models/item.dart';
import '../models/promo_tier.dart';
import '../providers/cart_provider.dart';
import '../services/promo_tier_service.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.item, this.onTap});

  final Item item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final quantity = context.select<CartProvider, int>(
      (cart) => cart.quantityFor(item.itemcode),
    );

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: colors.divider),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
                child: AspectRatio(
                  aspectRatio: 1.15,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          color: colors.surfaceVariant,
                          padding: EdgeInsets.all(12.w),
                          child: item.itemimagepath.isEmpty
                              ? _imageFallback(context)
                              : CachedNetworkImage(
                                  imageUrl: item.itemimagepath,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => Center(
                                    child: SizedBox(
                                      width: 18.w,
                                      height: 18.w,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          brandRed,
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      _imageFallback(context),
                                ),
                        ),
                      ),
                      FutureBuilder<List<PromoTier>>(
                        future: PromoTierService().getTiersFor(item.itemcode),
                        builder: (context, snapshot) {
                          if (snapshot.data?.isEmpty ?? true) {
                            return const SizedBox.shrink();
                          }
                          return const TierRibbon(compact: true);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (item.itemdescription.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        item.itemdescription,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(child: _PriceDisplay(item: item)),
                        _AddButton(item: item, quantity: quantity),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageFallback(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.surfaceVariant,
      child: Icon(
        Icons.medication_liquid_outlined,
        color: colors.iconInactive,
        size: 34.sp,
      ),
    );
  }
}

/// Shows the plain price, or — for items with tier pricing — the best
/// blended per-unit price reachable at the largest tier threshold, labeled
/// "For as low as" to entice the user into the detail screen for specifics.
class _PriceDisplay extends StatelessWidget {
  const _PriceDisplay({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PromoTier>>(
      future: PromoTierService().getTiersFor(item.itemcode),
      builder: (context, snapshot) {
        final tiers = snapshot.data ?? const [];
        if (tiers.isEmpty) {
          return Text(
            '₱${formatPeso(item.itemprice)}',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: brandRed,
            ),
          );
        }

        final maxMinQty = tiers
            .map((t) => t.minQty)
            .reduce((a, b) => a > b ? a : b);
        final calc = calculateDealBreakdown(tiers, item.itemprice, maxMinQty);
        final totalUnits = maxMinQty + calc.freeQuantity;
        final lowestPrice = totalUnits > 0
            ? (calc.appliedUnitPrice * maxMinQty) / totalUnits
            : item.itemprice;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₱${formatPeso(item.itemprice)}/pc',
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w600,
                color: context.colors.textTertiary,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            Text(
              'For as low as ₱${formatPeso(lowestPrice)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: brandRed,
                height: 1.2,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.item, required this.quantity});

  final Item item;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    if (quantity == 0) {
      return _GlossyIconButton(
        icon: Icons.add,
        onTap: () => context.read<CartProvider>().addToCart(item),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        gradient: const LinearGradient(
          colors: [brandRed, brandRedDark],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            onTap: () => context.read<CartProvider>().updateQuantity(
              item,
              quantity - 1,
            ),
          ),
          SizedBox(
            width: 22.w,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            onTap: () => context.read<CartProvider>().updateQuantity(
              item,
              quantity + 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 5.w),
        child: Icon(icon, size: 14.sp, color: Colors.white),
      ),
    );
  }
}

class _GlossyIconButton extends StatelessWidget {
  const _GlossyIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.all(7.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          gradient: const LinearGradient(
            colors: [brandRed, brandRedDark],
          ),
          boxShadow: [
            BoxShadow(
              color: brandRed.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 15.sp, color: Colors.white),
      ),
    );
  }
}
