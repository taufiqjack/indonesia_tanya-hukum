import 'package:flutter/material.dart';
import 'package:indonesia_law/core/components/toast.dart';
import 'package:indonesia_law/core/pages/register/register_controller.dart';
import 'package:indonesia_law/core/pages/signin_view.dart/auth_controller.dart';
import 'package:indonesia_law/core/widgets/auth_form.dart';

/// Creates an account on the app's own backend.
///
/// The backend decides what happens next: it either hands back a session, and
/// the new account goes straight into the chat, or it only confirms the account
/// exists, and the email is carried back to the sign-in page.
class RegisterView extends StatefulWidget {
  const RegisterView({super.key, required this.auth});

  final AuthController auth;

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _controller = RegisterController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await _controller.submit(
      firstName: _firstName.text,
      lastName: _lastName.text,
      email: _email.text,
      password: _password.text,
    );
    if (result == null || !mounted) return;

    final user = result.user;
    if (user != null) {
      // Signed in already: adopt the session first so the gate has the chat
      // ready behind this page, then leave.
      await widget.auth.adopt(user);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    toast(context, 'Akun berhasil dibuat. Silakan masuk.');
    Navigator.of(context).pop(_email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final isBusy = _controller.isBusy;

          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: isBusy ? null : () => Navigator.of(context).pop(),
                    tooltip: 'Kembali',
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 6),
                const AuthBrand(
                  title: 'Buat akun',
                  subtitle: 'Isi data di bawah untuk mulai bertanya soal '
                      'hukum di Indonesia.',
                ),
                const SizedBox(height: 28),
                AuthTextField(
                  controller: _firstName,
                  label: 'Nama depan',
                  hint: 'Taufiq',
                  enabled: !isBusy,
                  keyboardType: TextInputType.name,
                  autofillHints: const [AutofillHints.givenName],
                  validator: (value) =>
                      AuthValidators.notEmpty(value, 'Nama depan'),
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _lastName,
                  label: 'Nama belakang',
                  hint: 'Cahyono',
                  enabled: !isBusy,
                  keyboardType: TextInputType.name,
                  autofillHints: const [AutofillHints.familyName],
                  validator: (value) =>
                      AuthValidators.notEmpty(value, 'Nama belakang'),
                ),
                const SizedBox(height: 16),
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
                  hint: 'Minimal 8 karakter',
                  enabled: !isBusy,
                  obscure: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: AuthValidators.password,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _confirmation,
                  label: 'Konfirmasi kata sandi',
                  hint: 'Ulangi kata sandi',
                  enabled: !isBusy,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Konfirmasi kata sandi wajib diisi.';
                    }
                    if (value != _password.text) {
                      return 'Konfirmasi kata sandi belum sama.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_controller.error != null) ...[
                  AuthErrorBanner(
                    message: _controller.error!,
                    onDismiss: _controller.clearError,
                  ),
                  const SizedBox(height: 16),
                ],
                AuthPrimaryButton(
                  label: 'Daftar sekarang',
                  isBusy: isBusy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 18),
                _SignInLink(
                  onPressed: isBusy ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Way back for someone who already has an account.
class _SignInLink extends StatelessWidget {
  const _SignInLink({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Sudah punya akun?',
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
            'Masuk',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
