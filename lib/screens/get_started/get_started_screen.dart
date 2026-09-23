import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/ambient_particles.dart';
import '../../widgets/glass_button.dart';
import '../auth/auth_form.dart';

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key, this.openAuthInitially = false});

  final bool openAuthInitially;

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen>
    with SingleTickerProviderStateMixin {
  static const _ease = Cubic(0.22, 1, 0.36, 1);

  late final AnimationController _formAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  bool _showAuth = false;
  bool _formMounted = false;
  AuthFormMode _mode = AuthFormMode.signUp;

  @override
  void initState() {
    super.initState();
    if (widget.openAuthInitially) {
      _showAuth = true;
      _formMounted = true;
      _formAnim.value = 1;
    }
  }

  @override
  void dispose() {
    _formAnim.dispose();
    super.dispose();
  }

  void _openAuth() {
    setState(() {
      _mode = AuthFormMode.signUp;
      _showAuth = true;
      _formMounted = true;
    });
    _formAnim.forward();
  }

  void _closeAuth() {
    setState(() => _showAuth = false);
    _formAnim.reverse().whenComplete(() {
      if (mounted && !_showAuth) {
        setState(() => _formMounted = false);
      }
    });
  }

  void _goToDashboard() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.dashboard,
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
            Image.asset(
              'lib/assets/images/SignInBG.jfif',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.backgroundDeep),
            ),
            const Positioned.fill(child: AmbientParticles()),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.42, 0.68, 1.0],
                  colors: [
                    Color(0x22000000),
                    Colors.transparent,
                    Color(0x99000000),
                    Color(0xF2000000),
                  ],
                ),
              ),
            ),
            // Scrim that deepens when the form is open
            AnimatedBuilder(
              animation: _formAnim,
              builder: (context, _) {
                return IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: 0.45 * _ease.transform(_formAnim.value),
                    ),
                  ),
                );
              },
            ),
            SafeArea(
              child: Stack(
                children: [
                  _buildCta(),
                  if (_formMounted)
                    AnimatedBuilder(
                    animation: _formAnim,
                    builder: (context, child) {
                      final t = _ease.transform(_formAnim.value);
                      return IgnorePointer(
                        ignoring: t < 0.05,
                        child: Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 28 * (1 - t)),
                            child: Transform.scale(
                              scale: 0.96 + 0.04 * t,
                              child: child,
                            ),
                          ),
                        ),
                      );
                    },
                    child: ExcludeSemantics(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                          child: AuthForm(
                            initialMode: _mode,
                            onSuccess: _goToDashboard,
                            onClose: _closeAuth,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCta() {
    final t = _ease.transform(_formAnim.value);
    final hide = 1 - t;

    return IgnorePointer(
      ignoring: _showAuth,
      child: Opacity(
        opacity: hide.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 16 * t),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 30),
            child: Column(
              children: [
                const Spacer(),
                GlassButton(
                  label: 'Get Started',
                  onPressed: _openAuth,
                ),
                const SizedBox(height: 18),
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 13,
                      height: 1.55,
                      fontWeight: FontWeight.w400,
                    ),
                    children: [
                      TextSpan(
                        text:
                            'By continuing, you agree to our terms of\nServices and ',
                      ),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: Color(0xFFE5E7EB),
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
      ),
    );
  }
}
