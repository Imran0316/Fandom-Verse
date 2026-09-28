import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/liquid_segmented_control.dart';

enum AuthFormMode { signIn, signUp }

class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    required this.initialMode,
    required this.onSuccess,
    required this.onClose,
  });

  final AuthFormMode initialMode;
  final ValueChanged<bool> onSuccess;
  final VoidCallback onClose;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AuthFormMode _mode = widget.initialMode;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  bool _obscurePassword = true;
  bool _loading = false;
  bool _googleLoading = false;

  bool get _isSignIn => _mode == AuthFormMode.signIn;

  @override
  void initState() {
    super.initState();
    _swap.value = 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _swap.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageOf(Object error) {
    final text = error.toString();
    if (text.contains('firebase-not-configured')) {
      return 'Firebase is not connected yet — run flutterfire configure first.';
    }
    if (text.contains(']')) {
      final code = text.substring(text.indexOf(']') + 1).trim();
      if (code.isNotEmpty) return code;
    }
    return 'Something went wrong. Please try again.';
  }

  void _switchMode(int index) {
    final next = index == 0 ? AuthFormMode.signIn : AuthFormMode.signUp;
    if (next == _mode) return;
    FocusScope.of(context).unfocus();
    setState(() => _mode = next);
    _formKey.currentState?.reset();
    _swap.forward(from: 0);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      if (_isSignIn) {
        await AuthService.instance.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await AuthService.instance.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
      }
      if (!mounted) return;
      widget.onSuccess(!_isSignIn);
    } catch (e) {
      _showMessage(_messageOf(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() => _googleLoading = true);
    try {
      await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      widget.onSuccess(false);
    } catch (e) {
      _showMessage(_messageOf(e));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Enter your email first, then tap "Forgot password".');
      return;
    }
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      _showMessage('Password reset email sent to $email.');
    } catch (e) {
      _showMessage(_messageOf(e));
    }
  }

  Widget _buildFields() {
    return Column(
      key: ValueKey(_mode),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isSignIn) ...[
          AppTextField(
            controller: _nameController,
            label: 'Username',
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Username is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
        ],
        AppTextField(
          controller: _emailController,
          label: 'Email',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.isEmpty) return 'Email is required';
            if (!v.contains('@') || !v.contains('.')) {
              return 'Enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _passwordController,
          label: 'Password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            if (value.length < 6) {
              return 'At least 6 characters';
            }
            return null;
          },
          suffixIcon: IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 21,
            ),
          ),
        ),
        if (_isSignIn)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loading ? null : _forgotPassword,
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Liquid glass: light blur, very low fill so the hero image stays visible.
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.4),
            Colors.white.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.22),
          ],
          stops: const [0, 0.35, 0.7, 1],
        ),
      ),
      child: LiquidGlass(
        radius: 27,
        blur: 12,
        tint: const Color(0x1F080810),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.03),
            Colors.white.withValues(alpha: 0.06),
            AppColors.primary.withValues(alpha: 0.08),
          ],
          stops: const [0, 0.4, 0.75, 1],
        ),
        borderColor: Colors.white.withValues(alpha: 0.26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 40,
            spreadRadius: -6,
            offset: const Offset(0, 18),
          ),
        ],
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
        child: Form(
          key: _formKey,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isSignIn ? 'Welcome back' : 'Join FandomVerse',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: InkWell(
                        onTap: widget.onClose,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LiquidSegmentedControl(
                  labels: const ['Sign In', 'Create Account'],
                  selectedIndex: _isSignIn ? 0 : 1,
                  onIndexChanged: _switchMode,
                ),
                const SizedBox(height: 22),
                AnimatedBuilder(
                  animation: _swap,
                  builder: (context, child) {
                    final t = Curves.easeOutCubic.transform(_swap.value);
                    final fade =
                        _swap.status == AnimationStatus.forward ||
                            _swap.value == 1
                        ? t
                        : t;
                    return Opacity(
                      opacity: fade.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - t)),
                        child: Transform.scale(
                          scale: 0.985 + 0.015 * t,
                          alignment: Alignment.topCenter,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: _buildFields(),
                ),
                const SizedBox(height: 12),
                GlassButton(
                  label: _isSignIn ? 'Sign In' : 'Create Account',
                  variant: GlassButtonVariant.sleek,
                  isLoading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0x33FFFFFF))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or continue with',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0x33FFFFFF))),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: (_loading || _googleLoading)
                        ? null
                        : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 1.2,
                      ),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _googleLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : const Icon(Icons.g_mobiledata_rounded, size: 30),
                    label: const Text(
                      'Google',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
