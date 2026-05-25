import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../core/local_date.dart';
import 'vocab_repository.dart';

/// On-device cache for the Vocabulary tab (calendar + per-day word lists).
class VocabCacheStore {
  VocabCacheStore._();
  static final VocabCacheStore instance = VocabCacheStore._();

  Database? _db;
  String? _userId;

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

  Future<VocabUiSnapshot?> loadUiSnapshot() async {
    final uid = _userId;
    if (uid == null) return null;
    final db = await _database();

    final calRows = await db.query(
      'vocab_calendar',
      where: 'user_id = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (calRows.isEmpty) return null;

    final cal = calRows.first;
    final dates = _decodeDates(cal['dates_json'] as String?);
    final selectedRaw = cal['selected_date'] as String?;
    DateTime selected;
    try {
      selected = selectedRaw != null && selectedRaw.isNotEmpty
          ? parseLocalDate(selectedRaw)
          : DateTime.now();
    } catch (_) {
      selected = DateTime.now();
    }

    final selectedKey = formatLocalDate(selected);
    final entryRows = await db.query(
      'vocab_day_entries',
      where: 'user_id = ? AND local_date = ?',
      whereArgs: [uid, selectedKey],
      limit: 1,
    );
    final entries = entryRows.isEmpty
        ? <VocabEntry>[]
        : _decodeEntries(entryRows.first['entries_json'] as String?);

    return VocabUiSnapshot(
      datesWithWords: dates,
      selectedDate: selected,
      entries: entries,
    );
  }

  Future<List<VocabEntry>?> loadEntriesForDate(DateTime localDay) async {
    final uid = _userId;
    if (uid == null) return null;
    final db = await _database();
    final key = formatLocalDate(localDay);
    final rows = await db.query(
      'vocab_day_entries',
      where: 'user_id = ? AND local_date = ?',
      whereArgs: [uid, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decodeEntries(rows.first['entries_json'] as String?);
  }

  Future<void> saveUiSnapshot({
    required Set<String> datesWithWords,
    required DateTime selectedDate,
    required List<VocabEntry> entries,
  }) async {
    final uid = _userId;
    if (uid == null) return;
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final selectedKey = formatLocalDate(selectedDate);

    await db.insert(
      'vocab_calendar',
      {
        'user_id': uid,
        'dates_json': jsonEncode(datesWithWords.toList()..sort()),
        'selected_date': selectedKey,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.insert(
      'vocab_day_entries',
      {
        'user_id': uid,
        'local_date': selectedKey,
        'entries_json': jsonEncode(entries.map((e) => e.toJson()).toList()),
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveEntriesForDate(
    DateTime localDay,
    List<VocabEntry> entries,
  ) async {
    final uid = _userId;
    if (uid == null) return;
    final db = await _database();
    await db.insert(
      'vocab_day_entries',
      {
        'user_id': uid,
        'local_date': formatLocalDate(localDay),
        'entries_json': jsonEncode(entries.map((e) => e.toJson()).toList()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Set<String> _decodeDates(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  List<VocabEntry> _decodeEntries(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(VocabEntry.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class VocabUiSnapshot {
  const VocabUiSnapshot({
    required this.datesWithWords,
    required this.selectedDate,
    required this.entries,
  });

  final Set<String> datesWithWords;
  final DateTime selectedDate;
  final List<VocabEntry> entries;
}
