import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/error_text.dart';
import '../../../core/responsive.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../../members/application/members_controller.dart';
import '../../wallets/application/wallet_scope.dart';

/// Manage the current family: rename, see members, leave, or (owner, sole
/// member) delete it. Leaving/deleting returns to the personal-only space.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AuthUser? user = ref.watch(authControllerProvider).valueOrNull;

    if (user == null || !user.hasFamily) {
      return Scaffold(
        appBar: AppBar(title: Text(t.manageFamily)),
        body: Center(child: Text(t.setUpFamilyIntro)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.manageFamily)),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: cs.primaryContainer,
                      child: Icon(Icons.home_rounded, color: cs.primary),
                    ),
                    const SizedBox(width: 16),
                    // Expanded so a long family name wraps gracefully instead of
                    // collapsing into a one-character-per-line column.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.family,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.familyName ?? t.family,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (user.isOwner)
                      TextButton.icon(
                        onPressed: () => _rename(context, ref, t, user),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(t.rename),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.group_outlined, color: cs.primary),
                title: Text(t.members),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/members'),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.logout, color: cs.error),
                    title:
                        Text(t.leaveFamily, style: TextStyle(color: cs.error)),
                    onTap: () => _leave(context, ref, t),
                  ),
                  if (user.isOwner) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.delete_outline, color: cs.error),
                      title: Text(t.deleteFamily,
                          style: TextStyle(color: cs.error)),
                      onTap: () => _delete(context, ref, t),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    AuthUser user,
  ) async {
    final controller = TextEditingController(text: user.familyName ?? '');
    final messenger = ScaffoldMessenger.of(context);
    final String? name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowButtonSpacing: 8,
        title: Text(t.renameFamily),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: t.familyName),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(t.save),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) {
      return;
    }
    try {
      await ref.read(membersControllerProvider.notifier).renameFamily(name);
      await ref.read(authControllerProvider.notifier).refreshUser();
    } catch (e) {
      if (context.mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
      }
    }
  }

  Future<void> _leave(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
  ) async {
    final ok = await _confirm(context, t, t.leaveFamily, t.leaveFamilyConfirm);
    if (!ok || !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(authControllerProvider.notifier).leaveFamily();
      ref.read(walletScopeProvider.notifier).state = WalletScope.personal;
      router.go('/');
    } catch (e) {
      if (context.mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
  ) async {
    final ok =
        await _confirm(context, t, t.deleteFamily, t.deleteFamilyConfirm);
    if (!ok || !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(authControllerProvider.notifier).deleteFamily();
      ref.read(walletScopeProvider.notifier).state = WalletScope.personal;
      router.go('/');
    } catch (e) {
      if (context.mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
      }
    }
  }

  Future<bool> _confirm(
    BuildContext context,
    AppLocalizations t,
    String title,
    String message,
  ) async {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowButtonSpacing: 8,
        icon: Icon(Icons.warning_amber_rounded, color: cs.error, size: 32),
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(title),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}
