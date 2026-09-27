import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/app_colors.dart';
import '../../models/catalog_docs.dart';
import '../../services/event_location_service.dart';
import '../../services/event_service.dart';
import '../../widgets/event_widgets.dart';
import '../../widgets/content_widgets.dart';
import '../../widgets/liquid_glass.dart';

enum _EventsView { list, calendar }

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  final _searchController = TextEditingController();
  late final Stream<List<FandomEventDoc>> _eventsStream;
  String _query = '';
  String? _city;
  String? _eventType;
  DateTime? _selectedDate;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Position? _position;
  String? _locationMessage;
  bool _locationLoading = false;
  bool _locationSettingsRequired = false;
  bool _locationServicesDisabled = false;
  _EventsView _view = _EventsView.list;

  @override
  void initState() {
    super.initState();
    _eventsStream = EventService.instance.watchUpcoming();
    _requestLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestLocation() async {
    setState(() {
      _locationLoading = true;
      _locationMessage = null;
    });
    try {
      final position = await EventLocationService.instance.currentPosition();
      if (!mounted) return;
      setState(() {
        _position = position;
        _locationMessage = null;
        _locationSettingsRequired = false;
        _locationServicesDisabled = false;
      });
    } on EventLocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _position = null;
        _locationMessage = error.message;
        _locationSettingsRequired = error.permanentlyDenied;
        _locationServicesDisabled = error.locationServiceDisabled;
      });
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Column(
          children: [
            _AppBar(
              view: _view,
              onViewChanged: (value) => setState(() => _view = value),
              onMap: () => Navigator.pushNamed(context, '/events/map'),
            ),
            Expanded(
              child: StreamBuilder<List<FandomEventDoc>>(
                stream: _eventsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    );
                  }
                  if (snapshot.hasError && !snapshot.hasData) {
                    return ContentErrorState(
                      message:
                          'Events could not be loaded. Check your connection and try again.',
                      onRetry: () => setState(() {}),
                    );
                  }
                  final allEvents = snapshot.data ?? const <FandomEventDoc>[];
                  final cities =
                      allEvents
                          .map((event) => event.city.trim())
                          .where((city) => city.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort();
                  final types =
                      allEvents
                          .map((event) => event.eventType.trim())
                          .where((type) => type.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort();
                  var events = allEvents.where((event) {
                    final query = _query.trim().toLowerCase();
                    if (query.isNotEmpty &&
                        ![
                          event.title,
                          event.description,
                          event.city,
                          event.venue,
                          event.address,
                          event.eventType,
                        ].any((value) => value.toLowerCase().contains(query))) {
                      return false;
                    }
                    if (_city != null && event.city != _city) return false;
                    if (_eventType != null && event.eventType != _eventType) {
                      return false;
                    }
                    if (_position != null && _distance(event) > 100) {
                      return false;
                    }
                    return true;
                  }).toList();

                  if (_position != null) {
                    events.sort((a, b) => _distance(a).compareTo(_distance(b)));
                  }
                  final listEvents = _selectedDate == null
                      ? events
                      : events
                            .where(
                              (event) =>
                                  _sameDate(event.startAt, _selectedDate!),
                            )
                            .toList();

                  return Column(
                    children: [
                      _Filters(
                        query: _query,
                        searchController: _searchController,
                        onQueryChanged: (value) =>
                            setState(() => _query = value),
                        city: _city,
                        cities: cities,
                        eventType: _eventType,
                        types: types,
                        onCityChanged: (value) => setState(() => _city = value),
                        onTypeChanged: (value) =>
                            setState(() => _eventType = value),
                        onNearby: _requestLocation,
                        locationLoading: _locationLoading,
                        nearbyEnabled: _position != null,
                        onClearNearby: () => setState(() {
                          _position = null;
                          _locationMessage = null;
                        }),
                      ),
                      if (_locationMessage != null)
                        _LocationNotice(
                          message: _locationMessage!,
                          showSettings: _locationSettingsRequired,
                          showLocationSettings: _locationServicesDisabled,
                          onSettings: () async {
                            if (_locationSettingsRequired) {
                              await EventLocationService.instance
                                  .openSettings();
                            } else if (_locationServicesDisabled) {
                              await EventLocationService.instance
                                  .openLocationSettings();
                            } else {
                              await _requestLocation();
                            }
                          },
                        ),
                      if (snapshot.hasError)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: Text(
                            'Showing saved events. Fresh data is unavailable.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Expanded(
                        child: _view == _EventsView.calendar
                            ? _CalendarEvents(
                                events: events,
                                month: _visibleMonth,
                                selectedDate: _selectedDate,
                                distanceFor: _distance,
                                onMonthChanged: (month) =>
                                    setState(() => _visibleMonth = month),
                                onDateSelected: (date) =>
                                    setState(() => _selectedDate = date),
                              )
                            : listEvents.isEmpty
                            ? ContentEmptyState(
                                icon: Icons.event_available_outlined,
                                title: allEvents.isEmpty
                                    ? 'No upcoming events'
                                    : _position != null
                                    ? 'No events nearby'
                                    : 'No matching events',
                                message: allEvents.isEmpty
                                    ? 'New fandom events will appear here when they are published.'
                                    : _position != null
                                    ? 'No events with map locations were found within 100 km. Try another city or clear filters.'
                                    : 'Try clearing a filter or choosing another date.',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 28,
                                ),
                                itemCount: listEvents.length,
                                itemBuilder: (context, index) => _EventListItem(
                                  event: listEvents[index],
                                  distanceKm: _distance(listEvents[index]),
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    '/events/detail',
                                    arguments: listEvents[index],
                                  ),
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _distance(FandomEventDoc event) {
    final position = _position;
    if (position == null || !event.hasLocation) return double.infinity;
    return EventLocationService.instance.distanceInKilometres(
      fromLatitude: position.latitude,
      fromLongitude: position.longitude,
      toLatitude: event.latitude!,
      toLongitude: event.longitude!,
    );
  }

  bool _sameDate(DateTime? first, DateTime second) =>
      first != null &&
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _AppBar extends StatelessWidget {
  const _AppBar({
    required this.view,
    required this.onViewChanged,
    required this.onMap,
  });

  final _EventsView view;
  final ValueChanged<_EventsView> onViewChanged;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Events',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Map view',
            onPressed: onMap,
            icon: const Icon(Icons.map_outlined),
          ),
          SegmentedButton<_EventsView>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _EventsView.list,
                icon: Icon(Icons.view_list_rounded),
              ),
              ButtonSegment(
                value: _EventsView.calendar,
                icon: Icon(Icons.calendar_month_rounded),
              ),
            ],
            selected: {view},
            onSelectionChanged: (selection) => onViewChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.city,
    required this.cities,
    required this.eventType,
    required this.types,
    required this.onCityChanged,
    required this.onTypeChanged,
    required this.onNearby,
    required this.locationLoading,
    required this.nearbyEnabled,
    required this.onClearNearby,
  });

  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final String? city;
  final List<String> cities;
  final String? eventType;
  final List<String> types;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onNearby;
  final bool locationLoading;
  final bool nearbyEnabled;
  final VoidCallback onClearNearby;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search events, city, venue',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        searchController.clear();
                        onQueryChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _DropdownFilter<String>(
                  value: city,
                  values: cities,
                  hint: 'All cities',
                  onChanged: onCityChanged,
                ),
                const SizedBox(width: 8),
                _DropdownFilter<String>(
                  value: eventType,
                  values: types,
                  hint: 'All types',
                  onChanged: onTypeChanged,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: locationLoading
                      ? null
                      : nearbyEnabled
                      ? onClearNearby
                      : onNearby,
                  icon: locationLoading
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          nearbyEnabled
                              ? Icons.location_on
                              : Icons.near_me_outlined,
                        ),
                  label: Text(nearbyEnabled ? 'Nearby on' : 'Nearby'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownFilter<T> extends StatelessWidget {
  const _DropdownFilter({
    required this.value,
    required this.values,
    required this.hint,
    required this.onChanged,
  });

  final T? value;
  final List<T> values;
  final String hint;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<T>(
      value: values.contains(value) ? value : null,
      hint: Text(hint),
      underline: const SizedBox.shrink(),
      dropdownColor: AppColors.surface,
      items: [
        DropdownMenuItem<T>(value: null, child: Text(hint)),
        ...values.map(
          (item) => DropdownMenuItem<T>(value: item, child: Text('$item')),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _LocationNotice extends StatelessWidget {
  const _LocationNotice({
    required this.message,
    required this.showSettings,
    required this.showLocationSettings,
    required this.onSettings,
  });

  final String message;
  final bool showSettings;
  final bool showLocationSettings;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, size: 17, color: Colors.white54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: onSettings,
          child: Text(
            showSettings || showLocationSettings ? 'Settings' : 'Retry',
          ),
        ),
      ],
    ),
  );
}

class _CalendarEvents extends StatelessWidget {
  const _CalendarEvents({
    required this.events,
    required this.month,
    required this.selectedDate,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.distanceFor,
  });

  final List<FandomEventDoc> events;
  final DateTime month;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime?> onDateSelected;
  final double Function(FandomEventDoc) distanceFor;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final offset = firstDay.weekday - 1;
    final dayCount = DateUtils.getDaysInMonth(month.year, month.month);
    final visibleEvents = events.where((event) {
      final date = event.startAt;
      return date != null &&
          date.year == month.year &&
          date.month == month.month &&
          (selectedDate == null || _sameDate(date, selectedDate!));
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: LiquidGlass(
            radius: 16,
            blur: 12,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () =>
                          onMonthChanged(DateTime(month.year, month.month - 1)),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '${_monthName(month.month)} ${month.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: () =>
                          onMonthChanged(DateTime(month.year, month.month + 1)),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                Row(
                  children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                      .map(
                        (day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 6),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 42,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.25,
                  ),
                  itemBuilder: (context, index) {
                    final day = index - offset + 1;
                    if (day < 1 || day > dayCount) {
                      return const SizedBox.shrink();
                    }
                    final date = DateTime(month.year, month.month, day);
                    final isPastDate = DateUtils.dateOnly(
                      date,
                    ).isBefore(DateUtils.dateOnly(DateTime.now()));
                    final hasEvents =
                        !isPastDate &&
                        events.any((event) => _sameDate(event.startAt, date));
                    final selected =
                        !isPastDate &&
                        selectedDate != null &&
                        _sameDate(selectedDate, date);
                    return InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: isPastDate
                          ? null
                          : () => onDateSelected(selected ? null : date),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : isPastDate
                                    ? Colors.white24
                                    : Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (hasEvents)
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: visibleEvents.isEmpty
              ? ContentEmptyState(
                  icon: Icons.event_available_outlined,
                  title: selectedDate == null
                      ? 'No events this month'
                      : 'No events on this date',
                  message: 'Choose another date or browse a different month.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: visibleEvents.length,
                  itemBuilder: (context, index) => _EventListItem(
                    event: visibleEvents[index],
                    distanceKm: distanceFor(visibleEvents[index]),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/events/detail',
                      arguments: visibleEvents[index],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

bool _sameDate(DateTime? first, DateTime second) =>
    first != null &&
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _monthName(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

class _EventListItem extends StatelessWidget {
  const _EventListItem({
    required this.event,
    required this.onTap,
    required this.distanceKm,
  });

  final FandomEventDoc event;
  final VoidCallback onTap;
  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: LiquidGlass(
        radius: 18,
        blur: 16,
        gradient: LinearGradient(
          colors: [
            event.color.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: EventMapPin(event: event),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          LiquidGlassPillLabel(
                            event.dateLabel.isEmpty
                                ? 'Date TBA'
                                : event.dateLabel,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              event.eventType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (event.hasLocation) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white54,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              event.locationLabel.isEmpty
                                  ? event.city
                                  : event.locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (event.hasDescription) ...[
                        const SizedBox(height: 6),
                        Text(
                          event.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.people_outline_rounded,
                            color: Colors.white54,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${event.rsvpCount} going',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (distanceKm.isFinite) ...[
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.near_me_outlined,
                              color: Colors.white54,
                              size: 13,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${distanceKm.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (event.ticketUrl?.isNotEmpty == true) ...[
                            const Spacer(),
                            const Icon(
                              Icons.confirmation_num_outlined,
                              color: AppColors.accent,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
