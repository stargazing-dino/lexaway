import 'dart:convert';
import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart' as http;
import 'package:sqlite_async/sqlite_async.dart';

import 'download_helper.dart';
import 'hive_keys.dart';

const _baseUrl =
    'https://github.com/lexaway/lexaway-packs/releases/latest/download';

const maxSupportedPackSchema = 1;

enum PackUpdateStatus { notDownloaded, upToDate, updateAvailable, appUpdateRequired }

PackUpdateStatus packUpdateStatus(PackInfo remote, LocalPack? local) {
  if (local == null) return PackUpdateStatus.notDownloaded;
  if (remote.schemaVersion > maxSupportedPackSchema) {
    return PackUpdateStatus.appUpdateRequired;
  }
  if (remote.builtAt != local.builtAt) return PackUpdateStatus.updateAvailable;
  return PackUpdateStatus.upToDate;
}

class PackInfo {
  final String lang;
  final String fromLang;
  final String name;
  final String flag;
  final String builtAt;
  final int schemaVersion;

  const PackInfo({
    required this.lang,
    required this.fromLang,
    required this.name,
    required this.flag,
    required this.builtAt,
    required this.schemaVersion,
  });

  factory PackInfo.fromJson(Map<String, dynamic> json) => PackInfo(
    lang: json['lang'] as String,
    fromLang: json['from_lang'] as String,
    name: json['name'] as String,
    flag: json['flag'] as String,
    builtAt: json['built_at'] as String,
    schemaVersion: json['schema_version'] as int,
  );
}

class LocalPack {
  final String lang;
  final String fromLang;
  final int schemaVersion;
  final String builtAt;
  final int sizeBytes;

  const LocalPack({
    required this.lang,
    required this.fromLang,
    required this.schemaVersion,
    required this.builtAt,
    required this.sizeBytes,
  });

  factory LocalPack.fromJson(String lang, Map<String, dynamic> json) =>
      LocalPack(
        lang: lang,
        fromLang: json['from_lang'] as String,
        schemaVersion: json['schema_version'] as int,
        builtAt: json['built_at'] as String,
        sizeBytes: json['size_bytes'] as int,
      );

  Map<String, dynamic> toJson() => {
    'from_lang': fromLang,
    'schema_version': schemaVersion,
    'built_at': builtAt,
    'size_bytes': sizeBytes,
  };
}

class Manifest {
  final int schemaVersion;
  final List<PackInfo> packs;

  const Manifest({required this.schemaVersion, required this.packs});

  factory Manifest.fromJson(Map<String, dynamic> json) => Manifest(
    schemaVersion: json['schema_version'] as int,
    packs: (json['packs'] as List)
        .map((p) => PackInfo.fromJson(p as Map<String, dynamic>))
        .toList(),
  );
}

class PackManager {
  final Box _box;
  final String packsDir;

  PackManager(this._box, {required this.packsDir});

  // -- Manifest --

  Future<Manifest> fetchManifest() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/manifest.json'));
      if (response.statusCode == 200) {
        _box.put(HiveKeys.manifestCache, response.body);
        return Manifest.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Fall through to cached version
    }

    final cached = _box.get(HiveKeys.manifestCache) as String?;
    if (cached != null) {
      try {
        return Manifest.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {
        _box.delete(HiveKeys.manifestCache);
      }
    }

    throw Exception('No manifest available (network failed, no cache)');
  }

  // -- Download --

  Future<void> downloadPack(
    String lang, {
    required String fromLang,
    void Function(double)? onProgress,
  }) async {
    final dir = packsDir;
    await Directory(dir).create(recursive: true);

    final tmpPath = '$dir/$lang.db.tmp';
    await downloadToFile(
      '$_baseUrl/$lang.db',
      tmpPath,
      onProgress: onProgress,
    );

    final sizeBytes = await File(tmpPath).length();
    await File(tmpPath).rename('$dir/$lang.db');
    await _updateMeta(lang, fromLang, sizeBytes);
  }

  // -- Delete --

  Future<void> deletePack(String lang) async {
    final dir = packsDir;
    final file = File('$dir/$lang.db');
    if (await file.exists()) await file.delete();

    final packs = _getPacks();
    packs.remove(lang);
    _box.put(HiveKeys.packs, packs);
    if (_box.get(HiveKeys.lastUsed) == lang) _box.delete(HiveKeys.lastUsed);
  }

  // -- Local state --

  Map<String, LocalPack> getLocalPacks() {
    final packs = _getPacks();
    return packs.map(
      (lang, data) => MapEntry(
        lang,
        LocalPack.fromJson(lang, Map<String, dynamic>.from(data as Map)),
      ),
    );
  }

  String? get lastUsed => _box.get(HiveKeys.lastUsed) as String?;

  void setLastUsed(String lang) => _box.put(HiveKeys.lastUsed, lang);

  // -- Internals --

  Map<String, dynamic> _getPacks() {
    final raw = _box.get(HiveKeys.packs);
    if (raw == null) return {};
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<void> _updateMeta(String lang, String fromLang, int sizeBytes) async {
    final dbPath = '$packsDir/$lang.db';
    final db = SqliteDatabase(path: dbPath);
    try {
      final rows = await db.getAll(
        "SELECT key, value FROM meta WHERE key IN ('built_at', 'schema_version')",
      );
      final meta = {for (final r in rows) r['key'] as String: r['value'] as String};

      final packs = _getPacks();
      packs[lang] = {
        'from_lang': fromLang,
        'schema_version': int.parse(meta['schema_version'] ?? '1'),
        'built_at': meta['built_at'] ?? '',
        'size_bytes': sizeBytes,
      };
      _box.put(HiveKeys.packs, packs);
      _box.put(HiveKeys.lastUsed, lang);
    } finally {
      await db.close();
    }
  }
}
