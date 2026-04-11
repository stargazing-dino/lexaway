import 'package:flutter_test/flutter_test.dart';
import 'package:lexaway/data/pack_manager.dart';

void main() {
  const remote = PackInfo(
    lang: 'fra',
    fromLang: 'eng',
    name: 'French',
    flag: 'F',
    builtAt: '2026-04-07T00:00:00+00:00',
    schemaVersion: 1,
  );

  const local = LocalPack(
    lang: 'fra',
    fromLang: 'eng',
    schemaVersion: 1,
    builtAt: '2026-04-07T00:00:00+00:00',
    sizeBytes: 1024,
  );

  test('notDownloaded when local is null', () {
    expect(packUpdateStatus(remote, null), PackUpdateStatus.notDownloaded);
  });

  test('upToDate when builtAt matches', () {
    expect(packUpdateStatus(remote, local), PackUpdateStatus.upToDate);
  });

  test('updateAvailable when builtAt differs', () {
    const older = LocalPack(
      lang: 'fra',
      fromLang: 'eng',
      schemaVersion: 1,
      builtAt: '2026-03-01T00:00:00+00:00',
      sizeBytes: 1024,
    );
    expect(packUpdateStatus(remote, older), PackUpdateStatus.updateAvailable);
  });

  test('appUpdateRequired when remote schema exceeds max supported', () {
    const futureRemote = PackInfo(
      lang: 'fra',
      fromLang: 'eng',
      name: 'French',
      flag: 'F',
      builtAt: '2026-04-07T00:00:00+00:00',
      schemaVersion: maxSupportedPackSchema + 1,
    );
    expect(packUpdateStatus(futureRemote, local), PackUpdateStatus.appUpdateRequired);
  });

  // --- localOutdated cases ---
  //
  // The safety net gate is dormant in production (min=max=1). These tests
  // exercise it by injecting min=2 — the configuration the refactor PR will
  // activate — so CI proves the live gate works on every push.

  test('localOutdated at live gate values (min=2, max=2)', () {
    const futureRemote = PackInfo(
      lang: 'fra',
      fromLang: 'eng',
      name: 'French',
      flag: 'F',
      builtAt: '2026-04-07T00:00:00+00:00',
      schemaVersion: 2,
    );
    expect(
      packUpdateStatus(futureRemote, local, min: 2, max: 2),
      PackUpdateStatus.localOutdated,
    );
  });

  test('localOutdated at dormant gate values (schema 0)', () {
    const zeroLocal = LocalPack(
      lang: 'fra',
      fromLang: 'eng',
      schemaVersion: 0,
      builtAt: '2026-04-07T00:00:00+00:00',
      sizeBytes: 1024,
    );
    expect(packUpdateStatus(remote, zeroLocal), PackUpdateStatus.localOutdated);
  });

  test('appUpdateRequired wins over localOutdated', () {
    // Remote schema > max AND local schema < min → app is the blocker.
    const futureRemote = PackInfo(
      lang: 'fra',
      fromLang: 'eng',
      name: 'French',
      flag: 'F',
      builtAt: '2026-04-07T00:00:00+00:00',
      schemaVersion: 3,
    );
    expect(
      packUpdateStatus(futureRemote, local, min: 2, max: 2),
      PackUpdateStatus.appUpdateRequired,
    );
  });

  test('localOutdated wins over updateAvailable', () {
    const futureRemote = PackInfo(
      lang: 'fra',
      fromLang: 'eng',
      name: 'French',
      flag: 'F',
      builtAt: '2026-04-09T00:00:00+00:00',
      schemaVersion: 2,
    );
    // Local is stale schema AND built_at differs — localOutdated takes precedence.
    expect(
      packUpdateStatus(futureRemote, local, min: 2, max: 2),
      PackUpdateStatus.localOutdated,
    );
  });

  group('localPackStatus (pure, no remote)', () {
    test('null → notDownloaded', () {
      expect(localPackStatus(null), PackUpdateStatus.notDownloaded);
    });

    test('schema in window → upToDate', () {
      expect(localPackStatus(local), PackUpdateStatus.upToDate);
    });

    test('schema below min → localOutdated', () {
      expect(
        localPackStatus(local, min: 2, max: 2),
        PackUpdateStatus.localOutdated,
      );
    });

    test('schema above max → localOutdated', () {
      const futureLocal = LocalPack(
        lang: 'fra',
        fromLang: 'eng',
        schemaVersion: 5,
        builtAt: '2026-04-07T00:00:00+00:00',
        sizeBytes: 1024,
      );
      expect(localPackStatus(futureLocal), PackUpdateStatus.localOutdated);
    });
  });
}
