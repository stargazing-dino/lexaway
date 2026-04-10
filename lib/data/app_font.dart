/// User-selectable font families bundled with the app.
///
/// All three are shipped as local assets under `assets/fonts/` and declared
/// in `pubspec.yaml`, so the app never needs to hit the network for text
/// rendering — the core requirement for offline-first use.
enum AppFont {
  pixelifySans('Pixelify Sans', 'Pixelify Sans'),
  atkinsonHyperlegible('Atkinson Hyperlegible', 'Atkinson Hyperlegible'),
  nunito('Nunito', 'Nunito');

  const AppFont(this.family, this.displayName);

  /// Family name — must match the `family:` entry in pubspec.yaml exactly.
  final String family;

  /// Label shown in the Settings picker.
  final String displayName;

  static AppFont fromKey(String? key) => AppFont.values.firstWhere(
    (f) => f.name == key,
    orElse: () => pixelifySans,
  );
}
