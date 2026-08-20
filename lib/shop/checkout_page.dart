import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../widgets/glossy_widgets.dart';
import 'models/cart_item.dart';
import 'providers/cart_provider.dart';
import 'services/checkout_service.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.items,
    required this.clinicName,
  });

  final List<CartItem> items;
  final String clinicName;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _remarksController = TextEditingController();
  bool _isSubmitting = false;

  double get _total =>
      widget.items.fold(0.0, (sum, cartItem) => sum + cartItem.subtotal);

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSubmit() async {
    final itemCount = widget.items.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit order?'),
        content: Text(
          'You are about to submit $itemCount item${itemCount == 1 ? '' : 's'} '
          'totaling ₱${formatPeso(_total)}. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Submit',
              style: TextStyle(color: brandRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final result = await CheckoutService.submit(
      clinicName: widget.clinicName,
      items: widget.items,
      remarks: _remarksController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      // Only remove items from the cart after a confirmed success — a
      // failed/timed-out submission must leave the cart untouched so the
      // user can retry without re-adding everything.
      final cartProvider = context.read<CartProvider>();
      for (final cartItem in widget.items) {
        await cartProvider.removeFromCart(cartItem.item);
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: const Text('Order submitted'),
          content: Text(
            (result.referenceNumber?.isNotEmpty ?? false)
                ? 'Reference No: ${result.referenceNumber}'
                : 'Your order has been submitted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Failed to submit order.'),
          backgroundColor: brandRedDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
      );
    }
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
          'Order Summary',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                ...widget.items.map((cartItem) => _CheckoutTile(cartItem: cartItem)),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remarks (optional)',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: _remarksController,
                        maxLines: 3,
                        style: TextStyle(fontSize: 13.sp),
                        decoration: InputDecoration(
                          hintText: 'Add any notes for this order…',
                          hintStyle: TextStyle(fontSize: 13.sp, color: colors.textTertiary),
                          filled: true,
                          fillColor: colors.scaffoldBackground,
                          contentPadding: EdgeInsets.all(12.w),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total (${widget.items.length} item${widget.items.length == 1 ? '' : 's'})',
                        style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
                      ),
                      Text(
                        '₱${formatPeso(_total)}',
                        style: TextStyle(
                          fontSize: 19.sp,
                          fontWeight: FontWeight.bold,
                          color: brandRed,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  GlossyButton(
                    label: 'Submit Order',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _confirmAndSubmit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutTile extends StatelessWidget {
  const _CheckoutTile({required this.cartItem});

  final CartItem cartItem;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = cartItem.item;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: SizedBox(
              width: 52.w,
              height: 52.w,
              child: item.itemimagepath.isEmpty
                  ? Container(
                      color: colors.surfaceVariant,
                      child: Icon(
                        Icons.medication_liquid_outlined,
                        color: colors.iconInactive,
                        size: 20.sp,
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
                          size: 20.sp,
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
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Qty ${cartItem.quantity} × ₱${formatPeso(cartItem.unitPrice)}'
                  '${cartItem.freeQty > 0 ? '  (+${cartItem.freeQty} free)' : ''}',
                  style: TextStyle(fontSize: 11.5.sp, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '₱${formatPeso(cartItem.subtotal)}',
            style: TextStyle(
              fontSize: 13.5.sp,
              fontWeight: FontWeight.bold,
              color: brandRed,
            ),
          ),
        ],
      ),
    );
  }
}
