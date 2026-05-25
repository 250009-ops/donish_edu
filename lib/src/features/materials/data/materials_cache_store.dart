import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// On-device cache for the Materials list (per filter/search key).
class MaterialsCacheStore {
  MaterialsCacheStore._();
  static final MaterialsCacheStore instance = MaterialsCacheStore._();

  Database? _db;
  String? _userId;

  static String cacheKey({
    required String type,
    required String level,
    required String searchQuery,
  }) {
    final q = searchQuery.trim().toLowerCase();
    return '$type|$level|$q';
  }

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'donish_local_cache.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vocab_calendar (
            user_id TEXT PRIMARY KEY,
            dates_json TEXT NOT NULL,
            selected_date TEXT,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE vocab_day_entries (
            user_id TEXT NOT NULL,
            local_date TEXT NOT NULL,
            entries_json TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (user_id, local_date)
          )
        ''');
        await db.execute('''
          CREATE TABLE materials_feed (
            user_id TEXT NOT NULL,
            cache_key TEXT NOT NULL,
            items_json TEXT NOT NULL,
            has_more INTEGER NOT NULL,
            next_offset INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (user_id, cache_key)
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> setActiveUser(String? userId) async {
    _userId = userId;
  }

  String _currentKey({
    required String type,
    required String level,
    required String searchQuery,
  }) =>
      cacheKey(type: type, level: level, searchQuery: searchQuery);

  Future<MaterialsFeedSnapshot?> loadFeed({
    required String type,
    required String level,
    required String searchQuery,
  }) async {
    final uid = _userId;
    if (uid == null) return null;
    final db = await _database();
    final key = _currentKey(
      type: type,
      level: level,
      searchQuery: searchQuery,
    );
    final rows = await db.query(
      'materials_feed',
      where: 'user_id = ? AND cache_key = ?',
      whereArgs: [uid, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return MaterialsFeedSnapshot(
      itemMaps: _decodeItemMaps(r['items_json'] as String?),
      hasMore: (r['has_more'] as int? ?? 0) == 1,
      nextOffset: r['next_offset'] as int? ?? 0,
    );
  }

  Future<void> saveFeed({
    required String type,
    required String level,
    required String searchQuery,
    required List<Map<String, dynamic>> itemMaps,
    required bool hasMore,
    required int nextOffset,
  }) async {
    final uid = _userId;
    if (uid == null) return;
    final db = await _database();
    final key = _currentKey(
      type: type,
      level: level,
      searchQuery: searchQuery,
    );
    await db.insert(
      'materials_feed',
      {
        'user_id': uid,
        'cache_key': key,
        'items_json': jsonEncode(itemMaps),
        'has_more': hasMore ? 1 : 0,
        'next_offset': nextOffset,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  List<Map<String, dynamic>> _decodeItemMaps(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }
}

class MaterialsFeedSnapshot {
  const MaterialsFeedSnapshot({
    required this.itemMaps,
    required this.hasMore,
    required this.nextOffset,
  });

  final List<Map<String, dynamic>> itemMaps;
  final bool hasMore;
  final int nextOffset;
}
