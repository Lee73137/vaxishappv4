import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/cart_item.dart';

/// Local per-user cart storage. Every method swallows its own errors and
/// falls back to a safe default (empty list / no-op) rather than throwing,
/// so a corrupt row or a locked DB never crashes the cart UI — worst case
/// the user just sees an empty cart instead of a broken screen.
class CartDatabase {
  static final CartDatabase _instance = CartDatabase._internal();
  factory CartDatabase() => _instance;
  CartDatabase._internal();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'vaxishappv4_cart.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cart (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            itemcode TEXT NOT NULL,
            itemname TEXT,
            itemdescription TEXT,
            description TEXT,
            itemimagepath TEXT,
            itemprice REAL,
            category TEXT,
            quantity INTEGER NOT NULL,
            freeQty INTEGER NOT NULL DEFAULT 0,
            unitPrice REAL,
            UNIQUE(username, itemcode) ON CONFLICT REPLACE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Existing rows are left as-is; CartItem.fromMap falls back to the
        // catalog price when unitPrice is still null, and freeQty defaults
        // to 0 — so carts from before this migration keep working.
        if (oldVersion < 2) {
          try {
            await db.execute(
              'ALTER TABLE cart ADD COLUMN freeQty INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE cart ADD COLUMN unitPrice REAL');
          } catch (_) {}
        }
      },
    );
  }

  Future<List<CartItem>> getCartItems(String username) async {
    try {
      final db = await _database;
      final rows = await db.query(
        'cart',
        where: 'username = ?',
        whereArgs: [username],
      );
      return rows.map(CartItem.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> upsertCartItem(String username, CartItem cartItem) async {
    try {
      final db = await _database;
      await db.insert(
        'cart',
        cartItem.toMap(username),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeCartItem(String username, String itemcode) async {
    try {
      final db = await _database;
      await db.delete(
        'cart',
        where: 'username = ? AND itemcode = ?',
        whereArgs: [username, itemcode],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearCart(String username) async {
    try {
      final db = await _database;
      await db.delete('cart', where: 'username = ?', whereArgs: [username]);
      return true;
    } catch (_) {
      return false;
    }
  }
}
