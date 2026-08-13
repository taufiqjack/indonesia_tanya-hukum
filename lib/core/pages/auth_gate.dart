import 'package:flutter/material.dart';
import 'package:indonesia_law/core/pages/dashboard/dashboard_view.dart';
import 'package:indonesia_law/core/pages/signin_view.dart/auth_controller.dart';
import 'package:indonesia_law/core/pages/signin_view.dart/signin_view.dart';

/// Decides what the app opens on: the chat for a signed-in account, the
/// sign-in page otherwise.
///
/// The app always starts on the sign-in page — no session is restored in the
/// background, so the account is only resolved after the user taps the button.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        if (!auth.isSignedIn) return SigninView(auth: auth);
        // Keyed by account so switching users rebuilds the chat from scratch.
        return DashboardView(key: ValueKey(auth.user!.id), auth: auth);
      },
    );
  }
}
