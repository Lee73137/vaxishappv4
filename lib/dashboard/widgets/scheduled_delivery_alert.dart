import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../models/scheduled_delivery.dart';
import '../services/deliveries_service.dart';

/// Surfaces every not-yet-delivered scheduled delivery for the clinic.
/// Styled in blue rather than red — this is logistics info, not a payment
/// alert, so it shouldn't compete visually with [OverdueInvoiceAlert].
/// Renders nothing if there's no scheduled delivery.
class ScheduledDeliveryAlert extends StatefulWidget {
  const ScheduledDeliveryAlert({super.key, required this.clinicName});

  final String? clinicName;

  @override
  State<ScheduledDeliveryAlert> createState() => _ScheduledDeliveryAlertState();
}

class _ScheduledDeliveryAlertState extends State<ScheduledDeliveryAlert> {
  List<ScheduledDelivery>? _deliveries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final clinicName = widget.clinicName;
    if (clinicName == null || clinicName.isEmpty) {
      if (mounted) setState(() => _deliveries = []);
      return;
    }

    final deliveries = await DeliveriesService.fetchScheduled(clinicName);
    if (!mounted) return;
    setState(() => _deliveries = deliveries);
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = _deliveries;
    if (deliveries == null || deliveries.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final next = deliveries.first;
    final headline = deliveries.length == 1
        ? '1 delivery scheduled'
        : '${deliveries.length} deliveries scheduled';
    final nextDateLabel = next.scheduleDate != null
        ? DateFormat('MMM d, yyyy').format(next.scheduleDate!)
        : 'Date TBD';

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surface, Colors.blue.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.1),
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
                  color: Colors.blue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.blue.shade700,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Next: $nextDateLabel'
                      '${next.vehicle.isNotEmpty ? ' • ${next.vehicle}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.sp, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (deliveries.length > 1) ...[
            SizedBox(height: 10.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: deliveries
                  .map((delivery) => _DeliveryChip(delivery: delivery))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeliveryChip extends StatelessWidget {
  const _DeliveryChip({required this.delivery});

  final ScheduledDelivery delivery;

  @override
  Widget build(BuildContext context) {
    final dateLabel = delivery.scheduleDate != null
        ? DateFormat('MMM d').format(delivery.scheduleDate!)
        : 'TBD';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        delivery.drNo.isNotEmpty ? '${delivery.drNo} • $dateLabel' : dateLabel,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }
}
