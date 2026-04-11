import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../data/world_state_repository.dart';

/// Pre-resolved in main(), overridden in ProviderScope.
final hiveBoxProvider = Provider<Box>((ref) {
  throw UnimplementedError('hiveBoxProvider must be overridden');
});

/// The single persistence gateway for world state. Other code should depend
/// on this rather than reaching into the Hive box directly.
final worldStateRepositoryProvider = Provider<WorldStateRepository>((ref) {
  return WorldStateRepository(ref.watch(hiveBoxProvider));
});

/// Pre-resolved directory paths, overridden in ProviderScope.
final packsDirProvider = Provider<String>((ref) {
  throw UnimplementedError('packsDirProvider must be overridden');
});
final modelsDirProvider = Provider<String>((ref) {
  throw UnimplementedError('modelsDirProvider must be overridden');
});
final tmpDirProvider = Provider<String>((ref) {
  throw UnimplementedError('tmpDirProvider must be overridden');
});
