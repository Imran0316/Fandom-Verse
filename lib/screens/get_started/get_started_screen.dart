import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/liquid_glass.dart';
import '../auth/auth_form.dart';

/// Background slides for the Get Started carousel (files under lib/assets/images/).
const List<String> kGetStartedImages = [
  'lib/assets/images/SignInBG.jfif',
  'lib/assets/images/ertugrulSigninBG.jfif',
  'lib/assets/images/avengersSignInBG.webp',
  'lib/assets/images/DeathNoteSignInBG.webp',
  'lib/assets/images/StrangerThingsSignInBG.webp',
  'lib/assets/images/GTASignInBG.webp',
  'lib/assets/images/breakingBadSignInBG.webp',
  'lib/assets/images/codSignInBG.webp',
  'lib/assets/images/valoSigninBG.webp',
  'lib/assets/images/carsSignInBG.webp',
];

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key, this.openAuthInitially = false});

  final bool openAuthInitially;

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
  late final PageController _pageController;
  int _page = 0;
  Timer? _autoPlay;

  bool _showAuth = false;
  bool _formMounted = false;
  AuthFormMode _mode = AuthFormMode.signUp;

  int get _imageCount => kGetStartedImages.length;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    if (widget.openAuthInitially) {
      _showAuth = true;
      _formMounted = true;
      return;
    }

    _startAutoPlay();
  }

  void _startAutoPlay() {
    if (_imageCount < 2) return;
    _autoPlay?.cancel();
    _autoPlay = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _showAuth || !_pageController.hasClients) return;
      if (!_pageController.hasClients || _imageCount < 2) return;
      final next = (_page + 1) % _imageCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoPlay?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _openAuth() {
    if (_showAuth) return;
    _autoPlay?.cancel();
    setState(() {
      _mode = AuthFormMode.signUp;
      _showAuth = true;
      _formMounted = true;
    });
  }

  void _closeAuth() {
    setState(() => _showAuth = false);
    _startAutoPlay();
  }

  void _handleAuthSuccess(bool didSignUp) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      didSignUp ? AppRoutes.interests : AppRoutes.dashboard,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showAuth,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeAuth();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDeep,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _ImageCarousel(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _page = i),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Color(0x1A000000),
                    Color(0x55000000),
                    Color(0xCC000000),
                    Color(0xFF000000),
                  ],
                  stops: [0.0, 0.22, 0.5, 0.78, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 280),
                opacity: _showAuth ? 0 : 1,
                child: IgnorePointer(
                  ignoring: _showAuth,
                  child: _LandingContent(
                    page: _page,
                    imageCount: _imageCount,
                    onGetStarted: _openAuth,
                  ),
                ),
              ),
            ),
            if (_formMounted)
              // Soft scrim so the frosted form pops against the hero image.
              IgnorePointer(
                ignoring: !_showAuth,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 280),
                  opacity: _showAuth ? 1 : 0,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x59000000),
                          Color(0x73000000),
                          Color(0x8C000000),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_formMounted)
              SafeArea(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 280),
                  opacity: _showAuth ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_showAuth,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                          child: AuthForm(
                            initialMode: _mode,
                            onSuccess: _handleAuthSuccess,
                            onClose: _closeAuth,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageCarousel extends StatelessWidget {
  const _ImageCarousel({
    required this.controller,
    required this.onPageChanged,
  });

  final PageController controller;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (kGetStartedImages.isEmpty) {
      return const ColoredBox(color: AppColors.backgroundDeep);
    }

    return PageView.builder(
      controller: controller,
      onPageChanged: onPageChanged,
      itemCount: kGetStartedImages.length,
      itemBuilder: (context, index) {
        final path = kGetStartedImages[index];
        return SizedBox.expand(
          child: Image.asset(
            path,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: AppColors.background,
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  color: Colors.white24,
                  size: 48,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LandingContent extends StatelessWidget {
  const _LandingContent({
    required this.page,
    required this.imageCount,
    required this.onGetStarted,
  });

  final int page;
  final int imageCount;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        children: [
          const Spacer(),
          if (imageCount > 1) ...[
            // Compact indicators that stay readable with many slides.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 5,
                runSpacing: 6,
                children: List.generate(imageCount, (i) {
                  final active = i == page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: active
                          ? AppColors.accent
                          : Colors.white.withValues(alpha: 0.35),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.55),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
          ],
          _GlowGetStartedButton(onTap: onGetStarted),
          const SizedBox(height: 14),
          Text(
            'By continuing you agree to our Terms & Privacy Policy',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.35,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowGetStartedButton extends StatefulWidget {
  const _GlowGetStartedButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_GlowGetStartedButton> createState() => _GlowGetStartedButtonState();
}

class _GlowGetStartedButtonState extends State<_GlowGetStartedButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  bool _pressed = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final glow = 0.35 + _pulse.value * 0.35;
          final scale = _pressed ? 0.96 : 1.0;

          return AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 120),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: glow * 0.55),
                    blurRadius: 32,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: glow * 0.25),
                    blurRadius: 48,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: LiquidGlass(
                radius: 999,
                blur: 18,
                tint: const Color(0x33FFFFFF),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.28),
                    Colors.white.withValues(alpha: 0.1),
                    AppColors.primary.withValues(alpha: 0.45),
                    AppColors.primaryDark.withValues(alpha: 0.35),
                  ],
                  stops: const [0, 0.4, 0.75, 1],
                ),
                borderColor: Colors.white.withValues(alpha: 0.4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 22,
                    offset: const Offset(0, 14),
                  ),
                ],
                padding: const EdgeInsets.symmetric(
                  horizontal: 52,
                  vertical: 18,
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Get Started',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
