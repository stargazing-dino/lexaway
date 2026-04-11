import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hive_keys.dart';
import 'bootstrap.dart';

/// Selected character key (e.g. "female/doux") for a given target language,
/// or null if the user hasn't hatched an egg for that language yet.
final characterProvider =
    NotifierProvider.family<CharacterNotifier, String?, String>(
      CharacterNotifier.new,
    );

class CharacterNotifier extends FamilyNotifier<String?, String> {
  @override
  String? build(String lang) {
    return ref.read(hiveBoxProvider).get(HiveKeys.character(lang)) as String?;
  }

  void set(String characterKey) {
    state = characterKey;
    ref.read(hiveBoxProvider).put(HiveKeys.character(arg), characterKey);
  }
}
