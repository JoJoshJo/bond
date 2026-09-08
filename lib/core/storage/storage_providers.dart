import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import 'storage_repository.dart';

/// Shared storage repository (couple-media bucket): used by chat media and the
/// memory vault. One instance app-wide, with its own signed-URL cache.
final storageRepositoryProvider = Provider<StorageRepository>(
  (ref) => StorageRepository(ref.watch(supabaseClientProvider)),
);
