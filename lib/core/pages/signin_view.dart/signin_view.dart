import 'package:flutter/material.dart';
import 'package:indonesia_law/core/pages/register/register_view.dart';
import 'package:indonesia_law/core/pages/signin_view.dart/auth_controller.dart';
import 'package:indonesia_law/core/widgets/auth_form.dart';
import 'package:indonesia_law/core/widgets/common_handle_back.dart';
import 'package:indonesia_law/core/widgets/google_logo.dart';

/// Gate in front of the chat: the assistant only opens once an account has
/// signed in, with an email and a password on the app's own backend or through
/// Google. Shares the dashboard's dark palette.
class SigninView extends StatefulWidget {
  const SigninView({super.key, required this.auth});

  final AuthController auth;

  @override
  State<SigninView> createState() => _SigninViewState();
}

class _SigninViewState extends State<SigninView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // The gate swaps this page for the chat on success, so nothing to do here.
    await widget.auth.signInWithPassword(
      email: _email.text,
      password: _password.text,
    );
  }

  Future<void> _openRegister() async {
    widget.auth.clearError();
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => RegisterView(auth: widget.auth)),
    );

    // An account created without a session comes back with its email, so the
    // only thing left to type is the password.
    if (!mounted || email == null || email.isEmpty) return;
    _email.text = email;
    _password.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => handleBack(context, didPop),
      child: ListenableBuilder(
        listenable: widget.auth,
        builder: (context, _) {
          final isBusy = widget.auth.isBusy;

          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const AuthBrand(
                  title: 'Tanya Hukum',
                  subtitle:
                      'Masuk dulu untuk mulai bertanya.\nRiwayat obrolan '
                      'Anda tersimpan rapi di perangkat ini.',
                ),
                const SizedBox(height: 32),
                AuthTextField(
                  controller: _email,
                  label: 'Alamat email',
                  hint: 'nama@email.com',
                  enabled: !isBusy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: AuthValidators.email,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _password,
                  label: 'Kata sandi',
                  hint: 'Kata sandi Anda',
                  enabled: !isBusy,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Kata sandi wajib diisi.'
                      : null,
                ),
                const SizedBox(height: 24),
                if (widget.auth.error != null) ...[
                  AuthErrorBanner(
                    message: widget.auth.error!,
                    onDismiss: widget.auth.clearError,
                  ),
                  const SizedBox(height: 16),
                ],
                AuthPrimaryButton(
                  label: 'Masuk',
                  isBusy: isBusy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 18),
                const _Divider(),
                // const SizedBox(height: 18),
                // _GoogleButton(enabled: !isBusy, onPressed: widget.auth.signIn),
                const SizedBox(height: 14),
                _RegisterLink(onPressed: isBusy ? null : _openRegister),
                const SizedBox(height: 18),
                const _Disclaimer(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Keeps Google as the second way in, below the form.
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(height: 1, color: AuthPalette.border),
    );

    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'atau',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12.5,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// Outlined twin of the primary button, so Google reads as the alternative.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AuthPalette.surface,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AuthPalette.border),
          ),
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GoogleLogo(size: 19),
                SizedBox(width: 12),
                Text(
                  'Masuk dengan Google',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
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

class _RegisterLink extends StatelessWidget {
  const _RegisterLink({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Belum punya akun?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13.5,
          ),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Daftar sekarang',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
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
