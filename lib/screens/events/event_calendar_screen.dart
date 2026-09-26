import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/catalog_docs.dart';
import '../../services/catalog_service.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/liquid_glass.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _weekdayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

class EventCalendarScreen extends StatefulWidget {
  const EventCalendarScreen({super.key, this.eventsStream, this.onOpenTicket});

  /// Test seam — defaults to the live Firestore events stream.
  final Stream<List<FandomEventDoc>>? eventsStream;

  /// Test seam — defaults to opening the link with url_launcher.
  final void Function(String url)? onOpenTicket;

  @override
  State<EventCalendarScreen> createState() => _EventCalendarScreenState();
}

class _EventCalendarScreenState extends State<EventCalendarScreen> {
  late final Stream<List<FandomEventDoc>> _stream;
  String? _city;
  late DateTime _focusedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _stream = widget.eventsStream ?? CatalogService.instance.watchEvents();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _sundayIndex(DateTime d) => d.weekday % 7;

  String _formatDayLabel(DateTime d) =>
      '${_weekdayNames[_sundayIndex(d)]}, ${_monthShort[d.month - 1]} ${d.day}';

  void _selectCity(String? city) {
    setState(() => _city = city);
  }

  void _clearFilters() {
    setState(() {
      _city = null;
      _selectedDay = null;
    });
  }

  void _toggleDay(DateTime day) {
    setState(() => _selectedDay = _selectedDay == day ? null : day);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + delta,
      );
    });
  }

  List<String> _cityNames(List<FandomEventDoc> events) {
    final seen = <String>{};
    final out = <String>[];
    for (final e in events) {
      final c = e.city.trim();
      if (c.isNotEmpty && seen.add(c.toLowerCase())) out.add(c);
    }
    out.sort();
    return out;
  }

  bool _matchesCity(FandomEventDoc e) =>
      _city == null || e.city.trim().toLowerCase() == _city!.toLowerCase();

  Set<DateTime> _daysWithEvents(List<FandomEventDoc> events) {
    final days = <DateTime>{};
    for (final e in events) {
      final s = e.startAt;
      if (s != null && _matchesCity(e)) days.add(_dayOf(s));
    }
    return days;
  }

  List<FandomEventDoc> _visible(List<FandomEventDoc> events) {
    final day = _selectedDay;
    final list = events.where((e) {
      if (!_matchesCity(e)) return false;
      if (day == null) return true;
      final s = e.startAt;
      return s != null && _dayOf(s) == day;
    }).toList();
    list.sort((a, b) {
      final da = a.startAt;
      final db = b.startAt;
      if (da != null && db != null) {
        final c = da.compareTo(db);
        if (c != 0) return c;
      }
      if (da == null && db != null) return 1;
      if (da != null && db == null) return -1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return list;
  }

  void _openTicket(String url) {
    if (widget.onOpenTicket != null) {
      widget.onOpenTicket!(url);
      return;
    }
    _launchExternally(url);
  }

  Future<void> _launchExternally(String raw) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('That ticket link looks invalid.'),
          backgroundColor: Color(0xE616161F),
        ),
      );
      return;
    }
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not open the ticket link.'),
            backgroundColor: Color(0xE616161F),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not open the ticket link.'),
            backgroundColor: Color(0xE616161F),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Expanded(
                        child: Text(
                          'Event Calendar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.eventMap),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          foregroundColor: AppColors.accent,
                        ),
                        icon: const Icon(Icons.map_outlined),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<FandomEventDoc>>(
                    stream: _stream,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          snap.data == null) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final events = snap.data ?? const <FandomEventDoc>[];
                      return _Content(events: events, state: this);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.events, required this.state});

  final List<FandomEventDoc> events;
  final _EventCalendarScreenState state;

  @override
  Widget build(BuildContext context) {
    final cities = state._cityNames(events);
    final eventDays = state._daysWithEvents(events);
    final visible = state._visible(events);
    final filtered = state._selectedDay != null || state._city != null;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (cities.isNotEmpty) ...[
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: cities.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final isAll = i == 0;
                final name = isAll ? 'All' : cities[i - 1];
                final selected = isAll
                    ? state._city == null
                    : state._city?.toLowerCase() == name.toLowerCase();
                return InkWell(
                  key: ValueKey<String>('city-chip-$name'),
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => state._selectCity(isAll ? null : name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _Calendar(
            state: state,
            eventDays: eventDays,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
          child: Row(
            children: [
              Text(
                state._selectedDay != null
                    ? state._formatDayLabel(state._selectedDay!)
                    : '${visible.length} event${visible.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (filtered)
                TextButton(
                  onPressed: state._clearFilters,
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.24),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No events scheduled yet',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Conventions and meetups from the community will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          )
        else if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.24),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No events match this filter',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: state._clearFilters,
                  child: const Text(
                    'Clear filters',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _EventTile(
              event: visible[i],
              onTickets: state._openTicket,
            ),
          ),
      ],
    );
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.state, required this.eventDays});

  final _EventCalendarScreenState state;
  final Set<DateTime> eventDays;

  @override
  Widget build(BuildContext context) {
    final month = state._focusedMonth;
    final leading = _sundayIndexOf(month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = _dayOfNow();

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _DayCell(
          day: DateTime(month.year, month.month, d),
          number: d,
          isToday: DateTime(month.year, month.month, d) == today,
          isSelected: DateTime(month.year, month.month, d) == state._selectedDay,
          hasEvent: eventDays.contains(DateTime(month.year, month.month, d)),
          onTap: () => state._toggleDay(
            DateTime(month.year, month.month, d),
          ),
        ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    final rows = <Row>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(
        Row(
          children: [
            for (var j = i; j < i + 7; j++)
              Expanded(
                child: SizedBox(height: 46, child: cells[j]),
              ),
          ],
        ),
      );
    }

    return LiquidGlass(
      radius: 24,
      blur: 22,
      tint: Colors.white.withValues(alpha: 0.05),
      borderColor: Colors.white.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => state._shiftMonth(-1),
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white70,
                ),
              ),
              Expanded(
                child: Text(
                  '${_monthNames[month.month - 1]} ${month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => state._shiftMonth(1),
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              for (final letter in _weekdayLetters)
                Expanded(
                  child: Text(
                    letter,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (final row in rows) row,
        ],
      ),
    );
  }

  static int _sundayIndexOf(DateTime d) => d.weekday % 7;

  static DateTime _dayOfNow() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.number,
    required this.isToday,
    required this.isSelected,
    required this.hasEvent,
    required this.onTap,
  });

  final DateTime day;
  final int number;
  final bool isToday;
  final bool isSelected;
  final bool hasEvent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey<int>(number),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? AppColors.primary : null,
          border: isToday && !isSelected
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.55),
                  width: 1.4,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$number',
              style: TextStyle(
                color:
                    isSelected ? Colors.white : Colors.white.withValues(alpha: 0.92),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasEvent
                    ? (isSelected
                        ? Colors.white
                        : AppColors.primary)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.onTickets});

  final FandomEventDoc event;
  final void Function(String url) onTickets;

  @override
  Widget build(BuildContext context) {
    final base = event.color;
    final ticket = event.ticketUrl?.trim();
    final hasTicket = ticket != null && ticket.isNotEmpty;

    return LiquidGlass(
      radius: 20,
      blur: 24,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          base.withValues(alpha: 0.55),
          base.withValues(alpha: 0.9),
        ],
      ),
      borderColor: Colors.white.withValues(alpha: 0.18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LiquidGlass(
                  radius: 999,
                  blur: 12,
                  tint: Colors.white.withValues(alpha: 0.14),
                  borderColor: Colors.white.withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    event.dateLabel.isEmpty ? 'TBA' : event.dateLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  event.icon,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (event.city.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (hasTicket) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: GlassButton(
                  label: 'Get tickets',
                  icon: Icons.confirmation_number_outlined,
                  height: 46,
                  onPressed: () => onTickets(ticket),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
