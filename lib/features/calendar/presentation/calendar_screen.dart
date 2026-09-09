import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../../premium/presentation/premium_gate.dart';
import '../application/calendar_providers.dart';
import '../data/calendar_models.dart';
import 'event_editor_sheet.dart';

/// The shared couple calendar — a BOND+ feature. Free users see the lock card
/// (→ paywall); premium users get the month grid + upcoming list + CRUD.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key, required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context) {
    return BondScaffold(
      title: 'Calendar',
      showBack: true,
      padded: false,
      child: PremiumGate(
        featureName: 'Shared calendar',
        blurb: 'Plan your dates together — a BOND+ feature.',
        child: _CalendarBody(coupleId: coupleId),
      ),
    );
  }
}

class _CalendarBody extends ConsumerStatefulWidget {
  const _CalendarBody({required this.coupleId});

  final String coupleId;

  @override
  ConsumerState<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends ConsumerState<_CalendarBody> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarControllerProvider(widget.coupleId));

    if (state.loading) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.huge),
        child: BondLoader(),
      );
    }

    final selectedEvents = state.eventsOn(_selected);
    final upcoming = state.upcoming();

    return Column(
      children: [
        _calendar(state),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPad, AppSpacing.lg, AppSpacing.screenPad, AppSpacing.huge),
            children: [
              _sectionHeader(
                '${_months[_selected.month - 1]} ${_selected.day}',
                onAdd: () => _openEditor(date: _selected),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (selectedEvents.isEmpty)
                Text('Nothing on this day — tap + to add something.',
                    style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted))
              else
                for (final e in selectedEvents) _eventTile(e),
              const SizedBox(height: AppSpacing.xl),
              Text('Upcoming',
                  style: AppText.bodySmall.copyWith(
                      color: AppColors.mintDeep,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
              const SizedBox(height: AppSpacing.sm),
              if (upcoming.isEmpty)
                Text('No upcoming dates yet.',
                    style: AppText.bodyMedium.copyWith(color: AppColors.inkMuted))
              else
                for (final u in upcoming) _eventTile(u.event, when: u.when),
            ],
          ),
        ),
      ],
    );
  }

  Widget _calendar(CalendarState state) {
    return TableCalendar<CoupleEvent>(
      firstDay: DateTime(DateTime.now().year - 5),
      lastDay: DateTime(DateTime.now().year + 20),
      focusedDay: _focused,
      currentDay: DateTime.now(),
      selectedDayPredicate: (d) => isSameDay(d, _selected),
      eventLoader: state.eventsOn,
      startingDayOfWeek: StartingDayOfWeek.monday,
      onDaySelected: (selected, focused) {
        setState(() {
          _selected = selected;
          _focused = focused;
        });
      },
      onPageChanged: (focused) => _focused = focused,
      availableGestures: AvailableGestures.horizontalSwipe,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: AppText.title,
        leftChevronIcon:
            Icon(Icons.chevron_left, color: AppColors.inkMuted),
        rightChevronIcon:
            Icon(Icons.chevron_right, color: AppColors.inkMuted),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: AppText.bodySmall.copyWith(color: AppColors.inkFaint),
        weekendStyle: AppText.bodySmall.copyWith(color: AppColors.inkFaint),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        todayDecoration: BoxDecoration(
          color: AppColors.mintWash,
          shape: BoxShape.circle,
        ),
        todayTextStyle: AppText.bodyMedium.copyWith(color: AppColors.mintDeep),
        selectedDecoration: BoxDecoration(
          color: AppColors.mint,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: AppText.bodyMedium.copyWith(color: AppColors.onMint),
        markerDecoration:
            BoxDecoration(color: AppColors.mintDeep, shape: BoxShape.circle),
        markersMaxCount: 3,
        defaultTextStyle: AppText.bodyMedium,
        weekendTextStyle: AppText.bodyMedium,
      ),
    );
  }

  Widget _sectionHeader(String label, {required VoidCallback onAdd}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.title),
        IconButton(
          icon: Icon(Icons.add_circle_outline, color: AppColors.mint),
          tooltip: 'Add event',
          onPressed: onAdd,
        ),
      ],
    );
  }

  Widget _eventTile(CoupleEvent e, {DateTime? when}) {
    final type = EventType.fromKey(e.type);
    final subtitleParts = <String>[];
    if (when != null) subtitleParts.add(_dateShort(when));
    if (e.time != null) subtitleParts.add(e.time!.format(context));
    if (e.recurringYearly) subtitleParts.add('every year');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: BondCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () => _openEditor(date: e.date, existing: e),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.mintWash,
                shape: BoxShape.circle,
              ),
              child: Icon(type.icon, color: AppColors.mint, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.label, style: AppText.bodyLarge),
                  if (subtitleParts.isNotEmpty)
                    Text(subtitleParts.join(' · '),
                        style: AppText.bodySmall
                            .copyWith(color: AppColors.inkMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }

  String _dateShort(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _openEditor({required DateTime date, CoupleEvent? existing}) {
    return EventEditorSheet.open(
      context,
      coupleId: widget.coupleId,
      date: date,
      existing: existing,
    );
  }
}
