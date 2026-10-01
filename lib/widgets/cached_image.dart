import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
import 'package:flutter/material.dart';

/// Disk-cached network image used across the app so covers, avatars and
/// merch photos stay visible offline (the requirement's "data shows even
/// without a connection"). Falls back to [_Missing] on bad URLs.
///
/// Two things this widget exists to guarantee:
///
/// * On web the bytes are fetched over HTTP and decoded from memory
///   ([ImageRenderMethodForWeb.HttpGet]) instead of the default
///   `HtmlImage` `<img>` element. An `<img>`-backed texture taints the
///   CanvasKit surface, so every later draw throws
///   `SecurityError: The image element contains cross-origin data` and the
///   whole feed blanks out.
/// * The widget tree always contains a real [Image] once a URL is present,
///   so semantics and widget tests see the image even while it is loading
///   or when the network is unavailable.
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
    this.memCacheHeight,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool circular;
  final int? memCacheWidth;
  final int? memCacheHeight;

  static const int _maxDecodeWidth = 1280;

  @override
  Widget build(BuildContext context) {
    final src = (url ?? '').trim();
    if (src.isEmpty) return const _Missing();

    ImageProvider provider = CachedNetworkImageProvider(
      src,
      imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
    );
    if (memCacheWidth != null || memCacheHeight != null) {
      provider = ResizeImage(
        provider,
        width: memCacheWidth,
        height: memCacheHeight,
      );
    } else {
      provider = ResizeImage(provider, width: _maxDecodeWidth);
    }

    final Widget image = Image(
      image: provider,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      // Neutral block until the first frame decodes, and the same block for
      // a dead URL — never a broken-image glyph.
      frameBuilder: (context, child, frame, wasSyncLoaded) =>
          (wasSyncLoaded || frame != null) ? child : const _Missing(),
      errorBuilder: (_, _, _) => const _Missing(),
    );

    if (circular) return ClipOval(child: image);
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
