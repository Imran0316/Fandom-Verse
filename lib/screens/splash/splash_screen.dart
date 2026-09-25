import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';

/// Full-screen animated launch screen.
///
/// Staged reveal: dark backdrop -> poster collage -> logo with a soft brand
/// glow -> "FanVerse" wordmark, then a bounded hand-off to the first real
/// screen (dashboard when signed in, onboarding otherwise).
///
/// The reveal starts synchronously on the first frame — it never waits on
/// asset decoding, and both images have graceful fallbacks, so the screen
/// can never be left blank or stuck.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const String _bgAsset = 'lib/assets/images/splash/splashScreenBG.png';
  static const String _logoAsset =
      'lib/assets/images/splash/splashScreenLogo.png';

  /// Total length of the staged reveal. Fractions below map onto it.
  static const Duration _sequenceDuration = Duration(milliseconds: 3000);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _sequenceDuration,
  );

  late final Animation<double> _bgOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.03, 0.2, curve: Curves.easeOut),
  );

  late final Animation<double> _bgScale =
      Tween<double>(begin: 1.06, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.03, 0.97, curve: Curves.easeOutCubic),
        ),
      );

  late final Animation<double> _vignetteOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.03, 0.26, curve: Curves.easeOut),
  );

  late final Animation<double> _logoOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.24, 0.42, curve: Curves.easeOut),
  );

  late final Animation<double> _logoScale =
      Tween<double>(begin: 0.84, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.24, 0.5, curve: Curves.easeOutCubic),
        ),
      );

  late final Animation<double> _glowOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.24, 0.55, curve: Curves.easeOut),
  );

  late final Animation<double> _titleOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.44, 0.6, curve: Curves.easeOut),
  );

  late final Animation<double> _titleOffset =
      Tween<double>(begin: 22, end: 0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.44, 0.64, curve: Curves.easeOutCubic),
        ),
      );

  late final Animation<double> _titleSpacing =
      Tween<double>(begin: 10, end: 2.5).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.44, 0.72, curve: Curves.easeOutCubic),
        ),
      );

  Timer? _navigationTimer;
  bool _sequenceStarted = false;
  bool _navigating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sequenceStarted) return;
    _sequenceStarted = true;

    // Warm the image cache in the background; the reveal never waits on it.
    unawaited(
      Future.wait(<Future<void>>[
        precacheImage(const AssetImage(_bgAsset), context),
        precacheImage(const AssetImage(_logoAsset), context),
      ]).catchError((Object _) => <void>[]),
    );

    _controller.forward();
    _navigationTimer = Timer(
      const Duration(milliseconds: 2400),
      _navigateWhenReady,
    );
  }

  Future<void> _navigateWhenReady() async {
    if (!mounted || _navigating) return;
    _navigating = true;

    // Give Firebase a bounded window (~3s, usually already done) to finish
    // initializing so we land on the right destination. Counts timer ticks
    // instead of wall-clock time so it behaves under test fake-time too.
    int waitedMs = 0;
    while (mounted && !AuthService.instance.isReady && waitedMs < 3000) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      waitedMs += 80;
    }
    if (!mounted) return;

    final String next = AuthService.instance.isSignedIn
        ? AppRoutes.dashboard
        : AppRoutes.getStarted;
    Navigator.of(context).pushReplacementNamed(next);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final double shortestSide = MediaQuery.sizeOf(context).shortestSide;
          final double logoSize = (shortestSide * 0.46).clamp(150.0, 230.0);

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Opacity(
                opacity: _bgOpacity.value,
                child: Transform.scale(
                  scale: _bgScale.value,
                  child: Image.asset(
                    _bgAsset,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: _fallbackBackdrop,
                  ),
                ),
              ),
              Opacity(
                opacity: _vignetteOpacity.value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                      stops: const <double>[0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: SizedBox(
                          width: logoSize * 1.65,
                          height: logoSize * 1.65,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              Opacity(
                                opacity: _glowOpacity.value,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: <Color>[
                                        AppColors.primary.withValues(
                                          alpha: 0.38,
                                        ),
                                        AppColors.primary.withValues(
                                          alpha: 0.0,
                                        ),
                                      ],
                                    ),
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                              ClipOval(
                                child: Image.asset(
                                  _logoAsset,
                                  width: logoSize,
                                  height: logoSize,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stack) =>
                                      _FallbackLogo(size: logoSize),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: logoSize * 0.16),
                    Opacity(
                      opacity: _titleOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _titleOffset.value),
                        child: Text(
                          'FanVerse',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 38,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: _titleSpacing.value,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _fallbackBackdrop(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF17171F), Color(0xFF0A0A0F)],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.surfaceLight,
            AppColors.surface.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Icon(
        Icons.movie_creation_outlined,
        size: size * 0.42,
        color: AppColors.textSecondary,
      ),
    );
  }
}
