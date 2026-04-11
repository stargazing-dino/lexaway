import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:lexaway/data/hive_keys.dart';
import 'package:lexaway/providers.dart';

import 'fixtures/pack_fixtures.dart';

/// Integration tests for the non-destructive schema gate in
/// `ActivePackNotifier._openAndLoad` and `build()`.
///
/// The gate itself is dormant in production (min=max=1). These tests inject
/// `min: 2, max: 2` via `packSchemaBoundsProvider` to exercise the live
/// configuration the refactor PR will activate, without mutating globals.
///
/// Strategy: the pre-check fires *before* any SQLite call, so we use a
/// placeholder file on disk rather than a real sqlite file. If the gate ever
/// regressed to opening the file, the test would fail with a sqlite error
/// instead of the expected null — which is what we want.
void main() {
  late Directory tmpPacksDir;
  late Box box;

  setUp(() async {
    tmpPacksDir = await Directory.systemTemp.createTemp('lexaway_gate_test_');
    box = await Hive.openBox(
      'gate_test_${DateTime.now().microsecondsSinceEpoch}',
      bytes: Uint8List(0),
    );
  });

  tearDown(() async {
    await box.close();
    if (tmpPacksDir.existsSync()) {
      await tmpPacksDir.delete(recursive: true);
    }
  });

  ProviderContainer buildContainer({int min = 2, int max = 2}) {
    return ProviderContainer(
      overrides: [
        hiveBoxProvider.overrideWithValue(box),
        packsDirProvider.overrideWithValue(tmpPacksDir.path),
        packSchemaBoundsProvider.overrideWithValue((min: min, max: max)),
      ],
    );
  }

  group('schema gate (non-destructive)', () {
    test(
        'single stale pack: build() returns null, file and metadata preserved, '
        'lastUsed untouched',
        () async {
      final file = await seedPlaceholderPack(
        packsDir: tmpPacksDir,
        box: box,
        packId: 'eng-fra',
        schemaVersion: 1,
      );
      await box.put(HiveKeys.lastUsed, 'eng-fra');

      final container = buildContainer();
      addTearDown(container.dispose);

      final result = await container.read(activePackProvider.future);

      expect(result, isNull);
      expect(file.existsSync(), isTrue,
          reason: 'pre-check must not delete the file');
      final packs = box.get(HiveKeys.packs) as Map?;
      expect(packs, isNotNull);
      expect(packs!.containsKey('eng-fra'), isTrue,
          reason: 'pre-check must not scrub Hive metadata');
      expect(box.get(HiveKeys.lastUsed), equals('eng-fra'),
          reason: 'lastUsed must survive so user preference resumes after update');

      final notifier = container.read(activePackProvider.notifier);
      expect(notifier.activePackId, isNull);
    });

    test(
        'switchPack() to a stale pack hits the pre-check: returns null, '
        'file and metadata preserved',
        () async {
      // Seed only the stale pack. build() returns null (no compatible pack),
      // then we call switchPack directly to exercise _openAndLoad's pre-check.
      final staleFile = await seedPlaceholderPack(
        packsDir: tmpPacksDir,
        box: box,
        packId: 'eng-fra',
        schemaVersion: 1,
      );

      final container = buildContainer();
      addTearDown(container.dispose);

      // Settle initial build.
      await container.read(activePackProvider.future);

      // Direct switchPack call — bypasses build() and hits _openAndLoad.
      final notifier = container.read(activePackProvider.notifier);
      await notifier.switchPack('eng-fra');

      final state = container.read(activePackProvider);
      expect(state.hasValue, isTrue);
      expect(state.value, isNull,
          reason: 'pre-check must return null instead of opening the file');
      expect(staleFile.existsSync(), isTrue,
          reason: 'pre-check must not delete the file on switchPack');
      final packs = box.get(HiveKeys.packs) as Map?;
      expect(packs!.containsKey('eng-fra'), isTrue,
          reason: 'pre-check must not scrub Hive metadata on switchPack');
    });
  });

  group('multi-pack fallback', () {
    test(
        'stale lastUsed falls through to the next schema-compatible pack '
        'without stranding the user on /packs',
        () async {
      // Stale pack that the user was last using — placeholder is fine
      // because build()'s filter must skip it *before* any sqlite call.
      final staleFile = await seedPlaceholderPack(
        packsDir: tmpPacksDir,
        box: box,
        packId: 'eng-fra',
        schemaVersion: 1,
      );
      // Current pack — real sqlite so _openAndLoad can actually open it.
      await seedRealPack(
        packsDir: tmpPacksDir,
        box: box,
        packId: 'eng-spa',
        schemaVersion: 2,
      );
      await box.put(HiveKeys.lastUsed, 'eng-fra');

      final container = buildContainer();
      addTearDown(container.dispose);

      final result = await container.read(activePackProvider.future);
      expect(result, isNotNull,
          reason: 'build() should fall through to the schema-compatible pack');

      final notifier = container.read(activePackProvider.notifier);
      expect(notifier.activePackId, equals('eng-spa'),
          reason:
              'stale lastUsed should be ignored; filter picks the compatible pack');

      expect(staleFile.existsSync(), isTrue,
          reason:
              'stale pack file must survive — build() filter should have '
              'skipped it entirely');
      final packs = box.get(HiveKeys.packs) as Map?;
      expect(packs!.containsKey('eng-fra'), isTrue,
          reason: 'stale pack metadata preserved so user can re-download later');
    });
  });
}
