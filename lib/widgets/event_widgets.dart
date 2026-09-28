import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/catalog_docs.dart';
import 'cached_image.dart';
import 'liquid_glass.dart';

/// Compact horizontal event chip for home rails and event lists.
class EventChip extends StatelessWidget {
  const EventChip({
    super.key,
    required this.event,
    required this.onTap,
    this.width = 224,
  });

  final FandomEventDoc event;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final base = event.color;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: LiquidGlass(
          radius: 20,
          blur: 0,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [base.withValues(alpha: 0.55), base.withValues(alpha: 0.9)],
          ),
          borderColor: Colors.white.withValues(alpha: 0.18),
          child: Stack(
            children: [
              if (event.coverImageUrl?.isNotEmpty == true)
                Positioned.fill(
                  child: CachedImage(url: event.coverImageUrl),
                ),
              if (event.coverImageUrl?.isNotEmpty == true)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: const [Color(0x33000000), Color(0xCC000000)],
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: -8,
                top: -8,
                child: Icon(
                  event.icon,
                  size: 88,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LiquidGlassPillLabel(event.dateLabel),
                    const Spacer(),
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiquidGlassPillLabel extends StatelessWidget {
  const LiquidGlassPillLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: 999,
      blur: 12,
      tint: Colors.white.withValues(alpha: 0.14),
      borderColor: Colors.white.withValues(alpha: 0.25),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// A map pin chip that either embeds a Google Maps pin preview or falls back
/// to a location pill when the API key is missing.
class EventMapPin extends StatelessWidget {
  const EventMapPin({super.key, required this.event});

  final FandomEventDoc event;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 128,
        width: double.infinity,
        child: event.coverImageUrl?.isNotEmpty == true
            ? CachedImage(url: event.coverImageUrl)
            : _LocationChip(event: event),
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.event});

  final FandomEventDoc event;

  @override
  Widget build(BuildContext context) {
    final label = event.locationLabel.isNotEmpty
        ? event.locationLabel
        : event.city;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: AppColors.accent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
