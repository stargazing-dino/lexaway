import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/question.dart';

class PackDatabase {
  Database? _db;

  Future<void> open(String lang) async {
    await _db?.close();
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/packs/$lang.db';

    if (!File(dbPath).existsSync()) {
      throw StateError('Pack "$lang" not downloaded — use PackManager first');
    }

    _db = await openDatabase(dbPath, readOnly: true);
  }

  Future<List<Question>> loadQuestions({String? level, int limit = 200}) async {
    final db = _db!;
    final where = level != null ? 'WHERE level = ?' : '';
    final args = level != null ? [level] : <String>[];
    final rows = await db.rawQuery(
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
