import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/promo_tier.dart';

/// The tier list is small (a few hundred rows across the whole catalog) and
/// changes rarely, so it's fetched once per app session and cached in
/// memory rather than re-fetched per item or persisted locally.
class PromoTierService {
  static final PromoTierService _instance = PromoTierService._internal();
  factory PromoTierService() => _instance;
  PromoTierService._internal();

  static const _url = 'http://shopapi.vaxilifecorp.com/api/apppromotier';

  Map<String, List<PromoTier>>? _byItemcode;
  Future<Map<String, List<PromoTier>>>? _inFlight;

  Future<List<PromoTier>> getTiersFor(String itemcode) async {
    final all = await _loadAll();
    return all[itemcode] ?? const [];
  }

  Future<Map<String, List<PromoTier>>> _loadAll() {
    if (_byItemcode != null) return Future.value(_byItemcode);
    return _inFlight ??= _fetch().then((tiers) {
      final grouped = <String, List<PromoTier>>{};
      for (final tier in tiers) {
        grouped.putIfAbsent(tier.itemcode, () => []).add(tier);
      }
      _byItemcode = grouped;
      _inFlight = null;
      return grouped;
    });
  }

  Future<List<PromoTier>> _fetch() async {
    try {
      final response = await http
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => PromoTier.fromJson(e)).toList();
    } catch (_) {
      // Tiers are a pricing enhancement, not essential — if this fails, the
      // item detail screen just falls back to the item's plain price.
      return [];
    }
  }
}
