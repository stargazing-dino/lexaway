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
}
