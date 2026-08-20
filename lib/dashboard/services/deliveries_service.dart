import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/scheduled_delivery.dart';

class DeliveriesService {
  static const _baseUrl = 'http://shopapi.vaxilifecorp.com';

  /// Not-yet-delivered deliveries scheduled for a clinic — the backend
  /// already excludes anything tagged `delivered = 1` in `qb_deliveries`.
  static Future<List<ScheduledDelivery>> fetchScheduled(String clinicName) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/api/deliveries/scheduled/${Uri.encodeComponent(clinicName)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final List<dynamic> data = jsonDecode(response.body);
      final deliveries = data.map((e) => ScheduledDelivery.fromJson(e)).toList()
        ..sort((a, b) {
          if (a.scheduleDate == null) return 1;
          if (b.scheduleDate == null) return -1;
          return a.scheduleDate!.compareTo(b.scheduleDate!);
        });
      return deliveries;
    } catch (_) {
      return [];
    }
  }
}
