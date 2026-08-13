import 'package:flutter/material.dart';

/// Two soft light cones falling from the top of the screen, used behind the
/// empty chat state and the sign-in page.
class SpotlightBackdrop extends StatelessWidget {
  const SpotlightBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          children: const [
            _Spotlight(alignment: Alignment(-0.5, -1.6)),
            _Spotlight(alignment: Alignment(0.5, -1.6)),
          ],
        ),
      ),
    );
  }
}

class _Spotlight extends StatelessWidget {
  const _Spotlight({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 320,
        height: 420,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}
