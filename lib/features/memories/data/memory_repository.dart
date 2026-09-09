import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail_plus/video_thumbnail_plus.dart';

import '../../../core/storage/storage_repository.dart';
import 'memory_models.dart';

/// Data access for the shared memory vault. Media goes to the existing private
/// couple-media bucket at {couple_id}/memories/{id}.{ext}; the object path is
/// stored in memories.media_url and signed on view.
class MemoryRepository {
  MemoryRepository(this._client, this._storage);

  final SupabaseClient _client;
  final StorageRepository _storage;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<Memory>> fetchMemories(String coupleId, {int limit = 500}) async {
    final rows = await _client
        .from('memories')
        .select('id, media_url, media_type, caption, taken_at')
        .eq('couple_id', coupleId)
        .order('taken_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List<dynamic>)
        .map((r) => Memory.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<String> signedUrl(String path) => _storage.signedUrl(path);

  /// Add a photo: compress → upload → insert row. Returns nothing; the vault
  /// re-fetches (or realtime pushes it).
  Future<void> addPhoto({
    required String coupleId,
    required String id,
    required String localPath,
    required DateTime takenAt,
    String? caption,
  }) async {
    final compressed = await _storage.compressImage(localPath, id);
    final objectPath = '$coupleId/memories/$id.jpg';
    await _storage.upload(objectPath, compressed, 'image/jpeg');
    await _insertRow(
      coupleId: coupleId,
      path: objectPath,
      mediaType: 'photo',
      takenAt: takenAt,
      caption: caption,
    );
  }

  /// Add a video: upload as-is (no transcoding) → insert row.
  Future<void> addVideo({
    required String coupleId,
    required String id,
    required String localPath,
    required DateTime takenAt,
    String? caption,
  }) async {
    final ext = localPath.split('.').last.toLowerCase();
    final safeExt = (ext == 'mov' || ext == 'mp4') ? ext : 'mp4';
    final objectPath = '$coupleId/memories/$id.$safeExt';
    final contentType = safeExt == 'mov' ? 'video/quicktime' : 'video/mp4';
    await _storage.upload(objectPath, File(localPath), contentType);
    // Best-effort first-frame thumbnail at {coupleId}/memories/{id}_thumb.jpg.
    // Never blocks the video upload — a failure just falls back to the tile
    // placeholder at view time.
    await _uploadThumbnail(coupleId: coupleId, id: id, localVideoPath: localPath);
    await _insertRow(
      coupleId: coupleId,
      path: objectPath,
      mediaType: 'video',
      takenAt: takenAt,
      caption: caption,
    );
  }

  /// Generate a JPEG thumbnail from the local video's first frame and upload it
  /// alongside the video. Swallows all errors — thumbnails are a nicety, not a
  /// requirement for the memory to exist.
  Future<void> _uploadThumbnail({
    required String coupleId,
    required String id,
    required String localVideoPath,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final thumbFile = await VideoThumbnailPlus.thumbnailFile(
        video: localVideoPath,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 600,
        quality: 75,
      );
      if (thumbFile == null) return;
      final file = File(thumbFile);
      if (!await file.exists()) return;
      await _storage.upload(
        '$coupleId/memories/${id}_thumb.jpg',
        file,
        'image/jpeg',
      );
    } catch (_) {
      // Non-fatal: the tile falls back to the play-icon placeholder.
    }
  }

  Future<void> _insertRow({
    required String coupleId,
    required String path,
    required String mediaType,
    required DateTime takenAt,
    String? caption,
  }) async {
    final ymd = '${takenAt.year.toString().padLeft(4, '0')}-'
        '${takenAt.month.toString().padLeft(2, '0')}-'
        '${takenAt.day.toString().padLeft(2, '0')}';
    await _client.from('memories').insert({
      'couple_id': coupleId,
      'media_url': path,
      'media_type': mediaType,
      'caption': (caption != null && caption.trim().isNotEmpty)
          ? caption.trim()
          : null,
      'taken_at': ymd,
    });
  }

  RealtimeChannel channel(String coupleId, {required void Function() onChange}) {
    return _client.channel('memories_$coupleId').onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'memories',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'couple_id',
            value: coupleId,
          ),
          callback: (_) => onChange(),
        );
  }

  Future<void> removeChannel(RealtimeChannel channel) =>
      _client.removeChannel(channel);
}
