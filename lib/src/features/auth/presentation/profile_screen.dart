import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/prefs.dart';
import '../application/auth_controller.dart';
import '../domain/auth_user.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final AuthUser? user = ref.watch(authControllerProvider).valueOrNull;
    final Locale? locale = ref.watch(localeControllerProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.profile)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(t.displayName),
            subtitle: Text(user.displayName),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editName(context, ref, t, user.displayName),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: Text(t.email),
            subtitle: Text(user.email),
          ),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: Text(t.role),
            subtitle: Text(user.isOwner ? t.roleOwner : t.roleMember),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(t.language),
            subtitle: Text(_localeLabel(t, locale)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLanguage(context, ref, t, locale),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(t.signOut),
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.delete_forever),
              label: Text(t.deleteAccount),
              onPressed: () => _confirmDelete(context, ref, t),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _localeLabel(AppLocalizations t, Locale? locale) {
    return switch (locale?.languageCode) {
      'en' => t.english,
      'vi' => t.vietnamese,
      _ => t.systemDefault,
    };
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    String current,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(authControllerProvider.notifier);
    final controller = TextEditingController(text: current);
    final String? name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.editName),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: t.displayName),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(t.save),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == current) {
      return;
    }
    try {
      await notifier.updateDisplayName(name);
      messenger.showSnackBar(SnackBar(content: Text(t.saved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    Locale? current,
  ) async {
    final String selected = current?.languageCode ?? 'system';
    final options = <(String, String)>[
      ('system', t.systemDefault),
      ('en', t.english),
      ('vi', t.vietnamese),
    ];
    // Returns a marker: 'system' / 'en' / 'vi'; a null result means dismissed.
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (code, label) in options)
              ListTile(
                title: Text(label),
                trailing: code == selected
                    ? Icon(Icons.check,
                        color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, code),
              ),
          ],
        ),
      ),
    );
    if (choice == null) {
      return; // dismissed without choosing
    }
    final Locale? locale = choice == 'system' ? null : Locale(choice);
    await ref.read(localeControllerProvider.notifier).setLocale(locale);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(authControllerProvider.notifier);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteAccount),
        content: Text(t.deleteAccountWarning),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.deleteAccountConfirm),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      await notifier.deleteAccount();
      // Auth state is now null → the router redirects to /login automatically.
      messenger.showSnackBar(SnackBar(content: Text(t.accountDeleted)));
    } on ApiException catch (e) {
      final String msg = e.statusCode == 409 ? t.ownerMustTransfer : e.message;
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}
