import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';

import 'hive_keys.dart';
import 'world_state.dart';

/// The one and only code path that reads or writes persistent world state.
///
/// One instance per target language — each language pack gets its own dino
/// world (position, biome, picked-up coins). Game code should never touch
/// [HiveKeys.world] directly — go through this repository so persistence
/// concerns stay in one place.
class WorldStateRepository {
  final Box _box;
  final String _lang;

  WorldStateRepository(this._box, this._lang);

  String get _key => HiveKeys.world(_lang);

  /// Returns the saved world state, or null if no save exists or the stored
  /// value is corrupt. On corruption this logs and treats it as a fresh
  /// start — silent progress loss is worse than loud, but crashing at boot
  /// is worse still.
  WorldState? load() {
    final Object? raw;
    try {
      raw = _box.get(_key);
    } catch (e) {
      debugPrint('world_state_repository: load failed ($e)');
      return null;
    }
    if (raw == null) return null;
    if (raw is! Map) {
      debugPrint('world_state_repository: stored value is ${raw.runtimeType}, '
          'expected Map — discarding');
      return null;
    }
    final state = WorldState.fromMap(raw);
    if (state == null) {
      debugPrint('world_state_repository: stored map failed schema check — '
          'discarding');
    }
    return state;
  }

  void save(WorldState state) {
    _box.put(_key, state.toMap());
  }
}
