import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../core/word_normalizer.dart';

/// On-device mirror of the user's word lexicon for instant reader lookups.
class WordLexiconEntry {
  const WordLexiconEntry({
    required this.word,
    required this.translationBaseUz,
    required this.savedForPractice,
  });

  final String word;
  final String translationBaseUz;
  final bool savedForPractice;
}

class WordLexiconStore {
  WordLexiconStore._();
  static final WordLexiconStore instance = WordLexiconStore._();

  Database? _db;
  String? _userId;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'donish_word_lexicon.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE word_lexicon (
            user_id TEXT NOT NULL,
            word TEXT NOT NULL,
            translation_base_uz TEXT NOT NULL,
            saved_for_practice INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (user_id, word)
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> setActiveUser(String? userId) async {
    _userId = userId;
    if (userId == null) return;
    final db = await _database();
    await db.delete(
      'word_lexicon',
      where: 'user_id != ?',
      whereArgs: [userId],
    );
  }

  Future<void> clearAll() async {
    final db = await _database();
    await db.delete('word_lexicon');
    _userId = null;
  }

  Future<WordLexiconEntry?> lookup(String word) async {
    final uid = _userId;
    if (uid == null) return null;
    final normalized = normalizeTappedWord(word);
    if (normalized.isEmpty) return null;
    final db = await _database();
    final rows = await db.query(
      'word_lexicon',
      where: 'user_id = ? AND word = ?',
      whereArgs: [uid, normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return WordLexiconEntry(
      word: r['word'] as String,
      translationBaseUz: r['translation_base_uz'] as String,
      savedForPractice: (r['saved_for_practice'] as int? ?? 0) == 1,
    );
  }

  Future<Map<String, WordLexiconEntry>> allForUser() async {
    final uid = _userId;
    if (uid == null) return {};
    final db = await _database();
    final rows = await db.query(
      'word_lexicon',
      where: 'user_id = ?',
      whereArgs: [uid],
    );
    final map = <String, WordLexiconEntry>{};
    for (final r in rows) {
      final word = r['word'] as String;
      map[word] = WordLexiconEntry(
        word: word,
        translationBaseUz: r['translation_base_uz'] as String,
        savedForPractice: (r['saved_for_practice'] as int? ?? 0) == 1,
      );
    }
    return map;
  }

  Future<void> upsert({
    required String word,
    required String translationBaseUz,
    required bool savedForPractice,
  }) async {
    final uid = _userId;
    if (uid == null) return;
    final normalized = normalizeTappedWord(word);
    if (normalized.isEmpty) return;
    final db = await _database();
    await db.insert(
      'word_lexicon',
      {
        'user_id': uid,
        'word': normalized,
        'translation_base_uz': translationBaseUz.trim(),
        'saved_for_practice': savedForPractice ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceAllFromServer(List<Map<String, dynamic>> words) async {
    final uid = _userId;
    if (uid == null) return;
    final db = await _database();
    final batch = db.batch();
    batch.delete('word_lexicon', where: 'user_id = ?', whereArgs: [uid]);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final w in words) {
      final word = normalizeTappedWord(w['word'] as String? ?? '');
      if (word.isEmpty) continue;
      batch.insert('word_lexicon', {
        'user_id': uid,
        'word': word,
        'translation_base_uz':
            (w['translation_base_uz'] as String? ?? '').trim(),
        'saved_for_practice': w['saved_for_practice'] == true ? 1 : 0,
        'updated_at': now,
      });
    }
    await batch.commit(noResult: true);
  }
}
