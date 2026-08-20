import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/clinic_invoice.dart';
import '../models/invoice_line_item.dart';
import '../models/order_line_item.dart';
import '../models/order_stage.dart';
import '../models/recent_order.dart';

class InvoicesService {
  static const _baseUrl = 'http://shopapi.vaxilifecorp.com';

  /// Live, in-progress bookings straight off `vaxi_clinicbooking` — used
  /// for the Orders tracking list. DELIVERED bookings are excluded here
  /// since they've graduated into an invoice (see [fetchClinicHistory]).
  /// Hits the v4-only endpoint (not /api/recentorders, which the older
  /// vaxishapp app also calls) since this needs the DELIVERED-status
  /// override that endpoint doesn't have — changing the shared one would've
  /// altered behavior for that other app too.
  static Future<List<RecentOrder>> fetchRecentOrders(String clinicName) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/api/recentordersv4/${Uri.encodeComponent(clinicName)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => RecentOrder.fromJson(e))
          .where((order) => !isDeliveredStatus(order.status))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Full QuickBooks-invoice-based history (paid + unpaid) for the
  /// Invoices tab.
  static Future<List<ClinicInvoiceOrder>> fetchClinicHistory(
    String username,
  ) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/api/clinicname/${Uri.encodeComponent(username)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final List<dynamic> data = jsonDecode(response.body);
      final history = data
          .map((e) => ClinicInvoiceOrder.fromJson(e))
          // `status` here is QuickBooks' shipmethod field, which doubles as
          // a void marker — void invoices shouldn't show up in the list at
          // all, not just be styled differently.
          .where((invoice) => invoice.status.trim().toUpperCase() != 'VOID')
          .toList();
      // Most recent first.
      history.sort((a, b) {
        if (a.datesold == null) return 1;
        if (b.datesold == null) return -1;
        return b.datesold!.compareTo(a.datesold!);
      });
      return history;
    } catch (_) {
      return [];
    }
  }

  /// Line-item detail for one invoice, shown when an invoice card is
  /// tapped — the same data vaxishappv2.2's invoice detail view uses.
  static Future<List<InvoiceLineItem>> fetchInvoiceLineItems(
    String refnumber,
  ) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/api/invoice/${Uri.encodeComponent(refnumber.trim())}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => InvoiceLineItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Line-item detail for one in-progress order, shown when a card in the
  /// Orders tracking list is tapped — straight off vaxi_clinicbooking
  /// (one row per line item), not yet an invoice.
  static Future<List<OrderLineItem>> fetchOrderLineItems(
    String drno,
  ) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/api/orderitems/${Uri.encodeComponent(drno.trim())}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => OrderLineItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }
}
