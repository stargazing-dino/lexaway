import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const _baseUrl =
    'https://github.com/lexaway/lexaway-packs/releases/latest/download';

class PackInfo {
  final String lang;
  final String name;
  final String flag;

  const PackInfo({required this.lang, required this.name, required this.flag});

  factory PackInfo.fromJson(Map<String, dynamic> json) => PackInfo(
        lang: json['lang'] as String,
        name: json['name'] as String,
        flag: json['flag'] as String,
      );
}

class LocalPack {
  final String lang;
  final int schemaVersion;
  final String builtAt;
  final int sizeBytes;

  const LocalPack({
    required this.lang,
    required this.schemaVersion,
    required this.builtAt,
    required this.sizeBytes,
  });

  factory LocalPack.fromJson(String lang, Map<String, dynamic> json) =>
      LocalPack(
        lang: lang,
        schemaVersion: json['schema_version'] as int,
        builtAt: json['built_at'] as String,
        sizeBytes: json['size_bytes'] as int,
      );

  Map<String, dynamic> toJson() => {
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
  Future<String> get _packsDir async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/packs';
  }

  Future<File> get _metaFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/packs_meta.json');
  }

  Future<File> get _cachedManifestFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/manifest_cache.json');
  }

  // -- Manifest --

  Future<Manifest> fetchManifest() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/manifest.json'));
      if (response.statusCode == 200) {
        // Cache for offline use
        final cacheFile = await _cachedManifestFile;
        await cacheFile.writeAsString(response.body);
        return Manifest.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {
      // Fall through to cached version
    }

    // Try cached manifest
    final cacheFile = await _cachedManifestFile;
    if (await cacheFile.exists()) {
      final body = await cacheFile.readAsString();
      return Manifest.fromJson(jsonDecode(body) as Map<String, dynamic>);
    }

    throw Exception('No manifest available (network failed, no cache)');
  }

  // -- Download --

  Future<void> downloadPack(
    String lang, {
    void Function(double)? onProgress,
  }) async {
    final dir = await _packsDir;
    await Directory(dir).create(recursive: true);

    final request = http.Request('GET', Uri.parse('$_baseUrl/$lang.db'))
      ..followRedirects = true
      ..maxRedirects = 5;
    final client = http.Client();
    try {
      final streamed = await client.send(request);

      if (streamed.statusCode != 200) {
        throw Exception('Download failed: HTTP ${streamed.statusCode}');
      }

      final totalBytes = streamed.contentLength ?? 0;
      final tmpPath = '$dir/$lang.db.tmp';
      final outFile = File(tmpPath);
      final sink = outFile.openWrite();

      int received = 0;
      try {
        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (totalBytes > 0 && onProgress != null) {
            onProgress(received / totalBytes);
          }
        }
        await sink.close();
      } catch (_) {
        await sink.close();
        if (await outFile.exists()) await outFile.delete();
        rethrow;
      }

      // Atomic rename
      await outFile.rename('$dir/$lang.db');

      // Update local registry
      await _updateMeta(lang, received);
    } finally {
      client.close();
    }
  }

  // -- Delete --

  Future<void> deletePack(String lang) async {
    final dir = await _packsDir;
    final file = File('$dir/$lang.db');
    if (await file.exists()) await file.delete();

    final meta = await _readMeta();
    (meta['packs'] as Map<String, dynamic>).remove(lang);
    if (meta['last_used'] == lang) meta.remove('last_used');
    await _writeMeta(meta);
  }

  // -- Local state --

  Future<Map<String, LocalPack>> getLocalPacks() async {
    final meta = await _readMeta();
    final packs = meta['packs'] as Map<String, dynamic>? ?? {};
    return packs.map((lang, data) =>
        MapEntry(lang, LocalPack.fromJson(lang, data as Map<String, dynamic>)));
  }

  Future<String?> get lastUsed async {
    final meta = await _readMeta();
    return meta['last_used'] as String?;
  }

  Future<void> setLastUsed(String lang) async {
    final meta = await _readMeta();
    meta['last_used'] = lang;
    await _writeMeta(meta);
  }

  // -- Internals --

  Future<Map<String, dynamic>> _readMeta() async {
    final file = await _metaFile;
    if (!await file.exists()) return {'packs': <String, dynamic>{}};
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  Future<void> _writeMeta(Map<String, dynamic> meta) async {
    final file = await _metaFile;
    await file.writeAsString(jsonEncode(meta));
  }

  Future<void> _updateMeta(String lang, int sizeBytes) async {
    final meta = await _readMeta();
    final packs = meta['packs'] as Map<String, dynamic>? ?? {};
    packs[lang] = {
      'schema_version': 1,
      'built_at': DateTime.now().toUtc().toIso8601String(),
      'size_bytes': sizeBytes,
    };
    meta['packs'] = packs;
    meta['last_used'] = lang;
    await _writeMeta(meta);
  }
}
