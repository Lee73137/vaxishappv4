import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../widgets/glossy_widgets.dart';
import 'models/order_line_item.dart';
import 'models/order_stage.dart';
import 'models/recent_order.dart';
import 'services/invoices_service.dart';

class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({super.key, required this.order});

  final RecentOrder order;

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  late Future<List<OrderLineItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = InvoicesService.fetchOrderLineItems(widget.order.refnumber);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final order = widget.order;
    final delivered = isDeliveredStatus(order.status);
    final reachedCount = reachedStageCount(order.status);
    final dateLabel = order.orderdate != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(order.orderdate!)
        : '—';

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: Text(
          'Track Order',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 32.h),
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [brandRed, brandRedDark],
              ),
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: brandRed.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        order.refnumber.isNotEmpty
                            ? 'Order #${order.refnumber}'
                            : 'Order',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        order.status.isNotEmpty ? order.status.toUpperCase() : 'AWAITING',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                          color: brandRed,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: _InfoBlock(label: 'ORDER DATE', value: dateLabel),
                    ),
                    _InfoBlock(
                      label: 'AMOUNT',
                      value: '₱${formatPeso(order.amount)}',
                      alignEnd: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          Container(
            padding: EdgeInsets.fromLTRB(18.w, 20.w, 18.w, 6.w),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < kOrderStages.length; i++)
                  _TimelineStep(
                    label: displayLabelForOrderStage(kOrderStages[i]),
                    icon: iconForOrderStage(kOrderStages[i]),
                    reached: i < reachedCount,
                    isCurrent: !delivered && i == reachedCount - 1,
                    isFirst: i == 0,
                    isLast: i == kOrderStages.length - 1,
                    subtitle: i == 0 && order.orderdate != null
                        ? dateLabel
                        : (!delivered && i == reachedCount - 1
                              ? 'In progress'
                              : (i < reachedCount ? 'Completed' : 'Pending')),
                  ),
              ],
            ),
          ),
          if (delivered) ...[
            SizedBox(height: 16.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 22.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Delivered',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 24.h),
          Text(
            'Items',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
          ),
          SizedBox(height: 10.h),
          FutureBuilder<List<OrderLineItem>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 30.h),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: brandRed,
                      strokeWidth: 2.4,
                    ),
                  ),
                );
              }

              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: Text(
                    'No item details available.',
                    style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
                  ),
                );
              }

              final total = items.fold<double>(0, (sum, item) => sum + item.amount);

              return Column(
                children: [
                  ...items.map((item) => _OrderLineItemTile(item: item)),
                  SizedBox(height: 4.h),
                  _OrderTotalRow(total: total),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.75),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _OrderLineItemTile extends StatelessWidget {
  const _OrderLineItemTile({required this.item});

  final OrderLineItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  item.itemname.isNotEmpty ? item.itemname : 'Item',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
                SizedBox(height: 4.h),
                if (item.isFreeLine)
                  Text(
                    '+${item.quantity} free',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700,
                    ),
                  )
                else
                  Text(
                    'Qty ${item.quantity} × ₱${formatPeso(item.rate)}',
                    style: TextStyle(fontSize: 11.5.sp, color: colors.textSecondary),
                  ),
              ],
            ),
          ),
          Text(
            '₱${formatPeso(item.amount)}',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: brandRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTotalRow extends StatelessWidget {
  const _OrderTotalRow({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
          ),
          Text(
            '₱${formatPeso(total)}',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: brandRed),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.icon,
    required this.reached,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
    required this.subtitle,
  });

  final String label;
  final IconData icon;
  final bool reached;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;
  final String subtitle;

  // Three-state progress color: pending stages stay neutral gray; a stage
  // that's already been passed (reached but no longer current) shows a
  // lighter green so it visibly recedes; the current stage is solid,
  // darker green so it's unmistakably "you are here" — matches how a
  // delivery/shipment tracker is expected to read at a glance.
  static const _currentGreen = Color(0xFF2E7D32);
  static const _passedGreen = Color(0xFFA5D6A7);
  static const _passedGreenIcon = Color(0xFF1B5E20);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final markerSize = isCurrent ? 44.w : 34.w;
    final passed = reached && !isCurrent;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44.w,
            child: Column(
              children: [
                Container(
                  width: markerSize,
                  height: markerSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isCurrent
                        ? const LinearGradient(colors: [_currentGreen, Color(0xFF1B5E20)])
                        : null,
                    color: passed ? _passedGreen : (reached ? null : colors.surface),
                    border: reached
                        ? null
                        : Border.all(color: colors.divider, width: 1.5),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: _currentGreen.withValues(alpha: 0.4),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    passed ? Icons.check_rounded : icon,
                    size: isCurrent ? 20.sp : 16.sp,
                    color: isCurrent
                        ? Colors.white
                        : (passed ? _passedGreenIcon : colors.iconInactive),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.w,
                      margin: EdgeInsets.symmetric(vertical: 4.h),
                      color: reached ? _passedGreen : colors.divider,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: isCurrent ? 10.h : 6.h,
                bottom: isLast ? 20.h : 26.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
                      color: reached ? colors.textPrimary : colors.textTertiary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isCurrent
                          ? _currentGreen
                          : (passed ? _passedGreenIcon : colors.textTertiary),
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    ),
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
