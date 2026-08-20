import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/item.dart';

class ItemProvider extends ChangeNotifier {
  static const _baseUrl = 'http://shopapi.vaxilifecorp.com';
  static const _pageSize = 20;

  List<Item> items = [];
  List<String> categories = const ['ALL PRODUCTS'];
  String selectedCategory = 'ALL PRODUCTS';

  bool isLoading = false;
  bool hasMore = true;
  String? errorMessage;

  int _page = 0;
  String _search = '';
  Timer? _debounce;

  Future<void> loadCategories() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/getcategories'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return;

      final List<dynamic> data = jsonDecode(response.body);
      categories = ['ALL PRODUCTS', ...data.map((e) => e.toString())];
      notifyListeners();
    } catch (_) {
      // Category chips are a filter convenience, not critical — leave the
      // default "ALL PRODUCTS" in place if this fails.
    }
  }

  void onSearchChanged(String query) {
    if (selectedCategory != 'ALL PRODUCTS') {
      selectedCategory = 'ALL PRODUCTS';
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _search = query;
      loadItems(refresh: true);
    });
  }

  void selectCategory(String category) {
    selectedCategory = category;
    _search = '';
    loadItems(refresh: true);
  }

  Future<void> loadItems({bool refresh = false}) async {
    if (isLoading) return;
    if (!refresh && !hasMore) return;

    if (refresh) {
      _page = 0;
      items = [];
      hasMore = true;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final uri = Uri.parse('$_baseUrl/api/shopitems').replace(
        queryParameters: {
          'page': _page.toString(),
          if (selectedCategory != 'ALL PRODUCTS') 'category': selectedCategory,
          if (_search.isNotEmpty) 'search': _search,
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final List<dynamic> data = jsonDecode(response.body);
      final newItems = data.map((e) => Item.fromJson(e)).toList();

      items = [...items, ...newItems];
      _page++;
      hasMore = newItems.length >= _pageSize;
    } catch (_) {
      errorMessage =
          'Unable to load products. Check your connection and try again.';
      hasMore = false;
    }

    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
