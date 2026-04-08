import 'dart:io';

import 'package:sqlite_async/sqlite_async.dart';

import '../models/question.dart';

class PackDatabase {
  final String packsDir;
  SqliteDatabase? _db;

  PackDatabase({required this.packsDir});

  Future<void> open(String packId) async {
    await close();
    final dbPath = '$packsDir/$packId.db';

    if (!File(dbPath).existsSync()) {
      throw StateError('Pack "$packId" not downloaded — use PackManager first');
    }

    _db = SqliteDatabase(path: dbPath);
    await _migrate();
  }

  /// Idempotent migration for pack schema changes after launch.
  /// Pre-launch, bake new columns directly into build.py instead.
  Future<void> _migrate() async {
    // Add migrations here when users have local packs that can't be rebuilt.
  }

  Future<List<Question>> loadQuestions({String? level, int limit = 200}) async {
    final db = _db!;
    final where = level != null ? 'WHERE level = ?' : '';
    final args = level != null ? [level] : <String>[];
    final rows = await db.getAll(
      'SELECT phrase, translation, blank_index, answer, options '
      'FROM phrases $where ORDER BY RANDOM() LIMIT ?',
      [...args, limit],
    );
    return rows.map((r) => Question.fromMap(r)).toList();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
