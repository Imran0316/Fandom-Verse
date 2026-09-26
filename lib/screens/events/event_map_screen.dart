import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/catalog_docs.dart';
import '../../services/catalog_service.dart';
import '../../services/geocode_service.dart';

/// Map view of fan events: geocodes each event's city, drops a marker per
/// event and lets fans jump straight to the ticket link.
///
/// Test seams: [eventsStream] injects data, [geocode] replaces the network
/// geocoder and [mapBuilder] replaces the platform GoogleMap widget.
class EventMapScreen extends StatefulWidget {
  const EventMapScreen({
    super.key,
    this.eventsStream,
    this.geocode,
    this.mapBuilder,
    this.onOpenTicket,
  });

  final Stream<List<FandomEventDoc>>? eventsStream;
  final Future<({double lat, double lng})?> Function(String city)? geocode;
  final Widget Function(LatLng center, Set<Marker> markers)? mapBuilder;
  final void Function(String url)? onOpenTicket;

  @override
  State<EventMapScreen> createState() => _EventMapScreenState();
}

class _EventMapScreenState extends State<EventMapScreen> {
  late final Stream<List<FandomEventDoc>> _stream;
  late final StreamSubscription<List<FandomEventDoc>> _sub;
  List<FandomEventDoc> _events = const [];
  bool _loading = true;
  bool _geocodeFailed = false;
  final Map<String, ({double lat, double lng})> _coords = {};
  final Set<String> _inFlight = <String>{};
  FandomEventDoc? _selected;

  @override
  void initState() {
    super.initState();
    _stream = widget.eventsStream ?? CatalogService.instance.watchEvents();
    _sub = _stream.listen(
      (events) {
        if (!mounted) return;
        _ensureCoords(events);
        setState(() {
          _events = events;
          _loading = false;
          if (_selected != null && !events.any((e) => e.id == _selected!.id)) {
            _selected = null;
          }
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _loading = false);
      },
    );
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _ensureCoords(List<FandomEventDoc> events) {
    final geocode = widget.geocode ?? GeocodeService.instance.geocode;
    var attempted = false;
    for (final event in events) {
      final city = event.city.trim();
      if (city.isEmpty) continue;
      final key = city.toLowerCase();
      if (_coords.containsKey(key) || _inFlight.contains(key)) continue;
      attempted = true;
      _inFlight.add(key);
      geocode(city).then((loc) {
        if (!mounted) return;
        setState(() {
          if (loc != null) {
            _coords[key] = loc;
            _geocodeFailed = false;
          } else {
            _geocodeFailed = _coords.isEmpty;
          }
        });
      }).whenComplete(() => _inFlight.remove(key));
    }
    if (!attempted && _inFlight.isEmpty && events.isNotEmpty) {
      // No city could even be attempted (empty city fields).
      _geocodeFailed = _coords.isEmpty;
    }
  }

  LatLng get _center {
    if (_coords.isEmpty) return const LatLng(20, 0);
    var lat = 0.0;
    var lng = 0.0;
    for (final c in _coords.values) {
      lat += c.lat;
      lng += c.lng;
    }
    return LatLng(lat / _coords.length, lng / _coords.length);
  }

  double get _zoom {
    if (_coords.length == 1) return 10;
    if (_coords.isEmpty) return 2;
    return 4;
  }

  Set<Marker> _markers() {
    final markers = <Marker>{};
    for (final event in _events) {
      final loc = _coords[event.city.trim().toLowerCase()];
      if (loc == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId(event.id),
          position: LatLng(loc.lat, loc.lng),
          infoWindow: InfoWindow(
            title: event.title,
            snippet: '${event.city} · ${event.dateLabel}',
          ),
          onTap: () => setState(() => _selected = event),
        ),
      );
    }
    return markers;
  }

  Future<void> _openTicket(String raw) async {
    if (widget.onOpenTicket != null) {
      widget.onOpenTicket!(raw);
      return;
    }
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
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          child: SafeArea(child: _buildBody()),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_events.isEmpty) {
      return const _MapMessage(
        icon: Icons.event_busy_rounded,
        title: 'No events yet',
        subtitle: 'When fans gather, their cities will light up this map.',
      );
    }
    // Geocoding unavailable (key/billing) or every city failed → list fallback.
    if (_coords.isEmpty && (_geocodeFailed || _inFlight.isEmpty)) {
      return _buildFallbackList();
    }
    if (_coords.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        Expanded(child: _buildMap()),
        if (_selected != null) _selectedCard(_selected!),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const Expanded(
            child: Text(
              'Events Map',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_coords.length} ${_coords.length == 1 ? 'city' : 'cities'}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final markers = _markers();
    if (widget.mapBuilder != null) {
      return widget.mapBuilder!(_center, markers);
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: _center, zoom: _zoom),
        markers: markers,
        zoomControlsEnabled: false,
        myLocationButtonEnabled: false,
        onMapCreated: (_) {},
      ),
    );
  }

  Widget _buildFallbackList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x3316161F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: const Text(
            'Map locations are unavailable right now — showing the full '
            'event list instead.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            physics: const BouncingScrollPhysics(),
            itemCount: _events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _eventTile(_events[i]),
          ),
        ),
      ],
    );
  }

  Widget _eventTile(FandomEventDoc event) {
    final ticket = event.ticketUrl?.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_rounded,
              color: AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.city} · ${event.dateLabel}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (ticket != null && ticket.isNotEmpty)
            TextButton(
              onPressed: () => _openTicket(ticket),
              child: const Text(
                'Get tickets',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectedCard(FandomEventDoc event) {
    final ticket = event.ticketUrl?.trim();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xE616161F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _selected = null),
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${event.city} · ${event.dateLabel}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (ticket != null && ticket.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _openTicket(ticket),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.confirmation_num_outlined, size: 18),
                label: const Text(
                  'Get tickets',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
