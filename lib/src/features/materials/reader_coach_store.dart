import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Persists whether the reader swipe coach was shown for a user.
class ReaderCoachStore {
  ReaderCoachStore._();
  static final ReaderCoachStore instance = ReaderCoachStore._();

  Future<File> _flagFile(String userId) async {
    final dir = await getDatabasesPath();
    return File(p.join(dir, 'reader_swipe_coach_$userId.flag'));
  }

  Future<bool> hasSeenSwipeCoach(String userId) async {
    if (userId.isEmpty) return false;
    return (await _flagFile(userId)).exists();
  }

  Future<void> markSwipeCoachSeen(String userId) async {
    if (userId.isEmpty) return;
    await (await _flagFile(userId)).writeAsString('1');
  }
}
