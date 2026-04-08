import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lexaway/data/pack_manager.dart';
import 'package:lexaway/widgets/pack_tile.dart';
import 'package:lexaway/l10n/app_localizations.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('PackTile', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );
    }

    const fraPack = PackInfo(lang: 'fra', name: 'French', flag: '🇫🇷');
    const localPack = LocalPack(
      lang: 'fra',
      schemaVersion: 1,
      builtAt: '2025-01-01T00:00:00Z',
      sizeBytes: 5 * 1024 * 1024, // 5 MB
    );

    PackTile buildTile({
      PackInfo pack = fraPack,
      LocalPack? local,
      double? packProgress,
      double? voiceProgress,
      bool voiceDownloaded = false,
      bool includeVoice = true,
      VoidCallback? onDownload,
      VoidCallback? onDownloadVoice,
      VoidCallback? onDelete,
      VoidCallback? onSelect,
      ValueChanged<bool>? onToggleVoice,
    }) {
      return PackTile(
        pack: pack,
        local: local,
        packProgress: packProgress,
        voiceProgress: voiceProgress,
        voiceDownloaded: voiceDownloaded,
        includeVoice: includeVoice,
        onToggleVoice: onToggleVoice ?? (_) {},
        onDownload: onDownload ?? () {},
        onDownloadVoice: onDownloadVoice ?? () {},
        onDelete: onDelete ?? () {},
        onSelect: onSelect ?? () {},
      );
    }

    testWidgets('shows language badge', (tester) async {
      await tester.pumpWidget(wrap(buildTile()));
      await tester.pumpAndSettle();
      expect(find.text('FRA'), findsOneWidget);
    });

    testWidgets('shows pack name', (tester) async {
      await tester.pumpWidget(wrap(buildTile()));
      await tester.pumpAndSettle();
      expect(find.text('French'), findsOneWidget);
    });

    // -- Not downloaded state --

    testWidgets('shows download icon when not downloaded', (tester) async {
      await tester.pumpWidget(wrap(buildTile(local: null)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.download_rounded), findsWidgets);
    });

    testWidgets('fires onDownload when tapping download icon', (tester) async {
      var downloaded = false;
      await tester.pumpWidget(wrap(buildTile(
        local: null,
        onDownload: () => downloaded = true,
      )));
      await tester.pumpAndSettle();

      // Tap the download icon button in the sentences trailing
      await tester.tap(find.byIcon(Icons.download_rounded).first);
      expect(downloaded, isTrue);
    });

    // -- Downloaded state --

    testWidgets('shows check icon when downloaded', (tester) async {
      await tester.pumpWidget(wrap(buildTile(local: localPack)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('shows delete button when downloaded', (tester) async {
      await tester.pumpWidget(wrap(buildTile(local: localPack)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('fires onDelete when tapping delete', (tester) async {
      var deleted = false;
      await tester.pumpWidget(wrap(buildTile(
        local: localPack,
        onDelete: () => deleted = true,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(deleted, isTrue);
    });

    testWidgets('shows file size when downloaded', (tester) async {
      await tester.pumpWidget(wrap(buildTile(local: localPack)));
      await tester.pumpAndSettle();
      expect(find.text('5.0 MB'), findsOneWidget);
    });

    // -- Downloading state --

    testWidgets('shows spinner during pack download', (tester) async {
      await tester.pumpWidget(wrap(buildTile(packProgress: 0.5)));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    // -- Voice row (fra has TTS support) --

    testWidgets('shows voice row for supported languages', (tester) async {
      await tester.pumpWidget(wrap(buildTile()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('hides voice row for unsupported languages', (tester) async {
      const unsupported = PackInfo(lang: 'zzz', name: 'Unknown', flag: '?');
      await tester.pumpWidget(wrap(buildTile(pack: unsupported)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    });

    testWidgets('shows voice download button when pack installed but no voice',
        (tester) async {
      var voiceDownloaded = false;
      await tester.pumpWidget(wrap(buildTile(
        local: localPack,
        voiceDownloaded: false,
        onDownloadVoice: () => voiceDownloaded = true,
      )));
      await tester.pumpAndSettle();

      // The voice row should have a download icon
      final downloadIcons = find.byIcon(Icons.download_rounded);
      // Tap the last one (voice row's)
      await tester.tap(downloadIcons.last);
      expect(voiceDownloaded, isTrue);
    });
  });
}
