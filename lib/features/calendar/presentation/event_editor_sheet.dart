import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/utils/dev_error.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/calendar_providers.dart';
import '../data/calendar_models.dart';

/// Add / edit / delete an event. Opened from a day tap (add) or an event tap
/// (edit). Writes go through [calendarControllerProvider].
class EventEditorSheet extends ConsumerStatefulWidget {
  const EventEditorSheet({
    super.key,
    required this.coupleId,
    required this.date,
    this.existing,
  });

  final String coupleId;
  final DateTime date; // default date for a new event
  final CoupleEvent? existing;

  static Future<void> open(
    BuildContext context, {
    required String coupleId,
    required DateTime date,
    CoupleEvent? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) =>
          EventEditorSheet(coupleId: coupleId, date: date, existing: existing),
    );
  }

  @override
  ConsumerState<EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends ConsumerState<EventEditorSheet> {
  late final TextEditingController _label;
  late final TextEditingController _note;
  late DateTime _date;
  TimeOfDay? _time;
  late EventType _type;
  late bool _recurring;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _date = e?.date ?? widget.date;
    _time = e?.time;
    _type = EventType.fromKey(e?.type ?? 'custom');
    _recurring = e?.recurringYearly ?? false;
  }

  @override
  void dispose() {
    _label.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 20),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your event a title.')),
      );
      return;
    }
    setState(() => _saving = true);
    final controller =
        ref.read(calendarControllerProvider(widget.coupleId).notifier);
    try {
      if (_isEditing) {
        await controller.update(
          id: widget.existing!.id,
          label: label,
          date: _date,
          time: _time,
          note: _note.text,
          type: _type.key,
          recurringYearly: _recurring,
        );
      } else {
        await controller.add(
          label: label,
          date: _date,
          time: _time,
          note: _note.text,
          type: _type.key,
          recurringYearly: _recurring,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('calendar ${_isEditing ? 'update' : 'add'} failed: $e\n$st');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: Duration(seconds: kShowDevTools ? 12 : 4),
          content: Text(kShowDevTools
              ? 'Couldn\'t save — DEV · ${devErrorText(e)}'
              : 'Couldn\'t save — try again.'),
        ));
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete this event?'),
        content: Text('"${widget.existing!.label}" will be removed for both of you.',
            style: AppText.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(calendarControllerProvider(widget.coupleId).notifier)
          .remove(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t delete — try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateLabel = '${months[_date.month - 1]} ${_date.day}, ${_date.year}';

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPad,
        right: AppSpacing.screenPad,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEditing ? 'Edit event' : 'New event', style: AppText.title),
            const SizedBox(height: AppSpacing.lg),
            BondTextField(controller: _label, label: 'Title'),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _pickerTile(
                      Icons.calendar_today_rounded, dateLabel, _pickDate),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _pickerTile(
                    Icons.schedule_rounded,
                    _time == null ? 'All-day' : _time!.format(context),
                    _pickTime,
                    onClear: _time == null ? null : () => setState(() => _time = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Type', style: AppText.bodySmall.copyWith(color: AppColors.inkMuted)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final t in EventType.values)
                  _typeChip(t),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            BondTextField(controller: _note, label: 'Note (optional)'),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _recurring,
              title: Text('Repeat every year', style: AppText.bodyLarge),
              subtitle: Text('For anniversaries & recurring dates',
                  style: AppText.bodySmall),
              onChanged: (v) => setState(() => _recurring = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            BondButton(
              label: _isEditing ? 'Save changes' : 'Add event',
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
            if (_isEditing) ...[
              const SizedBox(height: AppSpacing.sm),
              BondButton(
                label: 'Delete event',
                variant: BondButtonVariant.ghost,
                onPressed: _saving ? null : _delete,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pickerTile(IconData icon, String label, VoidCallback onTap,
      {VoidCallback? onClear}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.inkFaint),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(label, style: AppText.bodyMedium)),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 16, color: AppColors.inkFaint),
              ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(EventType t) {
    final selected = _type == t;
    return GestureDetector(
      onTap: () => setState(() => _type = t),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.mint : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.mint : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(t.icon,
                size: 15, color: selected ? AppColors.onMint : AppColors.inkMuted),
            const SizedBox(width: 6),
            Text(t.label,
                style: AppText.bodySmall.copyWith(
                    color: selected ? AppColors.onMint : AppColors.inkMuted)),
          ],
        ),
      ),
    );
  }
}
