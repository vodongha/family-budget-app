import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/error_text.dart';
import '../application/auth_controller.dart';
import '../domain/auth_user.dart';

/// Change the account password â€” or, for a Google-only account that has none
/// yet, set the first password (no current-password field).
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations t, bool hasPassword) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            currentPassword: hasPassword ? _current.text : null,
            newPassword: _next.text,
          );
      messenger.showSnackBar(SnackBar(content: Text(t.passwordChanged)));
      navigator.pop();
    } catch (e) {
      if (mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AuthUser? user = ref.watch(authControllerProvider).valueOrNull;
    final bool hasPassword = user?.hasPassword ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(hasPassword ? t.changePassword : t.setPassword),
      ),
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
                  if (!hasPassword) ...[
                    Text(
                      t.setPasswordHint,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (hasPassword) ...[
                    TextFormField(
                      controller: _current,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: t.currentPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? t.fieldRequired : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _next,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: t.newPassword,
                      prefixIcon: const Icon(Icons.lock_reset_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 8) ? t.passwordMin : null,
                    onFieldSubmitted: (_) => _submit(t, hasPassword),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : () => _submit(t, hasPassword),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(hasPassword ? t.changePassword : t.setPassword),
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
