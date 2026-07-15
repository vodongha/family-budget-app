import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/config.dart';
import '../../../core/confirm.dart';
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
    final AuthUser? user = ref.watch(authControllerProvider).value;
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
                if (user.hasFamily)
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
              icon: Icons.settings_outlined,
              label: t.settings,
              onTap: () {
                Navigator.pop(context);
                parentContext.push('/settings');
              },
            ),
            // Family management lives in the hub now, not here.
            // Privacy policy sits below Settings; shown in-app via a WebView that
            // loads the bilingual page served by the backend.
            _MenuTile(
              icon: Icons.privacy_tip_outlined,
              label: t.privacyPolicy,
              onTap: () {
                Navigator.pop(context);
                parentContext.push('/privacy');
              },
            ),
            // Community & support forum: in-app WebView on mobile; on web open a
            // new tab (an external site can't be iframed reliably).
            _MenuTile(
              icon: Icons.forum_outlined,
              label: t.community,
              onTap: () {
                Navigator.pop(context);
                if (kIsWeb) {
                  launchUrl(
                    Uri.parse(AppConfig.communityUrl),
                    webOnlyWindowName: '_blank',
                  );
                } else {
                  parentContext.push('/community');
                }
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
    final bool ok = await confirmDelete(
      context,
      title: t.deleteAccount,
      message: t.deleteAccountWarning,
      confirmLabel: t.deleteAccountConfirm,
    );
    if (!ok) {
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
