import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../members/application/members_controller.dart';
import '../../stats/data/stats_repository.dart';
import '../../transactions/application/transactions_controller.dart';
import '../../wallets/application/wallets_controller.dart';
import '../application/inbox_controller.dart';
import '../domain/invitation.dart';

/// The invited (existing) account's inbox: pending in-app invites to accept/decline.
class InvitationsInboxScreen extends ConsumerWidget {
  const InvitationsInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final inbox = ref.watch(inboxControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.invitations)),
      body: inbox.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                t.noInvitations,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _InviteCard(
              invite: list[i],
              onAccept: () => _accept(context, ref, t, list[i]),
              onDecline: () => _decline(context, ref, t, list[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    InboxInvitation invite,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(inboxControllerProvider.notifier).accept(invite.rid);
      // The active family changed — drop cached family-scoped data.
      ref.invalidate(dashboardControllerProvider);
      ref.invalidate(walletsControllerProvider);
      ref.invalidate(transactionsControllerProvider);
      ref.invalidate(monthlyStatsProvider);
      ref.invalidate(membersControllerProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(t.joinedFamily(invite.familyName))),
      );
      router.go('/');
    } on ApiException catch (e) {
      final String msg =
          e.statusCode == 409 ? t.ownerMustTransferToJoin : e.message;
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _decline(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    InboxInvitation invite,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(inboxControllerProvider.notifier).decline(invite.rid);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.invite,
    required this.onAccept,
    required this.onDecline,
  });

  final InboxInvitation invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mail_outline, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.invitedYouToJoin(invite.invitedBy, invite.familyName),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onDecline, child: Text(t.decline)),
                const SizedBox(width: 8),
                FilledButton(onPressed: onAccept, child: Text(t.accept)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
