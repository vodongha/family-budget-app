import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';

/// Shown once, right after a brand-new account signs in: the user has no family
/// yet (the router redirects here until they do). They either create a family —
/// becoming its owner — or open their invitations to join an existing one.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _familyName = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _familyName.dispose();
    super.dispose();
  }

  Future<void> _create(AppLocalizations t) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // On success the auth state refreshes with the new family scope and the
      // router redirects to the dashboard — no manual navigation needed.
      await ref
          .read(authControllerProvider.notifier)
          .createFamily(_familyName.text.trim());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
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

    return Scaffold(
      appBar: AppBar(
        title: Text(t.setUpFamilyTitle),
        actions: [
          TextButton(
            onPressed: _saving
                ? null
                : () => ref.read(authControllerProvider.notifier).logout(),
            child: Text(t.signOut),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.diversity_3, size: 56, color: cs.primary),
                const SizedBox(height: 16),
                Text(
                  t.setUpFamilyIntro,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _familyName,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: t.familyName,
                      prefixIcon: const Icon(Icons.home_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? t.fieldRequired
                        : null,
                    onFieldSubmitted: (_) => _create(t),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _create(t),
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_home_outlined),
                  label: Text(t.createFamily),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  t.haveInvite,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed:
                      _saving ? null : () => context.push('/invitations'),
                  icon: const Icon(Icons.mail_outline),
                  label: Text(t.checkInvitations),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
