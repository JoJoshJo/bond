import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_typography.dart';

/// Chat composer: reply preview, attach (photo), text field, and a trailing
/// button that sends text or starts a voice recording. Tap-to-record.
class MessageInput extends StatefulWidget {
  const MessageInput({
    super.key,
    required this.onSendText,
    required this.onSendVoice,
    required this.onSendImage,
    this.replyingToText,
    this.onCancelReply,
  });

  final void Function(String text) onSendText;
  final void Function(String filePath) onSendVoice;
  final void Function(String filePath) onSendImage;
  final String? replyingToText;
  final VoidCallback? onCancelReply;

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _recorder = AudioRecorder();
  final _picker = ImagePicker();

  bool _hasText = false;
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;
  static const _maxSeconds = 60;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _sendText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSendText(text);
    _controller.clear();
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path);
    if (!mounted) return;
    setState(() {
      _recording = true;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      if (_seconds >= _maxSeconds) _stopAndSend();
    });
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (path != null && _seconds >= 1) widget.onSendVoice(path);
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    await _recorder.stop();
    if (!mounted) return;
    setState(() => _recording = false);
  }

  Future<void> _pickImage(ImageSource source) async {
    final x = await _picker.pickImage(source: source, maxWidth: 2400);
    if (x != null) widget.onSendImage(x.path);
  }

  void _attachSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined,
                  color: AppColors.mint),
              title: Text('Take a photo', style: AppText.bodyLarge),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined,
                  color: AppColors.mint),
              title: Text('Choose from gallery', style: AppText.bodyLarge),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString();
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? AppSpacing.sm
            : AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyingToText != null && !_recording) _replyBar(),
          _recording ? _recordingRow() : _composerRow(),
        ],
      ),
    );
  }

  Widget _composerRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          onPressed: _attachSheet,
          icon: Icon(Icons.add_circle_outline, color: AppColors.mint),
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            style: AppText.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Message',
              hintStyle:
                  AppText.bodyMedium.copyWith(color: AppColors.inkFaint),
              filled: true,
              fillColor: AppColors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _trailingButton(),
      ],
    );
  }

  Widget _trailingButton() {
    final icon = _hasText ? Icons.arrow_upward_rounded : Icons.mic_none_rounded;
    return Material(
      color: AppColors.mint,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _hasText ? _sendText : _startRecording,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Icon(icon, color: AppColors.onMint),
        ),
      ),
    );
  }

  Widget _recordingRow() {
    return Row(
      children: [
        IconButton(
          onPressed: _cancelRecording,
          icon: Icon(Icons.delete_outline, color: AppColors.error),
        ),
        Icon(Icons.fiber_manual_record, color: AppColors.error, size: 14),
        const SizedBox(width: AppSpacing.sm),
        Text('Recording  ${_fmt(_seconds)}', style: AppText.bodyMedium),
        const Spacer(),
        Material(
          color: AppColors.mint,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _stopAndSend,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Icon(Icons.arrow_upward_rounded, color: AppColors.onMint),
            ),
          ),
        ),
      ],
    );
  }

  Widget _replyBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(width: 3, height: 32, color: AppColors.mint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Replying to',
                    style: AppText.bodySmall.copyWith(color: AppColors.mintDeep)),
                Text(widget.replyingToText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySmall),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: AppColors.inkMuted),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }
}
