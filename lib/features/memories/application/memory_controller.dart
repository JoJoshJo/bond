import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/storage_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/memory_models.dart';
import '../data/memory_repository.dart';

final memoryRepositoryProvider = Provider<MemoryRepository>(
  (ref) => MemoryRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(storageRepositoryProvider),
  ),
);

/// A month section of the timeline.
class MemoryGroup {
  const MemoryGroup(this.label, this.memories);
  final String label; // e.g. "September 2026"
  final List<Memory> memories;
}

class MemoryVaultState {
  const MemoryVaultState({
    this.loading = true,
    this.groups = const [],
    this.flashbacks = const [],
    this.saving = false,
  });

  final bool loading;
  final List<MemoryGroup> groups;
  final List<Memory> flashbacks; // "N years ago today"
  final bool saving;

  bool get isEmpty => groups.isEmpty;

  /// Total saved memories across all month groups (for the free-tier cap).
  int get totalCount =>
      groups.fold(0, (sum, g) => sum + g.memories.length);

  MemoryVaultState copyWith({
    bool? loading,
    List<MemoryGroup>? groups,
    List<Memory>? flashbacks,
    bool? saving,
  }) =>
      MemoryVaultState(
        loading: loading ?? this.loading,
        groups: groups ?? this.groups,
        flashbacks: flashbacks ?? this.flashbacks,
        saving: saving ?? this.saving,
      );
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

class MemoryVaultController extends StateNotifier<MemoryVaultState> {
  MemoryVaultController(this._repo, this._coupleId)
      : super(const MemoryVaultState()) {
    _init();
  }

  final MemoryRepository _repo;
  final String _coupleId;
  final _uuid = const Uuid();
  RealtimeChannel? _channel;

  Future<void> _init() async {
    await _refresh();
    _channel = _repo.channel(_coupleId, onChange: _refresh)..subscribe();
  }

  Future<void> _refresh() async {
    final memories = await _repo.fetchMemories(_coupleId);
    if (!mounted) return;
    state = state.copyWith(
      loading: false,
      groups: _group(memories),
      flashbacks: _flashbacks(memories),
    );
  }

  List<MemoryGroup> _group(List<Memory> memories) {
    final groups = <String, List<Memory>>{};
    for (final m in memories) {
      final key = '${_months[m.takenAt.month - 1]} ${m.takenAt.year}';
      (groups[key] ??= []).add(m);
    }
    // memories are already newest-first, so insertion order of keys is correct.
    return groups.entries.map((e) => MemoryGroup(e.key, e.value)).toList();
  }

  List<Memory> _flashbacks(List<Memory> memories) {
    final now = DateTime.now();
    return memories
        .where((m) =>
            m.takenAt.month == now.month &&
            m.takenAt.day == now.day &&
            m.takenAt.year < now.year)
        .toList();
    // TODO(notifications): a daily Edge-Function check on taken_at month/day
    // fires an FCM push for flashbacks when the notifications layer lands.
    // This in-app card is the launch surface.
  }

  Future<String> signedUrl(String path) => _repo.signedUrl(path);

  Future<void> addPhoto(String localPath, String? caption, DateTime takenAt) async {
    state = state.copyWith(saving: true);
    try {
      await _repo.addPhoto(
        coupleId: _coupleId,
        id: _uuid.v4(),
        localPath: localPath,
        takenAt: takenAt,
        caption: caption,
      );
      await _refresh();
    } finally {
      if (mounted) state = state.copyWith(saving: false);
    }
  }

  Future<void> addVideo(String localPath, String? caption, DateTime takenAt) async {
    state = state.copyWith(saving: true);
    try {
      await _repo.addVideo(
        coupleId: _coupleId,
        id: _uuid.v4(),
        localPath: localPath,
        takenAt: takenAt,
        caption: caption,
      );
      await _refresh();
    } finally {
      if (mounted) state = state.copyWith(saving: false);
    }
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) _repo.removeChannel(ch);
    super.dispose();
  }
}

final memoryVaultProvider = StateNotifierProvider.autoDispose
    .family<MemoryVaultController, MemoryVaultState, String>((ref, coupleId) {
  return MemoryVaultController(ref.watch(memoryRepositoryProvider), coupleId);
});
