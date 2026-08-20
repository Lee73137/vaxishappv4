import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/cart_item.dart';

class CheckoutResult {
  const CheckoutResult({required this.success, this.referenceNumber, this.message});

  final bool success;
  final String? referenceNumber;
  final String? message;
}

/// Submits selected cart lines to the same `/api/cart/submit` endpoint
/// vaxishappv2.2 uses, so orders placed from this app land in the same
/// booking pipeline. The server assigns one shared reference number
/// (apprefnum) to the whole batch and echoes the submitted items back.
class CheckoutService {
  static const _url = 'http://shopapi.vaxilifecorp.com/api/cart/submit';

  static Future<CheckoutResult> submit({
    required String clinicName,
    required List<CartItem> items,
    required String remarks,
  }) async {
    final now = DateTime.now();
    final payload = items
        .map(
          (cartItem) => {
            'clinicname': clinicName,
            'datesold': now.toIso8601String(),
            'quantity': cartItem.quantity,
            'itemcode': cartItem.item.itemcode,
            'itemprice': cartItem.unitPrice,
            'subtotal': cartItem.subtotal,
            'freequantity': cartItem.freeQty,
            'apprefnum': '',
            'uploaded': 0,
            'remarks': remarks,
          },
        )
        .toList();

    try {
      final response = await http
          .post(
            Uri.parse(_url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final refNum = data.isNotEmpty
            ? (data.first['apprefnum']?.toString() ?? '')
            : '';
        return CheckoutResult(success: true, referenceNumber: refNum);
      }

      return CheckoutResult(success: false, message: _extractError(response.body));
    } catch (_) {
      return const CheckoutResult(
        success: false,
        message:
            'Unable to reach the server. Please check your connection and try again.',
      );
    }
  }

  static String _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is String) return decoded;
      if (decoded is Map && decoded['Message'] != null) {
        return decoded['Message'].toString();
      }
    } catch (_) {
      // Not JSON — fall through to the raw body.
    }
    return body.isNotEmpty ? body : 'Failed to submit order.';
  }
}
