import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

/// Pre-resolved in main(), overridden in ProviderScope.
final hiveBoxProvider = Provider<Box>((ref) {
  throw UnimplementedError('hiveBoxProvider must be overridden');
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
