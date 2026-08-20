/// A row from `GET /api/recentorders/{clinicname}` — live workflow status
/// straight off `vaxi_clinicbooking` (joined with `vaxi_status`), as
/// opposed to the QuickBooks-invoice-derived history used for Invoices.
/// Once a booking reaches DELIVERED it graduates into an invoice instead,
/// so this feed is filtered to exclude that status.
class RecentOrder {
  const RecentOrder({
    required this.refnumber,
    required this.status,
    required this.orderdate,
    required this.amount,
  });

  final String refnumber;
  final String status;
  final DateTime? orderdate;
  final double amount;

  factory RecentOrder.fromJson(Map<String, dynamic> json) {
    return RecentOrder(
      refnumber: json['refnumber']?.toString().trim() ?? '',
      status: json['status']?.toString().trim() ?? '',
      orderdate: DateTime.tryParse(json['orderdate']?.toString() ?? ''),
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
    );
  }
}
