import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glossy_widgets.dart';
import 'checkout_page.dart';
import 'models/cart_item.dart';
import 'providers/cart_provider.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Set<String> _selected = {};
  String _clinicName = '';

  @override
  void initState() {
    super.initState();
    // All items start selected — matches the common e-commerce default of
    // everything being ready to check out unless the user deselects some.
    _selected.addAll(
      context.read<CartProvider>().items.map((c) => c.item.itemcode),
    );
    _loadClinicName();
  }

  Future<void> _loadClinicName() async {
    final session = await AuthService.loadSession();
    if (!mounted || session == null) return;
    setState(() {
      _clinicName = session.fullname?.trim().isNotEmpty == true
          ? session.fullname!.trim()
          : session.username;
    });
  }

  void _toggle(String itemcode, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(itemcode);
      } else {
        _selected.remove(itemcode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: Text(
          'My Cart',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 84.w,
                    height: 84.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: brandRed.withValues(alpha: 0.08),
                    ),
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      size: 36.sp,
                      color: brandRed,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Items you add will show up here',
                    style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
                  ),
                ],
              ),
            );
          }

          // Drop selections for items no longer in the cart (e.g. deleted).
          final validCodes = cart.items.map((c) => c.item.itemcode).toSet();
          _selected.retainAll(validCodes);

          final selectedItems = cart.items
              .where((c) => _selected.contains(c.item.itemcode))
              .toList();
          final selectedTotal = selectedItems.fold(
            0.0,
            (sum, c) => sum + c.subtotal,
          );

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.all(16.w),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, _) => SizedBox(height: 10.h),
                  itemBuilder: (context, index) {
                    final cartItem = cart.items[index];
                    return _CartTile(
                      cartItem: cartItem,
                      isSelected: _selected.contains(cartItem.item.itemcode),
                      onSelectedChanged: (value) =>
                          _toggle(cartItem.item.itemcode, value),
                    );
                  },
                ),
              ),
              _CartSummary(
                total: selectedTotal,
                selectedCount: selectedItems.length,
                onCheckout: selectedItems.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CheckoutPage(
                            items: selectedItems,
                            clinicName: _clinicName,
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  const _CartTile({
    required this.cartItem,
    required this.isSelected,
    required this.onSelectedChanged,
  });

  final CartItem cartItem;
  final bool isSelected;
  final ValueChanged<bool> onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = cartItem.item;

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isSelected ? brandRed.withValues(alpha: 0.3) : colors.divider,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26.w,
            child: Checkbox(
              value: isSelected,
              onChanged: (value) => onSelectedChanged(value ?? false),
              activeColor: brandRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.r),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: SizedBox(
              width: 60.w,
              height: 60.w,
              child: item.itemimagepath.isEmpty
                  ? Container(
                      color: colors.surfaceVariant,
                      child: Icon(
                        Icons.medication_liquid_outlined,
                        color: colors.iconInactive,
                        size: 22.sp,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: item.itemimagepath,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: context.colors.surfaceVariant,
                        child: Icon(
                          Icons.medication_liquid_outlined,
                          color: context.colors.iconInactive,
                          size: 22.sp,
                        ),
                      ),
                    ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Text(
                      '₱${formatPeso(cartItem.unitPrice)}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: brandRed,
                      ),
                    ),
                    if (cartItem.unitPrice < item.itemprice) ...[
                      SizedBox(width: 6.w),
                      Text(
                        '₱${formatPeso(item.itemprice)}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: colors.textTertiary,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
                if (cartItem.freeQty > 0) ...[
                  SizedBox(height: 3.h),
                  Text(
                    '+${cartItem.freeQty} free',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () =>
                    context.read<CartProvider>().removeFromCart(item),
                icon: Icon(
                  Icons.delete_outline,
                  size: 19.sp,
                  color: colors.iconInactive,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              SizedBox(height: 6.h),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: colors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StepIcon(
                      icon: Icons.remove,
                      onTap: () => context.read<CartProvider>().updateQuantity(
                        item,
                        cartItem.quantity - 1,
                      ),
                    ),
                    SizedBox(
                      width: 24.w,
                      child: Text(
                        '${cartItem.quantity}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _StepIcon(
                      icon: Icons.add,
                      onTap: () => context.read<CartProvider>().updateQuantity(
                        item,
                        cartItem.quantity + 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
        child: Icon(icon, size: 13.sp, color: context.colors.textPrimary),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({
    required this.total,
    required this.selectedCount,
    required this.onCheckout,
  });

  final double total;
  final int selectedCount;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedCount > 0
                      ? 'Total ($selectedCount selected)'
                      : 'Total',
                  style: TextStyle(fontSize: 14.sp, color: colors.textSecondary),
                ),
                Text(
                  '₱${formatPeso(total)}',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: brandRed,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            GlossyButton(label: 'Checkout', onPressed: onCheckout),
          ],
        ),
      ),
    );
  }
}
