import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/phone_field.dart';
import '../application/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _familyName = TextEditingController();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _phone;

  @override
  void dispose() {
    _familyName.dispose();
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await ref.read(authControllerProvider.notifier).register(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _displayName.text.trim(),
          familyName: _familyName.text.trim(),
          phone: _phone,
        );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final bool busy = ref.watch(authControllerProvider).isLoading;

    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('${next.error}')));
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(t.createFamilyTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _familyName,
                    decoration: InputDecoration(labelText: t.familyName),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? t.fieldRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _displayName,
                    decoration: InputDecoration(labelText: t.yourName),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? t.fieldRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: t.email),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? t.enterValidEmail
                        : null,
                  ),
                  const SizedBox(height: 16),
                  AppPhoneField(
                    initialE164: null,
                    label: t.phoneOptional,
                    invalidMessage: t.invalidPhone,
                    onChanged: (e164) => _phone = e164,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(labelText: t.password),
                    validator: (v) =>
                        (v == null || v.length < 8) ? t.passwordMin : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t.createFamilyAndSignIn),
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
