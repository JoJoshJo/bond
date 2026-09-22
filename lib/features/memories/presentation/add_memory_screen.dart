import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/utils/input_limits.dart';
import '../../../shared/utils/error_messages.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/memory_controller.dart';

/// Add a memory: preview the picked media, add a caption + date (capped today),
/// then save (compress photo / upload video) into the shared vault.
class AddMemoryScreen extends ConsumerStatefulWidget {
  const AddMemoryScreen({
    super.key,
    required this.coupleId,
    required this.localPath,
    required this.isVideo,
  });

  final String coupleId;
  final String localPath;
  final bool isVideo;

  @override
  ConsumerState<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends ConsumerState<AddMemoryScreen> {
  final _caption = TextEditingController();
  DateTime _takenAt = DateTime.now();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _takenAt,
      firstDate: DateTime(1990),
      lastDate: now, // no future memories
    );
    if (picked != null) setState(() => _takenAt = picked);
  }

  Future<void> _save() async {
    final controller = ref.read(memoryVaultProvider(widget.coupleId).notifier);
    final caption = _caption.text;
    try {
      if (widget.isVideo) {
        await controller.addVideo(widget.localPath, caption, _takenAt);
      } else {
        await controller.addPhoto(widget.localPath, caption, _takenAt);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  String _fmtDate(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(memoryVaultProvider(widget.coupleId)).saving;
    return BondScaffold(
      title: 'New memory',
      showBack: true,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: AspectRatio(
              aspectRatio: 1,
              child: widget.isVideo
                  ? Container(
                      color: const Color(0xFF1E2A25),
                      child: const Center(
                        child: Icon(Icons.play_circle_fill,
                            color: Colors.white70, size: 48),
                      ),
                    )
                  : Image.file(File(widget.localPath), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          BondTextField(
              controller: _caption,
              label: 'Caption (optional)',
              maxLength: kMaxMemoryCaptionChars),
          const SizedBox(height: AppSpacing.md),
          BondCard(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: BondListTile(
              leadingIcon: Icons.calendar_today_rounded,
              title: 'Date',
              subtitle: _fmtDate(_takenAt),
              trailing:
                  Icon(Icons.chevron_right, color: AppColors.inkFaint),
              onTap: _pickDate,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          BondButton(
            label: saving ? 'Saving…' : 'Save to vault',
            loading: saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
