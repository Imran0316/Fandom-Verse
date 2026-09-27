import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/catalog_docs.dart';
import '../../services/event_service.dart';
import '../../services/event_location_service.dart';
import '../../widgets/event_widgets.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/content_widgets.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  FandomEventDoc? _event;
  bool _loading = true;
  bool _rsvped = false;
  bool _started = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final arg = ModalRoute.of(context)?.settings.arguments;
    final id = arg is FandomEventDoc ? arg.id : (arg as String? ?? '');
    FandomEventDoc? event = arg is FandomEventDoc ? arg : null;
    if (event == null) {
      try {
        event = await EventService.instance.getById(id);
      } catch (error) {
        debugPrint('EventDetailScreen: event load failed: $error');
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error =
              'Event details are unavailable. Check your connection and retry.';
        });
        return;
      }
    }
    if (event == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'This event could not be found.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _event = event;
      _loading = false;
      _error = null;
    });

    try {
      final latest = await EventService.instance.getById(event.id);
      if (mounted && latest != null) setState(() => _event = latest);
    } catch (error) {
      debugPrint(
        'EventDetailScreen: using cached event after refresh failed: $error',
      );
    }
    try {
      final rsvped = await EventService.instance.hasRsvped(event.id);
      if (mounted) setState(() => _rsvped = rsvped);
    } catch (error) {
      debugPrint('EventDetailScreen: RSVP status unavailable: $error');
    }
  }

  Future<void> _toggleRsvp() async {
    final event = _event;
    if (event == null) return;
    try {
      final ok = await EventService.instance.toggleRsvp(event.id);
      final updated = await EventService.instance.getById(event.id);
      if (!mounted) return;
      setState(() {
        _rsvped = ok;
        _event = updated ?? event;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your RSVP could not be updated. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (_error != null || _event == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDeep,
        body: ContentErrorState(
          message: _error ?? 'Unable to load event details.',
          onRetry: _load,
        ),
      );
    }

    final event = _event!;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(event: event),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventMapPin(event: event),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      LiquidGlassPillLabel(event.dateLabel),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.eventType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _EventInformation(event: event),
                  const SizedBox(height: 20),
                  if (event.hasDescription) ...[
                    const Text(
                      'About this event',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GlassButton(
                        label: _rsvped ? 'Going' : "I'm going",
                        onPressed: _toggleRsvp,
                        icon: _rsvped
                            ? Icons.people_rounded
                            : Icons.person_add_rounded,
                        height: 48,
                      ),
                      if (event.hasLocation ||
                          event.ticketUrl?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (event.hasLocation)
                              OutlinedButton.icon(
                                onPressed: () => _openDirections(event),
                                icon: const Icon(Icons.map_outlined, size: 18),
                                label: const Text('Open map'),
                              ),
                            if (event.ticketUrl?.isNotEmpty == true)
                              FilledButton.icon(
                                onPressed: () => _openTicket(event.ticketUrl!),
                                icon: const Icon(
                                  Icons.confirmation_num_outlined,
                                ),
                                label: const Text('Tickets'),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (event.rsvpCount > 0)
                    LiquidGlass(
                      radius: 14,
                      blur: 8,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people_outline_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${event.rsvpCount} ${event.rsvpCount == 1 ? 'fan' : 'fans'} going',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar({required FandomEventDoc event}) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 250,
      backgroundColor: AppColors.backgroundDeep,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      title: Text(
        event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      centerTitle: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (event.coverImageUrl?.isNotEmpty == true)
              Image.network(
                event.coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _eventImageFallback(event),
              )
            else
              _eventImageFallback(event),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC09090D)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDirections(FandomEventDoc event) async {
    if (!event.hasLocation) return;
    final position = await EventLocationService.instance
        .currentPosition(requestPermission: false)
        .then<({double latitude, double longitude})?>(
          (value) => (latitude: value.latitude, longitude: value.longitude),
        )
        .catchError((_) => null);
    final uri = position == null
        ? Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': '${event.latitude},${event.longitude}',
          })
        : Uri.https('www.google.com', '/maps/dir/', {
            'api': '1',
            'origin': '${position.latitude},${position.longitude}',
            'destination': '${event.latitude},${event.longitude}',
          });
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Map link could not be opened.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Map link could not be opened.')),
        );
      }
    }
  }

  Future<void> _openTicket(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return;
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket link could not be opened.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket link could not be opened.')),
      );
    }
  }

  Widget _eventImageFallback(FandomEventDoc event) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [event.color.withValues(alpha: 0.45), AppColors.backgroundDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(child: Icon(event.icon, size: 64, color: Colors.white38)),
  );
}

class _EventInformation extends StatelessWidget {
  const _EventInformation({required this.event});

  final FandomEventDoc event;

  @override
  Widget build(BuildContext context) {
    final date = event.startAt;
    final schedule = date == null
        ? event.dateLabel
        : '${event.dateLabel} · ${_formatTime(date)}${event.endAt == null ? '' : '–${_formatTime(event.endAt!)}'}';
    return Column(
      children: [
        _DetailLine(
          icon: Icons.schedule_rounded,
          label: 'Date and time',
          value: schedule,
        ),
        _DetailLine(
          icon: Icons.location_on_outlined,
          label: 'Venue',
          value: event.venue.isEmpty ? event.city : event.venue,
        ),
        if (event.address.isNotEmpty)
          _DetailLine(
            icon: Icons.pin_drop_outlined,
            label: 'Address',
            value: event.address,
          ),
        if (event.organizer.isNotEmpty)
          _DetailLine(
            icon: Icons.groups_outlined,
            label: 'Organizer',
            value: event.organizer,
          ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.accent, size: 18),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}
