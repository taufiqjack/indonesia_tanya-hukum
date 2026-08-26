import 'package:flutter/material.dart';
import 'package:indonesia_law/core/widgets/spotlight_backdrop.dart';

/// The dark palette the sign-in and register pages share with the chat.
abstract final class AuthPalette {
  static const background = Color(0xFF050505);
  static const surface = Color(0xFF141414);
  static const border = Color(0x1AFFFFFF);
  static const danger = Color(0xFFFF8A8A);
}

/// Page frame for the account pages: spotlight backdrop, safe area and a
/// scroll that keeps the form reachable once the keyboard is up.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.onPopInvokedWithResult,
    this.canPop = true,
  });

  final Widget child;
  final bool canPop;
  final void Function(bool didPop, Object? result)? onPopInvokedWithResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.background,
      body: PopScope(
        canPop: canPop,
        onPopInvokedWithResult: onPopInvokedWithResult,
        child: Stack(
          children: [
            const Positioned.fill(child: SpotlightBackdrop()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 40,
                      ),
                      child: child,
                    ),
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

/// App mark, name and one-line pitch, shown above both forms.
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: const Color(0x26FFFFFF)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              'assets/images/icon_th_tr.png',
              height: 56,
              width: 56,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Labelled field on the dark surface, with the eye toggle a password needs.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.obscure = false,
    this.enabled = true,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final bool obscure;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(16));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          validator: widget.validator,
          onFieldSubmitted: widget.onFieldSubmitted,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          cursorColor: Colors.white,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: AuthPalette.surface,
            hintText: widget.hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14.5,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            errorStyle: const TextStyle(
              color: AuthPalette.danger,
              fontSize: 12,
            ),
            suffixIcon: widget.obscure
                ? IconButton(
                    onPressed: () => setState(() => _hidden = !_hidden),
                    tooltip: _hidden ? 'Tampilkan' : 'Sembunyikan',
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 19,
                    ),
                    color: Colors.white.withValues(alpha: 0.45),
                  )
                : null,
            border: const OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AuthPalette.border),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AuthPalette.border),
            ),
            disabledBorder: const OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AuthPalette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: Color(0x66FF6B6B)),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AuthPalette.danger),
            ),
          ),
        ),
      ],
    );
  }
}

/// White pill, matching the send button on the chat composer.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
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
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Failure from the backend, shown above the submit button.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

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
            color: AuthPalette.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AuthPalette.danger,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Tutup',
            icon: const Icon(Icons.close_rounded, size: 16),
            color: AuthPalette.danger,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Shared field rules, so both pages reject the same things the same way.
abstract final class AuthValidators {
  static final _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static String? notEmpty(String? value, String label) =>
      (value?.trim().isEmpty ?? true) ? '$label wajib diisi.' : null;

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Alamat email wajib diisi.';
    if (!_email.hasMatch(trimmed)) return 'Format alamat email belum benar.';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Kata sandi wajib diisi.';
    if (text.length < 8) return 'Kata sandi minimal 8 karakter.';
    return null;
  }
}
