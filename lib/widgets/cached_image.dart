import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Disk-cached network image used across the app so covers, avatars and
/// merch photos stay visible offline (the requirement's "data shows even
/// without a connection"). Falls back to [errorWidget] on bad URLs.
///
/// [circular] clips the image to a circle (avatars).
class CachedImage extends StatelessWidget {
  const CachedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.circular = false,
    this.memCacheWidth,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool circular;
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final src = (url ?? '').trim();
    if (src.isEmpty) return const _Missing();

    final Widget image;
    try {
      image = CachedNetworkImage(
        imageUrl: src,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: memCacheWidth,
        fadeInDuration: Duration.zero,
        placeholder: (_, _) => const _Missing(),
        errorWidget: (_, _, _) => const _Missing(),
      );
    } catch (_) {
      return const _Missing();
    }

    if (circular) {
      return ClipOval(child: image);
    }
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.06),
      child: const SizedBox.expand(),
    );
  }
}
