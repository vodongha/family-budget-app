import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/error_text.dart';
import '../../auth/application/auth_controller.dart';
import '../data/invitation_repository.dart';
import '../domain/invitation.dart';

/// Public invite landing page. Shows the family being joined, then registers the
/// invitee (auto-login). Reached via the shared link `/invite/:token`.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final Future<InvitationPublic> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(invitationRepositoryProvider).getPublic(widget.token);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _accept(AppLocalizations t, bool needsEmail) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(invitationRepositoryProvider).accept(
            token: widget.token,
            password: _password.text,
            displayName: _name.text.trim(),
            email: needsEmail ? _email.text.trim() : null,
          );
      // New session token is stored â€” re-read auth so the router enters the app.
      ref.invalidate(authControllerProvider);
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

    return Scaffold(
      appBar: AppBar(title: Text(t.joinFamilyTitle)),
      body: FutureBuilder<InvitationPublic>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _Centered(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_off, size: 48, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(t.invitationInvalid, textAlign: TextAlign.center),
                ],
              ),
            );
          }
          final InvitationPublic inv = snapshot.data!;
          final bool needsEmail = inv.needsEmail;

          return _Centered(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.groups_outlined, size: 56, color: cs.primary),
                  const SizedBox(height: 16),
                  Text(
                    t.invitedToJoin,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    inv.familyName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _name,
                    decoration: InputDecoration(labelText: t.yourName),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? t.fieldRequired
                        : null,
                  ),
                  if (needsEmail) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: t.email),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? t.enterValidEmail
                          : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration:
                        InputDecoration(labelText: t.createYourPassword),
                    validator: (v) =>
                        (v == null || v.length < 8) ? t.passwordMin : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : () => _accept(t, needsEmail),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t.acceptAndJoin),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: child,
        ),
      ),
    );
  }
}
