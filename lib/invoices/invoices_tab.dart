import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glossy_widgets.dart';
import 'invoice_detail_page.dart';
import 'models/clinic_invoice.dart';
import 'models/order_stage.dart';
import 'models/recent_order.dart';
import 'order_tracking_page.dart';
import 'services/invoices_service.dart';

class InvoicesTab extends StatefulWidget {
  const InvoicesTab({super.key, this.user});

  final UserSession? user;

  @override
  State<InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends State<InvoicesTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<List<RecentOrder>> _ordersFuture;
  late Future<List<ClinicInvoiceOrder>> _invoicesFuture;

  String get _clinicName =>
      widget.user?.fullname?.trim().isNotEmpty == true
      ? widget.user!.fullname!.trim()
      : (widget.user?.username ?? '');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ordersFuture = InvoicesService.fetchRecentOrders(_clinicName);
    _invoicesFuture = InvoicesService.fetchClinicHistory(
      widget.user?.username ?? '',
    );
  }

  Future<void> _refreshOrders() async {
    final future = InvoicesService.fetchRecentOrders(_clinicName);
    setState(() {
      _ordersFuture = future;
    });
    await future;
  }

  Future<void> _refreshInvoices() async {
    final future = InvoicesService.fetchClinicHistory(
      widget.user?.username ?? '',
    );
    setState(() {
      _invoicesFuture = future;
    });
    await future;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      body: Column(
        children: [
          _GlassyHeader(tabController: _tabController),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  color: brandRed,
                  onRefresh: _refreshOrders,
                  child: FutureBuilder<List<RecentOrder>>(
                    future: _ordersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: brandRed,
                            strokeWidth: 2.4,
                          ),
                        );
                      }
                      return _LazyList<RecentOrder>(
                        items: snapshot.data ?? [],
                        itemBuilder: (context, item) => _OrderCard(order: item),
                        emptyIcon: Icons.local_shipping_outlined,
                        emptyTitle: 'No orders in progress',
                        emptySubtitle:
                            'Orders placed from checkout will show up here until delivered',
                      );
                    },
                  ),
                ),
                RefreshIndicator(
                  color: brandRed,
                  onRefresh: _refreshInvoices,
                  child: FutureBuilder<List<ClinicInvoiceOrder>>(
                    future: _invoicesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: brandRed,
                            strokeWidth: 2.4,
                          ),
                        );
                      }
                      return _LazyList<ClinicInvoiceOrder>(
                        items: snapshot.data ?? [],
                        itemBuilder: (context, item) => _InvoiceCard(invoice: item),
                        emptyIcon: Icons.receipt_outlined,
                        emptyTitle: 'No invoices yet',
                        emptySubtitle: 'Your invoice history will show up here',
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassyHeader extends StatelessWidget {
  const _GlassyHeader({required this.tabController});

  final TabController tabController;

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
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoices',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: brandRed,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: TabBar(
                      controller: tabController,
                      indicator: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [brandRed, brandRedDark],
                        ),
                        borderRadius: BorderRadius.circular(11.r),
                        boxShadow: [
                          BoxShadow(
                            color: brandRed.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: colors.textSecondary,
                      labelStyle: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: const [
                        Tab(text: 'Orders'),
                        Tab(text: 'Invoices'),
                      ],
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

/// Fetches everything once (the backend has no pagination on this endpoint)
/// but only builds/renders a growing slice of the list as the user scrolls,
/// so a long history doesn't build hundreds of cards up front.
class _LazyList<T> extends StatefulWidget {
  const _LazyList({
    required this.items,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.pageSize = 15,
    super.key,
  });

  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final int pageSize;

  @override
  State<_LazyList<T>> createState() => _LazyListState<T>();
}

class _LazyListState<T> extends State<_LazyList<T>> {
  late int _visibleCount;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.pageSize.clamp(0, widget.items.length);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _LazyList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _visibleCount = widget.pageSize.clamp(0, widget.items.length);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final nearBottom =
        _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200;
    if (nearBottom && _visibleCount < widget.items.length) {
      setState(() {
        _visibleCount = (_visibleCount + widget.pageSize).clamp(
          0,
          widget.items.length,
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return _EmptyState(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        subtitle: widget.emptySubtitle,
      );
    }

    final visible = widget.items.take(_visibleCount).toList();
    final hasMore = _visibleCount < widget.items.length;

    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.all(16.w),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: visible.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, _) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        if (index >= visible.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: const Center(
              child: CircularProgressIndicator(color: brandRed, strokeWidth: 2.2),
            ),
          );
        }
        return widget.itemBuilder(context, visible[index]);
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final RecentOrder order;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dateLabel = order.orderdate != null
        ? DateFormat('MMM d, yyyy').format(order.orderdate!)
        : '—';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderTrackingPage(order: order)),
        ),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.surface, brandRed.withValues(alpha: 0.06)],
            ),
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
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: brandRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_rounded, color: brandRed, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.refnumber.isNotEmpty ? '#${order.refnumber}' : 'Order',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      dateLabel,
                      style: TextStyle(fontSize: 11.5.sp, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₱${formatPeso(order.amount)}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: brandRed,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  _StatusChip(status: order.status),
                ],
              ),
              SizedBox(width: 4.w),
              Icon(Icons.chevron_right_rounded, color: colors.iconInactive, size: 20.sp),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toUpperCase();
    late final Color bg;
    late final Color fg;
    late final IconData icon;

    if (isDeliveredStatus(status)) {
      bg = Colors.green.shade50;
      fg = Colors.green.shade700;
      icon = Icons.check_circle_rounded;
    } else if (normalized == 'ON-HOLD') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
      icon = Icons.pause_circle_outline_rounded;
    } else if (normalized == 'OUT FOR DELIVERY' ||
        normalized == 'AWAITING FOR DELIVERY') {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade700;
      icon = Icons.local_shipping_outlined;
    } else if (normalized == 'PREPARATION' || normalized == 'FOR DISCOUNTING') {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade800;
      icon = Icons.inventory_2_outlined;
    } else if (normalized == 'INITIAL') {
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade700;
      icon = Icons.receipt_long_rounded;
    } else {
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade600;
      icon = Icons.help_outline_rounded;
    }

    final label = status.isNotEmpty ? status : 'Awaiting';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.sp, color: fg),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});

  final ClinicInvoiceOrder invoice;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final overdue = invoice.isOverdue;
    final paid = invoice.isPaid;
    final soldLabel = invoice.datesold != null
        ? DateFormat('MMM d, yyyy').format(invoice.datesold!)
        : '—';
    final dueLabel = invoice.duedate != null
        ? DateFormat('MMM d, yyyy').format(invoice.duedate!)
        : '—';
    final accent = overdue ? Colors.red : (paid ? Colors.green : brandRed);
    final accentDark = overdue
        ? Colors.red.shade700
        : (paid ? Colors.green.shade700 : brandRed);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoice: invoice)),
        ),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.surface, accent.withValues(alpha: 0.08)],
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
              Row(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      paid ? Icons.check_circle_outline_rounded : Icons.receipt_outlined,
                      color: accentDark,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      invoice.refnumber.isNotEmpty ? 'Invoice #${invoice.refnumber}' : 'Invoice',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                  _Tag(
                    label: overdue ? 'OVERDUE' : (paid ? 'PAID' : 'UNPAID'),
                    color: overdue
                        ? Colors.red
                        : (paid ? Colors.green : Colors.orange),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: colors.overlay.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Expanded(child: _MiniInfo(label: 'DATE SOLD', value: soldLabel)),
                    Expanded(child: _MiniInfo(label: 'DUE DATE', value: dueLabel)),
                    Expanded(
                      child: _MiniInfo(
                        label: 'TERMS',
                        value: invoice.terms.isNotEmpty ? invoice.terms : '—',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6.w,
                      runSpacing: 4.h,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (invoice.salesrep.isNotEmpty)
                          _Pill(icon: Icons.badge_outlined, label: invoice.salesrep),
                        if (invoice.promoTag != null)
                          _Pill(icon: Icons.local_offer_outlined, label: invoice.promoTag!),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        paid ? 'AMOUNT' : 'BALANCE',
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          color: colors.textTertiary,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        '₱${formatPeso(paid ? invoice.subtotal : invoice.balance)}',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: accentDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8.5.sp,
            fontWeight: FontWeight.w700,
            color: colors.textTertiary,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: brandRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.sp, color: brandRed),
          SizedBox(width: 4.w),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: brandRed),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w800,
          color: color.shade700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
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
                  child: Icon(icon, size: 36.sp, color: brandRed),
                ),
                SizedBox(height: 16.h),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
