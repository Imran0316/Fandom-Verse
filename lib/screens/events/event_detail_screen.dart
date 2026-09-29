import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../models/catalog_docs.dart';
import '../../services/event_service.dart';
import '../../services/event_location_service.dart';
import '../../widgets/cached_image.dart';
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
    // Explore mode: RSVPs belong to an account.
    if (!requireSignIn(context, reason: 'Sign in to RSVP to events.')) {
      return;
    }
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
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(event: event),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetaRow(event),
                      const SizedBox(height: 12),
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          height: 1.18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (event.rsvpCount > 0) ...[
                        const SizedBox(height: 12),
                        _AttendeesPill(count: event.rsvpCount),
                      ],
                      const SizedBox(height: 20),
                      _EventInformation(event: event),
                      if (event.hasDescription) ...[
                        const SizedBox(height: 16),
                        _AboutCard(event: event),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildDock(event)),
        ],
      ),
    );
  }

  Widget _buildMetaRow(FandomEventDoc event) {
    return Row(
      children: [
        LiquidGlass(
          radius: 999,
          blur: 10,
          tint: Colors.white.withValues(alpha: 0.13),
          borderColor: Colors.white.withValues(alpha: 0.24),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white,
                size: 13,
              ),
              const SizedBox(width: 6),
              Text(
                event.dateLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LiquidGlass(
            radius: 999,
            blur: 8,
            tint: Colors.transparent,
            borderColor: Colors.white.withValues(alpha: 0.16),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            child: Text(
              event.eventType,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDock(FandomEventDoc event) {
    final hasTickets = event.ticketUrl?.isNotEmpty == true;
    final secondary = <Widget>[
      if (event.hasLocation)
        GlassButton(
          label: 'Open map',
          onPressed: () => _openDirections(event),
          icon: Icons.navigation_rounded,
          variant: GlassButtonVariant.outline,
          height: 46,
        ),
      if (hasTickets)
        GlassButton(
          label: 'Tickets',
          onPressed: () => _openTicket(event.ticketUrl!),
          icon: Icons.confirmation_number_rounded,
          height: 46,
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, AppColors.backgroundDeep],
            ),
          ),
          child: SizedBox(height: 44, width: double.infinity),
        ),
        SafeArea(
          top: false,
          child: LiquidGlass(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            radius: 26,
            blur: 30,
            tint: const Color(0xCC07070C),
            borderColor: Colors.white.withValues(alpha: 0.12),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              children: [
                GlassButton(
                  label: _rsvped ? 'Going' : "I'm going",
                  onPressed: _toggleRsvp,
                  icon: _rsvped
                      ? Icons.check_circle_rounded
                      : Icons.person_add_rounded,
                  height: 52,
                ),
                if (secondary.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var i = 0; i < secondary.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: secondary[i]),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar({required FandomEventDoc event}) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 290,
      backgroundColor: AppColors.backgroundDeep,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 56,
      leading: Center(
        child: LiquidGlass(
          radius: 999,
          blur: 10,
          tint: Colors.white.withValues(alpha: 0.14),
          borderColor: Colors.white.withValues(alpha: 0.24),
          padding: const EdgeInsets.all(9),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
        ),
      ),
      title: Text(
        event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (event.coverImageUrl?.isNotEmpty == true)
              CachedImage(
                url: event.coverImageUrl,
                fit: BoxFit.cover,
              )
            else
              _eventImageFallback(event),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment(0, -0.25),
                  colors: [Color(0xF2050508), Color(0x33050508)],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Color(0x66000000), Colors.transparent],
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

class _AttendeesPill extends StatelessWidget {
  const _AttendeesPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: 999,
      blur: 10,
      tint: Colors.white.withValues(alpha: 0.10),
      borderColor: Colors.white.withValues(alpha: 0.20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.people_rounded,
            color: Colors.white70,
            size: 14,
          ),
          const SizedBox(width: 7),
          Text(
            '$count ${count == 1 ? 'fan' : 'fans'} going',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
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
    return _GlassCard(
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.calendar_month_rounded,
            label: 'Date and time',
            value: schedule,
          ),
          const _CardDivider(),
          _InfoRow(
            icon: Icons.storefront_rounded,
            label: 'Venue',
            value: event.venue.isEmpty ? event.city : event.venue,
          ),
          if (event.address.isNotEmpty) ...[
            const _CardDivider(),
            _InfoRow(
              icon: Icons.location_on_rounded,
              label: 'Address',
              value: event.address,
            ),
          ],
          if (event.organizer.isNotEmpty) ...[
            const _CardDivider(),
            _InfoRow(
              icon: Icons.group_rounded,
              label: 'Organizer',
              value: event.organizer,
            ),
          ],
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.event});

  final FandomEventDoc event;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: 24,
      blur: 24,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0.03),
        ],
      ),
      borderColor: Colors.white.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.07));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.accent.withValues(alpha: 0.14),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.20),
              ),
            ),
            child: Icon(icon, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}
