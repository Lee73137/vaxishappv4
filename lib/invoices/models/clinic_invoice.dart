/// A single row from `GET /api/clinicname/{username}` — the clinic's full
/// order/invoice history (not just unpaid ones). Carries both the order's
/// workflow status (`status`, e.g. "DELIVERED") and its payment state
/// (`ispaid`/`balance`/`duedate`), so it powers both the Orders and
/// Invoices sections.
class ClinicInvoiceOrder {
  const ClinicInvoiceOrder({
    required this.refnumber,
    required this.status,
    required this.datesold,
    required this.duedate,
    required this.subtotal,
    required this.balance,
    required this.isPaid,
    required this.terms,
    required this.salesrep,
    required this.promoTag,
  });

  final String refnumber;
  final String status;
  final DateTime? datesold;
  final DateTime? duedate;
  final double subtotal;
  final double balance;
  final bool isPaid;
  final String terms;
  final String salesrep;
  final String? promoTag;

  /// True only once the due date has fully passed — compares calendar
  /// dates, not exact time, so an invoice due today isn't flagged overdue
  /// just because it's already past midnight.
  bool get isOverdue {
    if (isPaid || duedate == null) return false;
    final today = DateTime.now();
    final dueDateOnly = DateTime(duedate!.year, duedate!.month, duedate!.day);
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    return dueDateOnly.isBefore(todayDateOnly);
  }

  factory ClinicInvoiceOrder.fromJson(Map<String, dynamic> json) {
    return ClinicInvoiceOrder(
      // The backend returns fixed-length padded strings (e.g. "0034162  ").
      refnumber: json['refnumber']?.toString().trim() ?? '',
      status: json['status']?.toString().trim() ?? '',
      datesold: DateTime.tryParse(json['datesold']?.toString() ?? ''),
      duedate: DateTime.tryParse(json['duedate']?.toString() ?? ''),
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '') ?? 0,
      balance: double.tryParse(json['balance']?.toString() ?? '') ?? 0,
      isPaid: json['ispaid'] == true,
      terms: json['terms']?.toString().trim() ?? '',
      salesrep: json['salesrep']?.toString().trim() ?? '',
      promoTag: (json['vaxelite']?.toString().trim().isNotEmpty ?? false)
          ? json['vaxelite'].toString().trim()
          : null,
    );
  }
}
