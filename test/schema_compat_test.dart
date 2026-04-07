import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexaway/game/components/coin.dart';
import 'package:lexaway/game/components/coin_manager.dart';
import 'package:lexaway/game/components/ground.dart';
import 'package:lexaway/game/lexaway_game.dart';
import 'package:lexaway/main.dart' show hiveSchemaVersion;

/// Fixture-based tests that verify current code can still read persisted data
/// from every shipped schema version. If a code change breaks deserialization,
/// these tests fail — forcing a migration before merge.
///
/// To add a new schema version:
///   1. Copy the latest fixture → hive_vN.json
///   2. Adjust values to match the new shape
///   3. Bump the version constants
///   4. Add migration logic so older fixtures still pass
void main() {
  late Map<String, dynamic> fixture;

  setUp(() {
    final file = File('test/fixtures/hive_v1.json');
    fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  group('Hive box v1 compatibility', () {
    test('fixture version matches current hiveSchemaVersion', () {
      expect(fixture['hive_schema_version'], equals(hiveSchemaVersion));
    });

    test('settings keys deserialize the way providers cast them', () {
      // Providers cast with (box.get(key) as num).toDouble() or as bool/String.
      // Exercise those exact casts here.
      expect((fixture['vol_master'] as num).toDouble(), isA<double>());
      expect((fixture['vol_sfx'] as num).toDouble(), isA<double>());
      expect((fixture['vol_tts'] as num).toDouble(), isA<double>());
      expect(fixture['haptics'] as bool, isA<bool>());
      expect(fixture['gender'] as String, isA<String>());
      expect(fixture['ui_locale'] as String, isA<String>());
    });

    test('progress counters survive the HiveIntNotifier cast', () {
      // HiveIntNotifier does: box.get(key, defaultValue: 0) as int
      expect(fixture['streak'] as int, isA<int>());
      expect(fixture['best_streak'] as int, isA<int>());
      expect(fixture['coins'] as int, isA<int>());
      expect(fixture['steps'] as int, isA<int>());
    });

    test('pack metadata matches PackManager expectations', () {
      final packs = fixture['packs'] as Map<String, dynamic>;
      for (final entry in packs.values) {
        final pack = Map<String, dynamic>.from(entry as Map);
        expect(pack['schema_version'] as int, isA<int>());
        expect(pack['built_at'] as String, isA<String>());
        expect(pack['size_bytes'] as int, isA<int>());
      }
    });

    test('tts model metadata matches TtsManager expectations', () {
      final models = fixture['tts_models'] as Map<String, dynamic>;
      for (final entry in models.values) {
        final model = Map<String, dynamic>.from(entry as Map);
        expect(model['archive_name'] as String, isA<String>());
        expect(model['downloaded_at'] as String, isA<String>());
      }
    });
  });

  group('World state v1 compatibility', () {
    late Map<String, dynamic> world;

    setUp(() {
      world = Map<String, dynamic>.from(fixture['world'] as Map);
    });

    test('version tag is present and understood', () {
      final version = world['_version'] as int;
      expect(version, lessThanOrEqualTo(LexawayGame.worldStateVersion));
    });

    test('Ground.restoreState round-trips fixture data', () {
      final data = Map<String, dynamic>.from(world['ground'] as Map);
      final ground = Ground();

      // Actually call the production deserialization path.
      ground.restoreState(data);
      expect(ground.scrollOffset, equals(1234.5));

      // Verify saveState produces the same shape.
      final resaved = ground.saveState();
      expect(resaved['offset'], equals(ground.scrollOffset));
    });

    test('Coin.fromJson round-trips every coin in the fixture', () {
      final data = Map<String, dynamic>.from(world['coin_manager'] as Map);
      final coins = data['coins'] as List;

      for (final raw in coins) {
        final json = Map<String, dynamic>.from(raw as Map);
        final coin = Coin.fromJson(json);
        // Round-trip: toJson should produce an equivalent map.
        final reserialized = coin.toJson();
        expect(Coin.fromJson(reserialized).worldX, equals(coin.worldX));
        expect(Coin.fromJson(reserialized).type, equals(coin.type));
      }
    });

    test('CoinManager.restoreState accepts fixture data', () {
      final data = Map<String, dynamic>.from(world['coin_manager'] as Map);
      final cm = CoinManager();

      // Actually call the production deserialization path.
      // This will add Coin children and set _nextSpawnAt.
      cm.restoreState(data);

      // Verify it consumed the data without throwing and state is populated.
      final resaved = cm.saveState();
      expect(resaved['next_spawn_at'], equals(data['next_spawn_at']));
    });
  });
}
