import 'package:flutter/material.dart';
import 'package:indonesia_law/core/pages/signin_view.dart/auth_controller.dart';
import 'package:indonesia_law/core/widgets/common_handle_back.dart';
import 'package:indonesia_law/core/widgets/google_logo.dart';
import 'package:indonesia_law/core/widgets/spotlight_backdrop.dart';

/// Gate in front of the chat: the assistant only opens once a Google account
/// has signed in. Shares the dashboard's dark palette.
class SigninView extends StatelessWidget {
  const SigninView({super.key, required this.auth});

  static const background = Color(0xFF050505);
  static const surface = Color(0xFF141414);
  static const border = Color(0x1AFFFFFF);

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) => handleBack(context, didPop),
        child: Stack(
          children: [
            const Positioned.fill(child: SpotlightBackdrop()),
            SafeArea(
              child: ListenableBuilder(
                listenable: auth,
                builder: (context, _) {
                  return Column(
                    children: [
                      const Spacer(flex: 3),
                      const _Brand(),
                      const Spacer(flex: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            if (auth.error != null) ...[
                              _ErrorBanner(
                                message: auth.error!,
                                onDismiss: auth.clearError,
                              ),
                              const SizedBox(height: 14),
                            ],
                            _GoogleButton(
                              isBusy: auth.isBusy,
                              onPressed: auth.signIn,
                            ),
                            const SizedBox(height: 18),
                            const _Disclaimer(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App mark, name and one-line pitch.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
          const SizedBox(height: 26),
          const Text(
            'Hukum AI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Masuk dulu untuk mulai bertanya.\nRiwayat obrolan Anda tersimpan '
            'rapi di perangkat ini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

/// White pill, matching the send button on the chat composer.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.isBusy, required this.onPressed});

  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isBusy ? null : onPressed,
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: Center(
            child: isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.black54,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      GoogleLogo(size: 21),
                      SizedBox(width: 12),
                      Text(
                        'Masuk dengan Google',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: const Color(0x1AFF6B6B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33FF6B6B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFFFF8A8A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFF8A8A),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Tutup',
            icon: const Icon(Icons.close_rounded, size: 16),
            color: const Color(0xFFFF8A8A),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Hukum AI memberi informasi umum, bukan pengganti konsultasi dengan '
      'advokat.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.38),
        fontSize: 12,
        height: 1.5,
      ),
    );
  }
}
