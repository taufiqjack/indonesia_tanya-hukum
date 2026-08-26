import 'package:flutter/material.dart';
import 'package:indonesia_law/core/pages/dashboard/dashboard_view.dart';
import 'package:indonesia_law/core/pages/signin_view.dart/auth_controller.dart';
import 'package:indonesia_law/core/pages/signin_view.dart/signin_view.dart';
import 'package:indonesia_law/core/widgets/auth_form.dart';
import 'package:indonesia_law/core/widgets/spotlight_backdrop.dart';

/// Decides what the app opens on: the chat for a signed-in account, the
/// sign-in page otherwise.
///
/// A session saved by an earlier run counts as signed in, so the splash below
/// covers the moment it takes to read it back rather than showing the sign-in
/// page to someone who is already signed in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        if (auth.isRestoring) return const _Splash();
        if (!auth.isSignedIn) return SigninView(auth: auth);
        // Keyed by account so switching users rebuilds the chat from scratch.
        return DashboardView(key: ValueKey(auth.user!.id), auth: auth);
      },
    );
  }
}

/// Brand mark on the sign-in page's backdrop, held while the saved session is
/// read — short enough that a spinner would only flicker.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.background,
      body: Stack(
        children: [
          const Positioned.fill(child: SpotlightBackdrop()),
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: const Color(0x26FFFFFF)),
              ),
              child: Icon(
                Icons.balance_rounded,
                size: 36,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
