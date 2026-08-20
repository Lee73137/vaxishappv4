import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../widgets/glossy_widgets.dart';
import 'models/clinic_invoice.dart';
import 'models/invoice_line_item.dart';
import 'models/order_stage.dart';
import 'services/invoices_service.dart';

class InvoiceDetailPage extends StatefulWidget {
  const InvoiceDetailPage({super.key, required this.invoice});

  final ClinicInvoiceOrder invoice;

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  late Future<List<InvoiceLineItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = InvoicesService.fetchInvoiceLineItems(widget.invoice.refnumber);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final invoice = widget.invoice;
    final overdue = invoice.isOverdue;
    final paid = invoice.isPaid;
    final badgeTextColor = overdue
        ? Colors.red.shade700
        : (paid ? Colors.green.shade700 : brandRed);
    final dateLabel = invoice.duedate != null
        ? DateFormat('MMM d, yyyy').format(invoice.duedate!)
        : '—';

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: Text(
          'Invoice Details',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
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
                        invoice.refnumber.isNotEmpty
                            ? 'Invoice #${invoice.refnumber}'
                            : 'Invoice',
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
                        overdue ? 'OVERDUE' : (paid ? 'PAID' : 'UNPAID'),
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w800,
                          color: badgeTextColor,
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
                      child: _InfoBlock(
                        label: paid ? 'DATE PAID' : 'DUE DATE',
                        value: dateLabel,
                      ),
                    ),
                    _InfoBlock(
                      label: paid ? 'AMOUNT' : 'BALANCE',
                      value: '₱${formatPeso(paid ? invoice.subtotal : invoice.balance)}',
                      alignEnd: true,
                    ),
                  ],
                ),
                if (invoice.datesold != null ||
                    invoice.terms.isNotEmpty ||
                    invoice.salesrep.isNotEmpty) ...[
                  SizedBox(height: 14.h),
                  Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      if (invoice.datesold != null)
                        Expanded(
                          child: _InfoBlock(
                            label: 'DATE SOLD',
                            value: DateFormat('MMM d, yyyy').format(invoice.datesold!),
                          ),
                        ),
                      if (invoice.terms.isNotEmpty)
                        Expanded(
                          child: _InfoBlock(label: 'TERMS', value: invoice.terms),
                        ),
                      if (invoice.salesrep.isNotEmpty)
                        _InfoBlock(
                          label: 'SALES REP',
                          value: invoice.salesrep,
                          alignEnd: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Items',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10.h),
          FutureBuilder<List<InvoiceLineItem>>(
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

              return Column(
                children: items
                    .map((item) => _LineItemTile(item: item))
                    .toList(),
              );
            },
          ),
          // invoice.status is the raw qb_invoices.shipmethod value — once
          // it's DELIVERED, this order has already graduated out of the
          // Orders tab's tracking timeline entirely (delivered orders are
          // filtered out of that list), so this is the only place left that
          // can tell the clinic the order actually arrived.
          if (isDeliveredStatus(invoice.status)) ...[
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
                      'DELIVERED',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

class _LineItemTile extends StatelessWidget {
  const _LineItemTile({required this.item});

  final InvoiceLineItem item;

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
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
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
