import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../core/animations/app_transitions.dart';

/// Lottie wrapper with graceful Flutter fallback when asset/network fails.
class LottieView extends StatelessWidget {
  const LottieView({
    super.key,
    this.asset,
    this.networkUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.repeat = true,
    this.controller,
    this.fallback,
  });

  final String? asset;
  final String? networkUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool repeat;
  final AnimationController? controller;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final child = fallback ?? const PulseDot();

    Widget? lottie;
    if (asset != null && asset!.isNotEmpty) {
      lottie = Lottie.asset(
        asset!,
        width: width,
        height: height,
        fit: fit,
        repeat: repeat,
        controller: controller,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    } else if (networkUrl != null && networkUrl!.isNotEmpty) {
      lottie = Lottie.network(
        networkUrl!,
        width: width,
        height: height,
        fit: fit,
        repeat: repeat,
        controller: controller,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }

    if (lottie == null) {
      return SizedBox(width: width, height: height, child: child);
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.passthrough,
        alignment: Alignment.center,
        children: [child, lottie],
      ),
    );
  }
}

/// Success sheet with Lottie (or pulse) + message.
Future<void> showSuccessSheet(
  BuildContext context, {
  required String title,
  String? message,
  Duration autoClose = const Duration(milliseconds: 1600),
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (sheetContext) {
      Future.delayed(autoClose, () {
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      });
      return Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xF2101018),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LottieView(
                width: 100,
                height: 100,
                repeat: false,
                asset: 'lib/assets/lottie/success.json',
                fallback: const PulseDot(size: 72),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
