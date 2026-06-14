import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../family/presentation/create_family_dialog.dart';
import '../application/wallet_scope.dart';

/// Switches the viewing scope between the user's **personal** (private) spending
/// and the shared **family** spending. Personal is on the left, family on the
/// right. Backs the shared [walletScopeProvider], so the dashboard, transactions
/// and statistics all follow the same selection.
///
/// Tapping **Family** with no family yet opens the create-family dialog instead
/// of switching; the switch only happens once a family exists.
class ScopeToggle extends ConsumerWidget {
  const ScopeToggle({super.key});

  Future<void> _onChanged(
    BuildContext context,
    WidgetRef ref,
    WalletScope next,
  ) async {
    if (next == WalletScope.family) {
      final bool hasFamily =
          ref.read(authControllerProvider).valueOrNull?.hasFamily ?? false;
      if (!hasFamily) {
        final bool created = await showCreateFamilyDialog(context, ref);
        if (!created) {
          return; // stay on personal
        }
      }
    }
    ref.read(walletScopeProvider.notifier).state = next;
  }

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
        onSelectionChanged: (s) => _onChanged(context, ref, s.first),
      ),
    );
  }
}
