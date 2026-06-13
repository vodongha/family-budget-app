import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/api_client.dart';
import '../application/auth_controller.dart';
import '../domain/auth_user.dart';
import 'avatar.dart';

/// Opens the modern account menu: edit profile, settings, delete account, sign out.
Future<void> showAccountSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => _AccountSheet(parentContext: context),
  );
}

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet({required this.parentContext});

  /// The screen context (outlives the sheet) used for navigation and snackbars.
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AuthUser? user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Identity header.
            Row(
              children: [
                UserAvatar(name: user.displayName, radius: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _RolePill(label: user.isOwner ? t.roleOwner : t.roleMember),
              ],
            ),
            const SizedBox(height: 20),
            _MenuTile(
              icon: Icons.person_outline,
              label: t.editProfile,
              onTap: () {
                Navigator.pop(context);
                parentContext.push('/profile');
              },
            ),
            _MenuTile(
              icon: Icons.people_outline,
              label: t.members,
              onTap: () {
                Navigator.pop(context);
                parentContext.push('/members');
              },
            ),
            _MenuTile(
              icon: Icons.mail_outline,
              label: t.invitations,
              onTap: () {
                Navigator.pop(context);
                parentContext.push('/invitations');
              },
            ),
            if (user.isOwner)
              _MenuTile(
                icon: Icons.group_add_outlined,
                label: t.addMember,
                onTap: () {
                  Navigator.pop(context);
                  parentContext.push('/members/add');
                },
              ),
            _MenuTile(
              icon: Icons.category_outlined,
              label: t.categories,
              onTap: () {
                Navigator.pop(context);
                parentContext.push('/categories');
              },
            ),
            _MenuTile(
              icon: Icons.settings_outlined,
              label: t.settings,
              onTap: () {
                Navigator.pop(context);
                parentContext.push('/settings');
              },
            ),
            _MenuTile(
              icon: Icons.logout,
              label: t.signOut,
              onTap: () {
                Navigator.pop(context);
                ref.read(authControllerProvider.notifier).logout();
              },
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.delete_outline,
              label: t.deleteAccount,
              danger: true,
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(parentContext, ref, t);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(authControllerProvider.notifier);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: cs.error, size: 32),
        title: Text(t.deleteAccount),
        content: Text(t.deleteAccountWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
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
      messenger.showSnackBar(SnackBar(content: Text(t.accountDeleted)));
    } on ApiException catch (e) {
      final String msg = e.statusCode == 409 ? t.ownerMustTransfer : e.message;
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color color = danger ? cs.error : cs.onSurface;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, color: danger ? cs.error : cs.primary),
      title: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      trailing:
          danger ? null : Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onSecondaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
