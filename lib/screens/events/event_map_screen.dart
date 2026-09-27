import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/catalog_docs.dart';
import '../../services/event_location_service.dart';
import '../../services/event_service.dart';
import '../../services/maps_config.dart';
import '../../widgets/event_widgets.dart';
import '../../widgets/liquid_glass.dart';

class EventMapScreen extends StatefulWidget {
  const EventMapScreen({super.key});

  @override
  State<EventMapScreen> createState() => _EventMapScreenState();
}

class _EventMapScreenState extends State<EventMapScreen> {
  final Set<FandomEventDoc> _pins = {};
  GoogleMapController? _controller;
  FandomEventDoc? _selectedEvent;
  LatLng? _userPosition;
  bool _loading = true;
  bool _locationLoading = false;
  String? _error;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    _load();
    _loadLocation();
  }

  Future<void> _load() async {
    try {
      final events = await EventService.instance.watchUpcoming().first;
      if (!mounted) return;
      setState(() {
        _pins
          ..clear()
          ..addAll(events.where((event) => event.hasLocation));
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Events could not be loaded. Check your connection and retry.';
      });
    }
  }

  Future<void> _loadLocation() async {
    setState(() {
      _locationLoading = true;
      _locationMessage = null;
    });
    try {
      final position = await EventLocationService.instance.currentPosition();
      if (!mounted) return;
      final target = LatLng(position.latitude, position.longitude);
      setState(() => _userPosition = target);
      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, 12));
    } on EventLocationException catch (error) {
      if (mounted) setState(() => _locationMessage = error.message);
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _openEvent(FandomEventDoc event) async {
    await Navigator.pushNamed(context, '/events/detail', arguments: event);
  }

  Future<void> _openTickets(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket link could not be opened.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket link could not be opened.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = MapsConfig.hasKey;
    final hasLocation = _pins.any((event) => event.hasLocation);

    if (_loading || _error != null || !hasKey || !hasLocation) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDeep,
        body: SafeArea(
          child: Column(
            children: [
              _MapAppBar(
                onMyLocation: _loadLocation,
                locationLoading: _locationLoading,
              ),
              Expanded(
                child: _MapPlaceholder(
                  pins: _pins.toList(),
                  missingKey: !hasKey,
                  missingLocation: !hasLocation,
                  loading: _loading,
                  error: _error,
                  locationMessage: _locationMessage,
                  onRetry: _load,
                  onOpenEvent: _openEvent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _controller = controller;
              final userPosition = _userPosition;
              if (userPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(userPosition, 12),
                );
              } else {
                _moveToCluster();
              }
            },
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 2,
            ),
            markers: _markerSet,
            mapToolbarEnabled: false,
            zoomControlsEnabled: true,
            myLocationEnabled: _userPosition != null,
            myLocationButtonEnabled: _userPosition != null,
            buildingsEnabled: true,
            style: jsonEncode(_mapStyle),
          ),
          Positioned(
            right: 14,
            top: 78,
            child: FloatingActionButton.small(
              heroTag: 'event-map-location',
              tooltip: 'Show my location',
              onPressed: _locationLoading ? null : _loadLocation,
              child: _locationLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _MapAppBar(
              onMyLocation: _loadLocation,
              locationLoading: _locationLoading,
            ),
          ),
          if (_locationMessage != null)
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _locationMessage!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          if (_selectedEvent case final event?)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: _SelectedEventCard(
                event: event,
                onOpen: () => _openEvent(event),
                onTickets: event.ticketUrl?.isNotEmpty == true
                    ? () => _openTickets(event.ticketUrl!)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Set<Marker> get _markerSet {
    final markers = <Marker>{};
    for (final event in _pins) {
      if (!event.hasLocation) continue;
      markers.add(
        Marker(
          markerId: MarkerId(event.id),
          position: LatLng(event.latitude!, event.longitude!),
          consumeTapEvents: true,
          infoWindow: InfoWindow(
            title: event.title,
            snippet: '${event.eventType} · ${event.city}',
            onTap: () => _openEvent(event),
          ),
          onTap: () => setState(() => _selectedEvent = event),
          icon: BitmapDescriptor.defaultMarkerWithHue(_hueFor(event.color)),
        ),
      );
    }
    return markers;
  }

  void _moveToCluster() {
    final positions = _pins
        .where((e) => e.hasLocation)
        .map((e) => LatLng(e.latitude!, e.longitude!))
        .toList();
    if (positions.isEmpty) return;
    if (positions.length == 1 ||
        (positions.map((point) => point.latitude).toSet().length == 1 &&
            positions.map((point) => point.longitude).toSet().length == 1)) {
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(positions.first, 11),
      );
      return;
    }
    final north = positions
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    final south = positions
        .map((p) => p.latitude)
        .reduce((a, b) => a < b ? a : b);
    final east = positions
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);
    final west = positions
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        50,
      ),
    );
  }

  double _hueFor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.toColor().toARGB32() == color.toARGB32() ? 0 : hsl.hue;
  }

  static const _mapStyle = [
    {
      'featureType': 'all',
      'elementType': 'labels',
      'stylers': <String, dynamic>{'visibility': 'off'},
    },
    {
      'featureType': 'water',
      'elementType': 'geometry',
      'stylers': <String, dynamic>{'color': '#0b0b12'},
    },
    {
      'featureType': 'landscape',
      'elementType': 'geometry',
      'stylers': <String, dynamic>{'color': '#0f0f18'},
    },
    {
      'featureType': 'poi',
      'elementType': 'geometry',
      'stylers': <String, dynamic>{'color': '#11111c'},
    },
    {
      'featureType': 'road',
      'elementType': 'geometry',
      'stylers': <String, dynamic>{'color': '#1c1c28'},
    },
    {
      'featureType': 'road',
      'elementType': 'labels.icon',
      'stylers': <String, dynamic>{'visibility': 'off'},
    },
  ];
}

class _MapAppBar extends StatelessWidget {
  const _MapAppBar({required this.onMyLocation, required this.locationLoading});

  final VoidCallback onMyLocation;
  final bool locationLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundDeep,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Event Map',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Show my location',
              onPressed: locationLoading ? null : onMyLocation,
              icon: locationLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({
    required this.pins,
    required this.missingKey,
    required this.missingLocation,
    required this.loading,
    required this.error,
    required this.locationMessage,
    required this.onRetry,
    required this.onOpenEvent,
  });

  final List<FandomEventDoc> pins;
  final bool missingKey;
  final bool missingLocation;
  final bool loading;
  final String? error;
  final String? locationMessage;
  final VoidCallback onRetry;
  final ValueChanged<FandomEventDoc> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final message = loading
        ? 'Loading events...'
        : error ??
              (missingKey
                  ? 'Google Maps isn\'t configured yet.'
                  : pins.isEmpty
                  ? 'No upcoming events to show on the map.'
                  : 'Events without valid coordinates won\'t appear here.');

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Flexible(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      size: 56,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                    if (locationMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        locationMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (pins.isNotEmpty)
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: pins.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final event = pins[i];
                  return EventChip(
                    event: event,
                    onTap: () => onOpenEvent(event),
                    width: 224,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectedEventCard extends StatelessWidget {
  const _SelectedEventCard({
    required this.event,
    required this.onOpen,
    this.onTickets,
  });

  final FandomEventDoc event;
  final VoidCallback onOpen;
  final VoidCallback? onTickets;

  @override
  Widget build(BuildContext context) => LiquidGlass(
    radius: 16,
    blur: 18,
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Icon(event.icon, color: event.color),
        const SizedBox(width: 10),
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
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${event.dateLabel} · ${event.city}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
        if (onTickets != null)
          IconButton(
            tooltip: 'Tickets',
            onPressed: onTickets,
            icon: const Icon(Icons.confirmation_num_outlined),
          ),
        TextButton(onPressed: onOpen, child: const Text('Details')),
      ],
    ),
  );
}
