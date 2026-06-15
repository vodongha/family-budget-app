import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/app_error_view.dart';
import '../../../core/money.dart';
import '../../../core/responsive.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/account_menu.dart';
import '../../auth/presentation/avatar.dart';
import '../../family/presentation/create_family_dialog.dart';
import '../../transactions/application/transactions_controller.dart';
import '../../transactions/domain/transaction.dart';
import '../../wallets/application/wallet_scope.dart';
import '../../wallets/application/wallets_controller.dart';
import '../../wallets/presentation/scope_toggle.dart';
import '../../wallets/presentation/wallet_edit_sheet.dart';
import '../../wallets/domain/wallet.dart';
import '../application/dashboard_controller.dart';
import '../domain/dashboard_summary.dart';

/// Sets the transaction filter and opens the Transactions screen — used by the
/// dashboard's income/expense pills and wallet tiles for contextual drill-down.
void _openFilteredTransactions(
  BuildContext context,
  WidgetRef ref, {
  TransactionType? type,
  String? walletRid,
}) {
  ref.read(txnFilterProvider.notifier).state = (
    type: type,
    categoryRid: null,
    walletRid: walletRid,
    from: null,
    to: null,
  );
  context.push('/transactions');
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final AsyncValue<DashboardSummary> summary =
        ref.watch(dashboardControllerProvider);
    final String name =
        ref.watch(authControllerProvider).valueOrNull?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        toolbarHeight: 72,
        title: Text(
          name.isEmpty ? t.dashboard : t.greeting(name),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => showAccountSheet(context, ref),
              child: UserAvatar(name: name.isEmpty ? '?' : name, radius: 20),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/transactions/new'),
        icon: const Icon(Icons.add),
        label: Text(t.add),
      ),
      body: ResponsiveCenter(
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorView(
            error: e,
            onRetry: () =>
                ref.read(dashboardControllerProvider.notifier).refresh(),
          ),
          data: (s) => RefreshIndicator(
            onRefresh: () =>
                ref.read(dashboardControllerProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              children: [
                const ScopeToggle(),
                const SizedBox(height: 20),
                _BalanceHero(
                  netLabel: t.netBalance,
                  net: s.netBalance,
                  incomeLabel: t.income,
                  income: s.totalIncome,
                  expenseLabel: t.expense,
                  expense: s.totalExpense,
                  onIncomeTap: () => _openFilteredTransactions(
                    context,
                    ref,
                    type: TransactionType.income,
                  ),
                  onExpenseTap: () => _openFilteredTransactions(
                    context,
                    ref,
                    type: TransactionType.expense,
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.walletsWithCount(s.walletCount),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        tooltip: t.newWallet,
                        icon: const Icon(Icons.add_circle_outline),
                        // Defaults the new wallet to the current scope (a
                        // personal wallet on the Personal tab, a shared one on
                        // the Family tab). Transactions live in the hub already.
                        onPressed: () => showWalletEditSheet(
                          context,
                          ref,
                          initialPersonal: ref.read(walletScopeProvider) ==
                              WalletScope.personal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                if (s.wallets.isEmpty)
                  _EmptyWallets(
                    label: t.noWalletsYet,
                    addLabel: t.newWallet,
                    onAdd: () => showWalletEditSheet(
                      context,
                      ref,
                      initialPersonal:
                          ref.read(walletScopeProvider) == WalletScope.personal,
                    ),
                  )
                else
                  ...s.wallets.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _WalletTile(wallet: w),
                      )),
                const SizedBox(height: 16),
                const _HubPager(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A grid of feature shortcuts on the dashboard (replaces the crowded account
/// sheet). Owner-only entries (add member) are gated.
class _HubPager extends ConsumerStatefulWidget {
  const _HubPager();

  @override
  ConsumerState<_HubPager> createState() => _HubPagerState();
}

class _HubPagerState extends ConsumerState<_HubPager> {
  final PageController _controller = PageController();
  int _page = 0;

  static const int _perPage = 8; // 4 columns × 2 rows

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// One page: two rows of four slots; empty slots keep the grid aligned.
  Widget _buildPage(List<_HubItem> items) {
    Widget row(int start) => SizedBox(
          height: 92,
          child: Row(
            children: [
              for (int c = 0; c < 4; c++)
                Expanded(
                  child: start + c < items.length
                      ? _HubCell(item: items[start + c])
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [row(0), const SizedBox(height: 12), row(4)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<_HubItem> items = [
      _HubItem(Icons.receipt_long_outlined, t.transactions, '/transactions'),
      _HubItem(Icons.bar_chart_outlined, t.statistics, '/stats'),
      _HubItem(Icons.calendar_month_outlined, t.calendar, '/calendar'),
      // Budgets and categories follow the personal/family scope (no family
      // required for personal); members is a shared family feature.
      _HubItem(Icons.pie_chart_outline, t.budgets, '/budgets'),
      _HubItem(Icons.swap_horiz, t.transferMoney, '/transfers/new'),
      _HubItem(Icons.category_outlined, t.categories, '/categories'),
      _HubItem(Icons.people_outline, t.members, '/members', familyOnly: true),
      _HubItem(Icons.mail_outline, t.invitations, '/invitations'),
    ];
    final List<List<_HubItem>> pages = [
      for (int i = 0; i < items.length; i += _perPage)
        items.sublist(
            i, i + _perPage > items.length ? items.length : i + _perPage),
    ];

    return Column(
      children: [
        SizedBox(
          height: 196,
          child: PageView.builder(
            controller: _controller,
            itemCount: pages.length,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (_, p) => _buildPage(pages[p]),
          ),
        ),
        if (pages.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < pages.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? cs.primary : cs.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HubItem {
  const _HubItem(this.icon, this.label, this.route, {this.familyOnly = false});
  final IconData icon;
  final String label;
  final String route;

  /// Requires a family (e.g. budgets, categories, members); a family-less user
  /// is prompted to create one instead of navigating into a 403.
  final bool familyOnly;
}

class _HubCell extends ConsumerWidget {
  const _HubCell({required this.item});
  final _HubItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        if (item.familyOnly) {
          final bool hasFamily =
              ref.read(authControllerProvider).valueOrNull?.hasFamily ?? false;
          if (!hasFamily) {
            await showCreateFamilyDialog(context, ref);
            return;
          }
        }
        if (context.mounted) {
          context.push(item.route);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              item.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// The gradient hero: net balance with income/expense split beneath.
class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.netLabel,
    required this.net,
    required this.incomeLabel,
    required this.income,
    required this.expenseLabel,
    required this.expense,
    this.onIncomeTap,
    this.onExpenseTap,
  });

  final String netLabel;
  final int net;
  final String incomeLabel;
  final int income;
  final String expenseLabel;
  final int expense;
  final VoidCallback? onIncomeTap;
  final VoidCallback? onExpenseTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.6)!],
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            netLabel,
            style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 6),
          Text(
            Money.format(net),
            style: TextStyle(
              color: cs.onPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  icon: Icons.arrow_downward_rounded,
                  label: incomeLabel,
                  amount: income,
                  onTap: onIncomeTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroStat(
                  icon: Icons.arrow_upward_rounded,
                  label: expenseLabel,
                  amount: expense,
                  onTap: onExpenseTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.label,
    required this.amount,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(16);
    return Material(
      color: cs.onPrimary.withValues(alpha: 0.15),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: cs.onPrimary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: cs.onPrimary.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      Money.format(amount),
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletTile extends ConsumerWidget {
  const _WalletTile({required this.wallet});
  final Wallet wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isOwner =
        ref.watch(authControllerProvider).valueOrNull?.isOwner ?? false;
    // A personal wallet is private to its owner (who is the only one seeing it),
    // so they may edit/delete it; a shared family wallet by the family owner or
    // the member who created it.
    final bool canManage = isOwner || wallet.isPersonal || wallet.createdByMe;
    final Color accent = wallet.colorOr(cs.primaryContainer);
    final bool hasColor = wallet.color != null && wallet.color!.isNotEmpty;
    final bool hasIcon = wallet.icon != null && wallet.icon!.isNotEmpty;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () =>
            _openFilteredTransactions(context, ref, walletRid: wallet.rid),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 14, canManage ? 4 : 16, 14),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: hasColor
                      ? accent.withValues(alpha: 0.16)
                      : cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: hasIcon
                      ? Text(wallet.icon!, style: const TextStyle(fontSize: 20))
                      : Icon(
                          wallet.isPersonal
                              ? Icons.lock_outline
                              : Icons.account_balance_wallet_outlined,
                          color: hasColor ? accent : cs.onPrimaryContainer,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  wallet.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                Money.format(wallet.balance),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                  onSelected: (v) {
                    if (v == 'edit') {
                      showWalletEditSheet(context, ref, existing: wallet);
                    } else if (v == 'delete') {
                      _confirmDelete(context, ref, t);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              color: cs.onSurfaceVariant, size: 20),
                          const SizedBox(width: 10),
                          Text(t.editWallet),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: cs.error, size: 20),
                          const SizedBox(width: 10),
                          Text(t.deleteWallet,
                              style: TextStyle(color: cs.error)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowButtonSpacing: 8,
        icon: Icon(Icons.warning_amber_rounded, color: cs.error, size: 32),
        title: Text(t.deleteWallet),
        content: Text(t.deleteWalletConfirm(wallet.name, wallet.txnCount)),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.deleteWallet),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      final int removed =
          await ref.read(walletsControllerProvider.notifier).delete(wallet.rid);
      messenger.showSnackBar(
        SnackBar(content: Text(t.walletDeleted(removed))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _EmptyWallets extends StatelessWidget {
  const _EmptyWallets({
    required this.label,
    required this.addLabel,
    required this.onAdd,
  });
  final String label;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 40, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            ),
          ],
        ),
      ),
    );
  }
}
