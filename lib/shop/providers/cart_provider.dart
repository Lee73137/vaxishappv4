import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/cart_database.dart';
import '../models/cart_item.dart';
import '../models/deal_calculation.dart';
import '../models/item.dart';
import '../services/promo_tier_service.dart';

/// Per-user cart, backed by local SQLite storage (see [CartDatabase]) so it
/// survives app restarts and is queryable/recoverable without needing a
/// network round-trip. All public methods are safe to call repeatedly and
/// never throw — failures are swallowed and simply leave state unchanged.
class CartProvider extends ChangeNotifier {
  final CartDatabase _db = CartDatabase();
  final List<CartItem> _items = [];
  String _username = '';

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get totalAmount =>
      _items.fold(0.0, (sum, i) => sum + i.subtotal);

  Future<void> _ensureUser() async {
    if (_username.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('auth_user_json') != null
        ? _extractUsername(prefs.getString('auth_user_json')!)
        : '';
  }

  String _extractUsername(String userJson) {
    // Lightweight extraction to avoid importing AuthService here (would
    // create a circular dependency between services and shop features).
    final match = RegExp(r'"UserName"\s*:\s*"([^"]*)"').firstMatch(userJson);
    return match?.group(1) ?? '';
  }

  /// Call after a successful login with the known username, so the cart
  /// doesn't depend on session persistence (works even without Remember Me).
  Future<void> loadForUser(String username) async {
    if (username.isEmpty) return;
    _username = username;
    _items
      ..clear()
      ..addAll(await _db.getCartItems(username));
    notifyListeners();
  }

  /// Clears the in-memory cart (e.g. on logout) without touching the stored
  /// rows, so they're still there next time this user logs back in.
  void resetUser() {
    _username = '';
    _items.clear();
    notifyListeners();
  }

  Future<void> addToCart(Item item, {int quantity = 1}) async {
    await _ensureUser();
    if (_username.isEmpty) return;

    final index = _items.indexWhere((c) => c.item.itemcode == item.itemcode);
    final newQuantity = index == -1
        ? quantity
        : _items[index].quantity + quantity;

    final cartItem = CartItem(item: item, quantity: newQuantity);
    final saved = await _db.upsertCartItem(_username, cartItem);
    if (!saved) return;

    if (index == -1) {
      _items.add(cartItem);
    } else {
      _items[index] = cartItem;
    }
    notifyListeners();
  }

  /// Sets the cart line for [item] to exactly [quantity]/[freeQty]/
  /// [unitPrice] — used by the item detail screen, where the user has
  /// already picked a specific quantity and seen the tier-computed price
  /// for it, rather than incrementally adding to whatever was there before.
  Future<void> setCartLine(
    Item item, {
    required int quantity,
    int freeQty = 0,
    double? unitPrice,
  }) async {
    await _ensureUser();
    if (_username.isEmpty) return;

    if (quantity <= 0) {
      await removeFromCart(item);
      return;
    }

    final cartItem = CartItem(
      item: item,
      quantity: quantity,
      freeQty: freeQty,
      unitPrice: unitPrice,
    );
    final saved = await _db.upsertCartItem(_username, cartItem);
    if (!saved) return;

    final index = _items.indexWhere((c) => c.item.itemcode == item.itemcode);
    if (index == -1) {
      _items.add(cartItem);
    } else {
      _items[index] = cartItem;
    }
    notifyListeners();
  }

  /// Adjusts quantity for an existing line (e.g. the +/- stepper on the
  /// Cart page) and re-runs the tier calculation for the new quantity, so
  /// nudging the count up or down never leaves stale/incorrect pricing —
  /// same rules as [setCartLine], just triggered from a different screen.
  Future<void> updateQuantity(Item item, int quantity) async {
    await _ensureUser();
    if (_username.isEmpty) return;

    if (quantity <= 0) {
      await removeFromCart(item);
      return;
    }

    final index = _items.indexWhere((c) => c.item.itemcode == item.itemcode);
    if (index == -1) return;

    final tiers = await PromoTierService().getTiersFor(item.itemcode);
    final calc = calculateDealBreakdown(tiers, item.itemprice, quantity);

    final cartItem = CartItem(
      item: item,
      quantity: quantity,
      freeQty: calc.freeQuantity,
      unitPrice: calc.appliedUnitPrice,
    );
    final saved = await _db.upsertCartItem(_username, cartItem);
    if (!saved) return;

    _items[index] = cartItem;
    notifyListeners();
  }

  Future<void> removeFromCart(Item item) async {
    await _ensureUser();
    if (_username.isEmpty) return;

    final removed = await _db.removeCartItem(_username, item.itemcode);
    if (!removed) return;

    _items.removeWhere((c) => c.item.itemcode == item.itemcode);
    notifyListeners();
  }

  Future<void> clearCart() async {
    await _ensureUser();
    if (_username.isEmpty) return;

    final cleared = await _db.clearCart(_username);
    if (!cleared) return;

    _items.clear();
    notifyListeners();
  }

  int quantityFor(String itemcode) {
    final match = _items.where((c) => c.item.itemcode == itemcode);
    return match.isEmpty ? 0 : match.first.quantity;
  }
}
