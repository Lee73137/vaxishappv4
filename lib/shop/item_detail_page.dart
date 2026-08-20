import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../widgets/glossy_widgets.dart';
import 'models/deal_calculation.dart';
import 'models/item.dart';
import 'models/promo_tier.dart';
import 'providers/cart_provider.dart';
import 'services/promo_tier_service.dart';

class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({super.key, required this.item});

  final Item item;

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  List<PromoTier> _tiers = [];
  bool _loadingTiers = true;
  int _quantity = 1;
  DealCalculation _calc = const DealCalculation(
    freeQuantity: 0,
    appliedUnitPrice: 0,
  );

  @override
  void initState() {
    super.initState();
    final existing = context
        .read<CartProvider>()
        .items
        .where((c) => c.item.itemcode == widget.item.itemcode);
    _quantity = existing.isNotEmpty ? existing.first.quantity : 1;
    _recompute();
    _loadTiers();
  }

  Future<void> _loadTiers() async {
    final tiers = await PromoTierService().getTiersFor(widget.item.itemcode);
    if (!mounted) return;
    setState(() {
      _tiers = tiers;
      _loadingTiers = false;
    });
    _recompute();
  }

  void _recompute() {
    setState(() {
      _calc = calculateDealBreakdown(_tiers, widget.item.itemprice, _quantity);
    });
  }

  void _setQuantity(int qty) {
    final clamped = qty < 0 ? 0 : qty;
    _quantity = clamped;
    _recompute();
  }

  Future<void> _addToCart() async {
    await context.read<CartProvider>().setCartLine(
      widget.item,
      quantity: _quantity,
      freeQty: _calc.freeQuantity,
      unitPrice: _calc.appliedUnitPrice,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Added to cart'),
        backgroundColor: brandRedDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        duration: const Duration(seconds: 1),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = widget.item;
    final originalTotal = item.itemprice * _quantity;
    final discountedTotal = _calc.appliedUnitPrice * _quantity;
    final savings =
        (originalTotal - discountedTotal) +
        (_calc.freeQuantity * item.itemprice);

    // Screen-capability-based sizing: below this width, tighten paddings and
    // fonts so the layout stays comfortable on small/older devices instead
    // of just relying on ScreenUtil's proportional scale-down.
    final screenSize = MediaQuery.of(context).size;
    final isCompact = screenSize.width < 360;
    final pad = isCompact ? 14.w : 20.w;
    final imageHeight = (screenSize.height * 0.26).clamp(170.0, 240.0);

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GlossyHeader(title: item.itemname),
                  Padding(
                    padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ImageSection(
                          item: item,
                          height: imageHeight,
                          hasTiers: _tiers.isNotEmpty,
                        ),
                        SizedBox(height: isCompact ? 14.h : 20.h),
                        Text(
                          item.itemname,
                          style: TextStyle(
                            fontSize: isCompact ? 17.sp : 20.sp,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        if (item.itemdescription.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            item.itemdescription,
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                        SizedBox(height: isCompact ? 14.h : 20.h),
                        _PriceQuantityCard(
                          appliedUnitPrice: _calc.appliedUnitPrice,
                          basePrice: item.itemprice,
                          hasDiscount: _calc.appliedUnitPrice < item.itemprice,
                          quantity: _quantity,
                          onChanged: _setQuantity,
                          isCompact: isCompact,
                        ),
                        SizedBox(height: 16.h),
                        if (_loadingTiers)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: brandRed,
                                strokeWidth: 2.2,
                              ),
                            ),
                          )
                        else if (_tiers.isNotEmpty)
                          _TierList(tiers: _tiers),
                        if (_calc.freeQuantity > 0) ...[
                          SizedBox(height: 16.h),
                          _FreeQtyBanner(freeQty: _calc.freeQuantity),
                        ],
                        SizedBox(height: isCompact ? 14.h : 20.h),
                        _DescriptionSection(html: item.description),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _BottomBar(
            total: discountedTotal,
            savings: savings,
            onAddToCart: _quantity > 0 ? _addToCart : null,
          ),
        ],
      ),
    );
  }
}

class _GlossyHeader extends StatelessWidget {
  const _GlossyHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.surface.withValues(alpha: 0.58),
                brandRed.withValues(alpha: 0.4),
              ],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
            boxShadow: [
              BoxShadow(
                color: brandRed.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 16.w, 18.h),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20.r),
                    child: Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: brandRed.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: brandRed,
                        size: 20.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.item,
    required this.height,
    required this.hasTiers,
  });

  final Item item;
  final double height;
  final bool hasTiers;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: item.itemimagepath.isEmpty
          ? null
          : () => showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.all(20.w),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20.r),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: CachedNetworkImage(
                      imageUrl: item.itemimagepath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: Stack(
            children: [
              // Positioned.fill forces tight constraints matching the full
              // card, so BoxFit.contain centers the image within it — a
              // plain non-positioned child here only gets loose constraints
              // from Stack and shrink-wraps to the fit-computed size, which
              // Stack then left-aligns instead of centering.
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14.r),
                    child: item.itemimagepath.isEmpty
                        ? Icon(
                            Icons.medication_liquid_outlined,
                            size: 64.sp,
                            color: colors.iconInactive,
                          )
                        : CachedNetworkImage(
                            imageUrl: item.itemimagepath,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                color: brandRed,
                                strokeWidth: 2.2,
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.medication_liquid_outlined,
                              size: 64.sp,
                              color: colors.iconInactive,
                            ),
                          ),
                  ),
                ),
              ),
              if (hasTiers) const TierRibbon(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceQuantityCard extends StatelessWidget {
  const _PriceQuantityCard({
    required this.appliedUnitPrice,
    required this.basePrice,
    required this.hasDiscount,
    required this.quantity,
    required this.onChanged,
    required this.isCompact,
  });

  final double appliedUnitPrice;
  final double basePrice;
  final bool hasDiscount;
  final int quantity;
  final ValueChanged<int> onChanged;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final priceRow = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '₱${formatPeso(appliedUnitPrice)}',
          style: TextStyle(
            fontSize: isCompact ? 19.sp : 22.sp,
            fontWeight: FontWeight.bold,
            color: brandRed,
          ),
        ),
        if (hasDiscount) ...[
          SizedBox(width: 8.w),
          Text(
            '₱${formatPeso(basePrice)}',
            style: TextStyle(
              fontSize: 12.sp,
              color: colors.textTertiary,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
    );

    final quantitySelector = _QuantitySelector(
      quantity: quantity,
      onChanged: onChanged,
    );

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface.withValues(alpha: 0.6),
            brandRed.withValues(alpha: 0.32),
          ],
        ),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price',
            style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
          ),
          SizedBox(height: 6.h),
          LayoutBuilder(
            builder: (context, constraints) {
              // Fall back to a stacked layout only on genuinely tiny widths
              // (e.g. split-screen/multi-window) — constraints here are
              // real device pixels, already net of the card's own padding,
              // so this threshold must stay well below a normal phone's
              // available width.
              if (constraints.maxWidth < 230) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    priceRow,
                    SizedBox(height: 12.h),
                    quantitySelector,
                  ],
                );
              }
              // Both children sit on the same line here (not against the
              // "Price" label above), so centering them against each
              // other actually lines up visually instead of centering the
              // pill against a much taller two-line block.
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: priceRow),
                  quantitySelector,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  Future<void> _editQuantity(BuildContext context) async {
    final fieldController = TextEditingController(text: '$quantity');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set quantity'),
        content: TextField(
          controller: fieldController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(int.tryParse(fieldController.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    fieldController.dispose();
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.divider),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepButton(Icons.remove_rounded, () => onChanged(quantity - 1)),
          InkWell(
            onTap: () => _editQuantity(context),
            child: SizedBox(
              width: 44.w,
              height: 36.h,
              child: Center(
                child: Text(
                  '$quantity',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp),
                ),
              ),
            ),
          ),
          _stepButton(Icons.add_rounded, () => onChanged(quantity + 1)),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        width: 34.w,
        height: 34.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: brandRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, size: 16.sp, color: brandRed),
      ),
    );
  }
}

class _TierList extends StatelessWidget {
  const _TierList({required this.tiers});

  final List<PromoTier> tiers;

  @override
  Widget build(BuildContext context) {
    final relevant = tiers.where((t) => t.minQty > 1).toList()
      ..sort((a, b) => a.minQty.compareTo(b.minQty));

    if (relevant.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brandRed.withValues(alpha: 0.26), Colors.amber.withValues(alpha: 0.14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_rounded, color: brandRed, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                'Bulk Deals',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ...relevant.map((tier) {
            final isFreeDeal = tier.freeQuantity > 0;
            final label = isFreeDeal
                ? 'Buy ${tier.minQty}, get ${tier.freeQuantity} free'
                : '₱${formatPeso(tier.amount)} each for ${tier.minQty}+';

            return Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                children: [
                  Icon(
                    isFreeDeal
                        ? Icons.card_giftcard
                        : Icons.discount_rounded,
                    size: 14.sp,
                    color: isFreeDeal ? Colors.amber.shade800 : brandRed,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FreeQtyBanner extends StatelessWidget {
  const _FreeQtyBanner({required this.freeQty});

  final int freeQty;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.green.withValues(alpha: 0.18) : Colors.green.shade50,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? Colors.green.withValues(alpha: 0.4) : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.card_giftcard,
            color: isDark ? Colors.green.shade300 : Colors.green.shade700,
            size: 22.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'You get $freeQty free ${freeQty > 1 ? 'items' : 'item'} with this quantity',
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.green.shade200 : Colors.green.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection({required this.html});

  final String html;

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.html.trim().isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, color: brandRed, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                'Product Details',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            // The description is raw HTML from the backend, so its text
            // color has to be set explicitly via Html's style map — it
            // doesn't inherit from the surrounding Flutter TextStyle/theme
            // the way a plain Text widget would, and would otherwise render
            // as illegible dark-on-dark in dark mode.
            firstChild: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 90.h),
              child: ClipRect(child: Html(data: widget.html, style: {"body": Style(color: colors.textPrimary)})),
            ),
            secondChild: Html(data: widget.html, style: {"body": Style(color: colors.textPrimary)}),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? 'Show less' : 'Read more',
                style: TextStyle(
                  color: brandRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.total,
    required this.savings,
    required this.onAddToCart,
  });

  final double total;
  final double savings;
  final VoidCallback? onAddToCart;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 14.h),
        decoration: BoxDecoration(
          color: colors.surface,
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
                  ),
                  Text(
                    '₱${formatPeso(total)}',
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (savings > 0)
                    Text(
                      'You save ₱${formatPeso(savings)}',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            SizedBox(
              width: 160.w,
              child: GlossyButton(label: 'Add to Cart', onPressed: onAddToCart),
            ),
          ],
        ),
      ),
    );
  }
}
