import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../data/chat_message.dart';
import '../../../../core/storage/storage_repository.dart';

/// Image bubble: shows the local file while uploading, else a signed-URL
/// network image. Tap → full-screen viewer.
class ImageBubble extends StatelessWidget {
  const ImageBubble({
    super.key,
    required this.message,
    required this.storage,
  });

  final ChatMessage message;
  final StorageRepository storage;

  @override
  Widget build(BuildContext context) {
    final local = message.localPath;
    final hasLocal = local != null && File(local).existsSync();

    return Semantics(
      button: true,
      label: 'Photo, open full screen',
      child: GestureDetector(
      onTap: () => _openViewer(context, hasLocal ? local : null),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240, maxHeight: 300),
          child: hasLocal
              ? Image.file(File(local), fit: BoxFit.cover)
              : _remote(),
        ),
        ),
      ),
    );
  }

  Widget _remote() {
    if (message.content == null) return _placeholder();
    return FutureBuilder<String>(
      future: storage.signedUrl(message.content!),
      builder: (context, snap) {
        if (!snap.hasData) return _placeholder();
        return Image.network(
          snap.data!,
          fit: BoxFit.cover,
          loadingBuilder: (c, child, progress) =>
              progress == null ? child : _placeholder(),
          errorBuilder: (c, e, s) => _placeholder(broken: true),
        );
      },
    );
  }

  Widget _placeholder({bool broken = false}) {
    return Container(
      height: 200,
      width: 240,
      color: AppColors.surfaceAlt,
      child: Icon(
        broken ? Icons.broken_image_outlined : Icons.image_outlined,
        color: AppColors.inkFaint,
        size: 32,
      ),
    );
  }

  void _openViewer(BuildContext context, String? localPath) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ImageViewer(
        message: message,
        storage: storage,
        localPath: localPath,
      ),
    ));
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({
    required this.message,
    required this.storage,
    required this.localPath,
  });

  final ChatMessage message;
  final StorageRepository storage;
  final String? localPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: localPath != null
              ? Image.file(File(localPath!))
              : (message.content == null
                  ? const SizedBox.shrink()
                  : FutureBuilder<String>(
                      future: storage.signedUrl(message.content!),
                      builder: (context, snap) => snap.hasData
                          ? Image.network(snap.data!)
                          : const Padding(
                              padding: EdgeInsets.all(AppSpacing.xxl),
                              child: CircularProgressIndicator(),
                            ),
                    )),
        ),
      ),
    );
  }
}
