import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../invoices/models/clinic_invoice.dart';
import '../../invoices/services/invoices_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glossy_widgets.dart';

/// Expresses an overdue span in the coarsest unit that reads naturally
/// (days under 2 weeks, weeks under 2 months, months beyond that), so a
/// months-old invoice never gets buried in a small day count.
String _overdueDurationLabel(int daysOverdue) {
  if (daysOverdue >= 60) {
    final months = daysOverdue ~/ 30;
    return '$months month${months == 1 ? '' : 's'}';
  }
  if (daysOverdue >= 14) {
    final weeks = daysOverdue ~/ 7;
    return '$weeks week${weeks == 1 ? '' : 's'}';
  }
  return '$daysOverdue day${daysOverdue == 1 ? '' : 's'}';
}

/// Surfaces every unpaid invoice that's overdue or due within the next 7
/// days, right on the Dashboard so it can't be missed — the combined
/// balance and each invoice number. Renders nothing if there's none.
class OverdueInvoiceAlert extends StatefulWidget {
  const OverdueInvoiceAlert({
    super.key,
    required this.username,
    required this.onTap,
  });

  final String? username;
  final VoidCallback onTap;

  @override
  State<OverdueInvoiceAlert> createState() => _OverdueInvoiceAlertState();
}

class _OverdueInvoiceAlertState extends State<OverdueInvoiceAlert> {
  List<ClinicInvoiceOrder>? _urgent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final username = widget.username;
    if (username == null || username.isEmpty) {
      if (mounted) setState(() => _urgent = []);
      return;
    }

    final history = await InvoicesService.fetchClinicHistory(username);
    if (!mounted) return;

    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 7));
    final urgent =
        history
            .where(
              (i) => !i.isPaid && i.duedate != null && i.duedate!.isBefore(cutoff),
            )
            .toList()
          ..sort((a, b) => a.duedate!.compareTo(b.duedate!));

    setState(() => _urgent = urgent);
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _urgent;
    if (urgent == null || urgent.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final totalDue = urgent.fold(0.0, (sum, i) => sum + i.balance);
    final overdueInvoices = urgent.where((i) => i.isOverdue).toList();
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final notOverdue = urgent.where((i) => !i.isOverdue).toList();
    final dueTodayInvoices = notOverdue.where((i) {
      final dueDateOnly = DateTime(i.duedate!.year, i.duedate!.month, i.duedate!.day);
      return dueDateOnly.isAtSameMomentAs(todayDateOnly);
    }).toList();
    final dueSoonCount = notOverdue.length - dueTodayInvoices.length;

    // Whenever anything is actually overdue, the headline always leads with
    // that (and how overdue, in weeks/months) — it must never read as a
    // soft "due within 7 days" notice when something is weeks or months
    // past due. A same-day due date gets its own "due today" wording too,
    // since folding it into "due within 7 days" undersells it.
    final String headline;
    if (overdueInvoices.isNotEmpty) {
      final maxDaysOverdue = overdueInvoices
          .map((i) => DateTime.now().difference(i.duedate!).inDays)
          .reduce((a, b) => a > b ? a : b);
      final durationLabel = _overdueDurationLabel(maxDaysOverdue);
      final overdueLabel = overdueInvoices.length == 1
          ? '1 invoice overdue by $durationLabel'
          : '${overdueInvoices.length} invoices overdue (up to $durationLabel)';
      final extras = [
        if (dueTodayInvoices.isNotEmpty) '${dueTodayInvoices.length} due today',
        if (dueSoonCount > 0) '$dueSoonCount due soon',
      ];
      headline = extras.isEmpty ? overdueLabel : '$overdueLabel • ${extras.join(' • ')}';
    } else if (dueTodayInvoices.isNotEmpty) {
      final dueTodayLabel = dueTodayInvoices.length == 1
          ? '1 invoice due today'
          : '${dueTodayInvoices.length} invoices due today';
      headline = dueSoonCount > 0 ? '$dueTodayLabel • $dueSoonCount due soon' : dueTodayLabel;
    } else {
      headline = dueSoonCount == 1
          ? '1 invoice due within 7 days'
          : '$dueSoonCount invoices due within 7 days';
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 14.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surface, Colors.red.withValues(alpha: 0.1)],
          ),
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    headline,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TOTAL DUE',
                      style: TextStyle(
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade400,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      '₱${formatPeso(totalDue)}',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: urgent.map((invoice) => _InvoiceChip(invoice: invoice)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceChip extends StatelessWidget {
  const _InvoiceChip({required this.invoice});

  final ClinicInvoiceOrder invoice;

  @override
  Widget build(BuildContext context) {
    final overdue = invoice.isOverdue;
    final color = overdue ? Colors.red : Colors.orange;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        '#${invoice.refnumber} • ₱${formatPeso(invoice.balance)}',
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: overdue ? Colors.red.shade700 : Colors.orange.shade800,
        ),
      ),
    );
  }
}
