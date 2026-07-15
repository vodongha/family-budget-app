import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/error_text.dart';
import '../../../core/phone_field.dart';
import '../../../core/responsive.dart';
import '../application/auth_controller.dart';
import '../domain/auth_user.dart';
import 'avatar.dart';

/// Edit-profile screen: large avatar, editable display name, read-only email
/// and role. Modern, single-column layout.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  String? _phone;
  bool _saving = false;
  bool _initialised = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(AppLocalizations t) async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(displayName: name, phone: _phone);
      messenger.showSnackBar(SnackBar(content: Text(t.saved)));
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
    final AuthUser? user = ref.watch(authControllerProvider).value;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_initialised) {
      _name.text = user.displayName;
      _phone = user.phone;
      _initialised = true;
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.editProfile)),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  UserAvatar(name: user.displayName, radius: 44),
                  const SizedBox(height: 12),
                  Text(
                    user.email,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.badge_outlined),
                labelText: t.displayName,
              ),
              onSubmitted: (_) => _save(t),
            ),
            const SizedBox(height: 16),
            AppPhoneField(
              initialE164: user.phone,
              label: t.phoneOptional,
              invalidMessage: t.invalidPhone,
              onChanged: (e164) => _phone = e164,
            ),
            const SizedBox(height: 16),
            _InfoCard(
              children: [
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: t.email,
                  value: user.email,
                ),
                const Divider(height: 1),
                _InfoRow(
                  icon: Icons.shield_outlined,
                  label: t.role,
                  value: user.isOwner ? t.roleOwner : t.roleMember,
                ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(t),
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(t.save),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(label,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
      subtitle: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
    );
  }
}
