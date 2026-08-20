import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/fcm_message_record.dart';

/// Local history of received FCM messages — Firebase itself keeps no
/// server-side inbox, so every message the app sees (foreground or via the
/// background isolate handler) gets persisted here to power the in-app
/// notification list. Every method swallows its own errors and falls back
/// to a safe default, matching CartDatabase's approach.
class NotificationDatabase {
  static final NotificationDatabase _instance = NotificationDatabase._internal();
  factory NotificationDatabase() => _instance;
  NotificationDatabase._internal();

  /// Live unread count, kept in sync by every method below that changes
  /// read/unread state — lets the Dashboard bell badge update immediately
  /// when a push arrives while it's already on screen, instead of only
  /// refreshing on app-resume or after returning from the notifications list.
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'vaxishappv4_notifications.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE fcm_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            messageId TEXT,
            title TEXT,
            body TEXT,
            imageUrl TEXT,
            receivedAt TEXT NOT NULL,
            isRead INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<bool> insert(FCMMessageRecord record) async {
    try {
      final db = await _database;
      await db.insert('fcm_messages', record.toMap());
      await refreshUnreadBadge();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Re-reads the unread count and pushes it to [unreadCountNotifier]. Public
  /// so a screen can force a resync (e.g. on resume) if it suspects it might
  /// have missed an update.
  Future<void> refreshUnreadBadge() async {
    unreadCountNotifier.value = await unreadCount();
  }

  Future<List<FCMMessageRecord>> getAll() async {
    try {
      final db = await _database;
      final rows = await db.query('fcm_messages', orderBy: 'receivedAt DESC');
      return rows.map(FCMMessageRecord.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> unreadCount() async {
    try {
      final db = await _database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as c FROM fcm_messages WHERE isRead = 0',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> markRead(int id) async {
    try {
      final db = await _database;
      await db.update('fcm_messages', {'isRead': 1}, where: 'id = ?', whereArgs: [id]);
      await refreshUnreadBadge();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markReadByMessageId(String messageId) async {
    try {
      final db = await _database;
      await db.update(
        'fcm_messages',
        {'isRead': 1},
        where: 'messageId = ?',
        whereArgs: [messageId],
      );
      await refreshUnreadBadge();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAllRead() async {
    try {
      final db = await _database;
      await db.update('fcm_messages', {'isRead': 1});
      await refreshUnreadBadge();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteOne(int id) async {
    try {
      final db = await _database;
      await db.delete('fcm_messages', where: 'id = ?', whereArgs: [id]);
      await refreshUnreadBadge();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearAll() async {
    try {
      final db = await _database;
      await db.delete('fcm_messages');
      await refreshUnreadBadge();
      return true;
    } catch (_) {
      return false;
    }
  }
}
