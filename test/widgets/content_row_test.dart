import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lexaway/widgets/content_row.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ContentRow', () {
    Widget wrap(Widget child) {
      return MaterialApp(home: Scaffold(body: child));
    }

    ContentRow buildRow({
      String label = 'Sentences',
      String? sizeText,
      bool downloaded = false,
      double? progress,
      VoidCallback? onTap,
      Widget trailing = const SizedBox.shrink(),
      Widget? leading,
      String? title,
    }) {
      return ContentRow(
        icon: Icons.text_snippet_outlined,
        label: label,
        sizeText: sizeText,
        downloaded: downloaded,
        progress: progress,
        onTap: onTap,
        trailing: trailing,
        leading: leading,
        title: title,
      );
    }

    testWidgets('displays label', (tester) async {
      await tester.pumpWidget(wrap(buildRow(label: 'Sentences')));
      expect(find.text('Sentences'), findsOneWidget);
    });

    testWidgets('displays title when provided', (tester) async {
      await tester.pumpWidget(wrap(buildRow(title: 'French')));
      expect(find.text('French'), findsOneWidget);
    });

    testWidgets('hides title when null', (tester) async {
      await tester.pumpWidget(wrap(buildRow(title: null)));
      // Only label text, no title
      expect(find.text('Sentences'), findsOneWidget);
    });

    testWidgets('shows size text when provided', (tester) async {
      await tester.pumpWidget(wrap(buildRow(sizeText: '12.3 MB')));
      expect(find.text('12.3 MB'), findsOneWidget);
    });

    testWidgets('hides size text when null', (tester) async {
      await tester.pumpWidget(wrap(buildRow(sizeText: null)));
      expect(find.text('12.3 MB'), findsNothing);
    });

    testWidgets('shows progress bar when progress is set', (tester) async {
      await tester.pumpWidget(wrap(buildRow(progress: 0.5)));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('hides progress bar when progress is null', (tester) async {
      await tester.pumpWidget(wrap(buildRow(progress: null)));
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('renders leading widget when provided', (tester) async {
      await tester.pumpWidget(wrap(buildRow(
        leading: const Icon(Icons.flag, key: Key('flag')),
      )));
      expect(find.byKey(const Key('flag')), findsOneWidget);
    });

    testWidgets('fires onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(buildRow(onTap: () => tapped = true)));

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('renders trailing widget', (tester) async {
      await tester.pumpWidget(wrap(buildRow(
        trailing: const Icon(Icons.download, key: Key('dl')),
      )));
      expect(find.byKey(const Key('dl')), findsOneWidget);
    });
  });
}
