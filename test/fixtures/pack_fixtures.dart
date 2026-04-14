import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:lexaway/data/hive_keys.dart';
import 'package:sqlite_async/sqlite_async.dart';

/// Test fixtures for pack files and their Hive metadata.
///
/// Two flavors:
///  - [seedPlaceholderPack] writes a non-sqlite placeholder file. Use when
///    the code under test must bail out *before* any sqlite call (e.g. the
///    schema gate pre-check). If anything ever tries to open the file, tests
///    fail loudly with a sqlite error — which is the point.
///  - [seedRealPack] writes a real sqlite file matching the current v1 schema
///    (meta + phrases tables with one row). Use when the code under test is
///    expected to successfully open and read questions.
///
/// Both helpers also seed the corresponding Hive `packs` map entry via
/// [seedHivePackMeta].

/// Seeds a single entry in the Hive `packs` map.
Future<void> seedHivePackMeta(
  Box box, {
  required String packId,
  required int schemaVersion,
  required int sizeBytes,
  String builtAt = '2026-04-07T00:00:00+00:00',
}) async {
  final existing =
      Map<String, dynamic>.from((box.get(HiveKeys.packs) as Map?) ?? {});
  existing[packId] = {
    'schema_version': schemaVersion,
    'built_at': builtAt,
    'size_bytes': sizeBytes,
  };
  await box.put(HiveKeys.packs, existing);
}

/// Writes a placeholder (non-sqlite) pack file and seeds Hive metadata.
/// The file is intentionally unreadable by sqlite so any accidental open
/// attempt fails loudly.
Future<File> seedPlaceholderPack({
  required Directory packsDir,
  required Box box,
  required String packId,
  required int schemaVersion,
  String builtAt = '2026-04-07T00:00:00+00:00',
}) async {
  final file = File('${packsDir.path}/$packId.db');
  await file.writeAsString('placeholder');
  await seedHivePackMeta(
    box,
    packId: packId,
    schemaVersion: schemaVersion,
    sizeBytes: await file.length(),
    builtAt: builtAt,
  );
  return file;
}

/// Writes a real sqlite pack file matching the current v1 schema and seeds
/// Hive metadata. The file contains one phrases row so `loadQuestions`
/// returns a non-empty result.
///
/// When the v1→v2 refactor lands, add a sibling `seedRealPackV2` helper here
/// rather than parameterizing this one — the table shapes diverge.
Future<File> seedRealPack({
  required Directory packsDir,
  required Box box,
  required String packId,
  required int schemaVersion,
  String builtAt = '2026-04-07T00:00:00+00:00',
}) async {
  final path = '${packsDir.path}/$packId.db';
  final db = SqliteDatabase(path: path);
  try {
    await db.execute(
        'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await db.execute(
        "INSERT INTO meta (key, value) VALUES ('schema_version', ?)",
        [schemaVersion.toString()]);
    await db.execute(
        "INSERT INTO meta (key, value) VALUES ('built_at', ?)", [builtAt]);
    // Mirrors the v1 `phrases` schema in lexaway-packs/build.py — keep in
    // sync with that file if the real build ever adds NOT NULL columns.
    await db.execute('''
      CREATE TABLE phrases (
        id INTEGER PRIMARY KEY,
        phrase TEXT NOT NULL,
        translation TEXT NOT NULL,
        blank_index INTEGER NOT NULL,
        answer TEXT NOT NULL,
        answer_pos TEXT NOT NULL,
        options TEXT NOT NULL,
        level TEXT NOT NULL DEFAULT 'beginner',
        easiness REAL NOT NULL DEFAULT 2.5,
        interval_days INTEGER NOT NULL DEFAULT 0,
        repetitions INTEGER NOT NULL DEFAULT 0,
        next_review TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute(
      'INSERT INTO phrases (phrase, translation, blank_index, answer, '
      'answer_pos, options, level) VALUES (?, ?, ?, ?, ?, ?, ?)',
      ['hola mundo', 'hello world', 0, 'hola', 'NOUN', '["hola","adios"]', 'beginner'],
    );
  } finally {
    await db.close();
  }
  final file = File(path);
  await seedHivePackMeta(
    box,
    packId: packId,
    schemaVersion: schemaVersion,
    sizeBytes: await file.length(),
    builtAt: builtAt,
  );
  return file;
}
