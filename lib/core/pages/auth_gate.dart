import 'package:flutter/material.dart';
import 'package:indonesia_law/core/pages/dashboard/dashboard_view.dart';
import 'package:indonesia_law/core/pages/signin_view.dart/auth_controller.dart';
import 'package:indonesia_law/core/pages/signin_view.dart/signin_view.dart';

/// Decides what the app opens on: the chat for a signed-in account, the
/// sign-in page otherwise.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth});

  final AuthController auth;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    widget.auth.restore();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.auth,
      builder: (context, _) {
        if (widget.auth.isRestoring) return const _Splash();
        if (!widget.auth.isSignedIn) return SigninView(auth: widget.auth);
        // Keyed by account so switching users rebuilds the chat from scratch.
        return DashboardView(
          key: ValueKey(widget.auth.user!.id),
          auth: widget.auth,
        );
      },
    );
  }
}

/// Held while the previous session is being checked, so the sign-in page never
/// flashes for an already signed-in user.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: SigninView.background,
      body: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      ),
    );
  }
}
