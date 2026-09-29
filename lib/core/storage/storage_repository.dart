import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads couple media to the private `couple-media` bucket and mints signed
/// URLs on demand (cached). Paths are `{couple_id}/{voice|photos}/{id}.{ext}`.
class StorageRepository {
  StorageRepository(this._client);

  final SupabaseClient _client;
  static const _bucket = 'couple-media';

  final Map<String, _SignedUrl> _cache = {};

  String voicePath(String coupleId, String id) => '$coupleId/voice/$id.m4a';
  String photoPath(String coupleId, String id) => '$coupleId/photos/$id.jpg';

  /// Upload a local file to [objectPath] within the private bucket.
  Future<void> upload(String objectPath, File file, String contentType) async {
    await _client.storage.from(_bucket).upload(
          objectPath,
          file,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
  }

  /// Signed URL for an object path, cached until shortly before expiry.
  Future<String> signedUrl(String objectPath, {int ttlSeconds = 3600}) async {
    final cached = _cache[objectPath];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.url;
    }
    final url =
        await _client.storage.from(_bucket).createSignedUrl(objectPath, ttlSeconds);
    _cache[objectPath] = _SignedUrl(
      url,
      DateTime.now().add(Duration(seconds: ttlSeconds - 300)),
    );
    return url;
  }

  /// Compress an image to a temp JPEG (~1600px, quality 70) before upload.
  /// Returns the compressed file (or the original if compression fails).
  Future<File> compressImage(String srcPath, String id) async {
    try {
      final dir = await getTemporaryDirectory();
      final target = '${dir.path}/compressed_$id.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        srcPath,
        target,
        quality: 70,
        minWidth: 1600,
        minHeight: 1600,
      );
      return result == null ? File(srcPath) : File(result.path);
    } catch (e) {
      // Falls back to the FULL-SIZE file — worth knowing about (upload size).
      debugPrint('image compression failed, uploading original: $e');
      return File(srcPath);
    }
  }
}

class _SignedUrl {
  _SignedUrl(this.url, this.expiresAt);
  final String url;
  final DateTime expiresAt;
}
