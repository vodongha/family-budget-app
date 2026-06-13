import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../application/wallet_scope.dart';

/// Switches the viewing scope between the user's **personal** (private) spending
/// and the shared **family** spending. Personal is on the left, family on the
/// right. Backs the shared [walletScopeProvider], so the dashboard, transactions
/// and statistics all follow the same selection.
class ScopeToggle extends ConsumerWidget {
  const ScopeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final WalletScope scope = ref.watch(walletScopeProvider);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<WalletScope>(
        segments: [
          ButtonSegment(
            value: WalletScope.personal,
            label: Text(t.personal),
            icon: const Icon(Icons.lock_outline),
          ),
          ButtonSegment(
            value: WalletScope.family,
            label: Text(t.family),
            icon: const Icon(Icons.people_outline),
          ),
        ],
        selected: {scope},
        showSelectedIcon: false,
        onSelectionChanged: (s) =>
            ref.read(walletScopeProvider.notifier).state = s.first,
      ),
    );
  }
}
