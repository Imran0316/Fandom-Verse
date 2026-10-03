import 'package:flutter/material.dart';

import '../screens/auth/auth_form.dart';

/// Shows the auth form as a bottom sheet popup.
/// Returns `true` if the user successfully signed in/up, `false` otherwise.
///
/// [message] is an optional one-line reason shown above the form ("Sign in to
/// comment on reels.") so the gate reads as context, not an error.
Future<bool?> showAuthPopup(BuildContext context, {String? message}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AuthPopup(message: message),
  );
}

class AuthPopup extends StatefulWidget {
  const AuthPopup({super.key, this.message});

  final String? message;

  @override
  State<AuthPopup> createState() => _AuthPopupState();
}

class _AuthPopupState extends State<AuthPopup> {
  void _handleSuccess(bool didSignUp) {
    Navigator.of(context).pop(true);
  }

  void _handleClose() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
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
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.message != null &&
                      widget.message!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 16),
                      child: Text(
                        widget.message!.trim(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontSize: 14.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  AuthForm(
                    initialMode: AuthFormMode.signIn,
                    onSuccess: _handleSuccess,
                    onClose: _handleClose,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
