import 'package:flutter/material.dart';

import '../screens/auth/auth_form.dart';

/// Shows the auth form as a bottom sheet popup.
/// Returns `true` if the user successfully signed in/up, `false` otherwise.
Future<bool?> showAuthPopup(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const AuthPopup(),
  );
}

class AuthPopup extends StatefulWidget {
  const AuthPopup({super.key});

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
              child: AuthForm(
                initialMode: AuthFormMode.signIn,
                onSuccess: _handleSuccess,
                onClose: _handleClose,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
