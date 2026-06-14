import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/avatar.dart';
import '../application/members_controller.dart';
import '../domain/family_member.dart';

/// Shows the family's members. The owner can transfer ownership to a member.
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final members = ref.watch(membersControllerProvider);
    final bool amOwner =
        ref.watch(authControllerProvider).valueOrNull?.isOwner ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(t.members)),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(membersControllerProvider),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(membersControllerProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, i) => _MemberTile(
              member: list[i],
              canTransfer: amOwner && !list[i].isOwner,
              onTransfer: () => _confirmTransfer(context, ref, t, list[i]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmTransfer(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    FamilyMember member,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.up,
        title: Text(t.transferOwnership),
        content: Text(t.transferOwnershipConfirm(member.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.makeOwner),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      await ref
          .read(membersControllerProvider.notifier)
          .transferOwnership(member.rid);
      messenger.showSnackBar(SnackBar(content: Text(t.ownershipTransferred)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canTransfer,
    required this.onTransfer,
  });

  final FamilyMember member;
  final bool canTransfer;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: UserAvatar(name: member.displayName, radius: 22),
      title: Text(member.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(member.phone ?? member.email),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RolePill(label: member.isOwner ? t.roleOwner : t.roleMember),
          if (canTransfer)
            IconButton(
              tooltip: t.transferOwnership,
              icon: Icon(Icons.shield_outlined, color: cs.primary),
              onPressed: onTransfer,
            ),
        ],
      ),
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(t.retry)),
        ],
      ),
    );
  }
}
