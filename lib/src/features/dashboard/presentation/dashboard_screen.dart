import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/money.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/account_menu.dart';
import '../../auth/presentation/avatar.dart';
import '../../wallets/application/wallets_controller.dart';
import '../../wallets/presentation/scope_toggle.dart';
import '../../wallets/domain/wallet.dart';
import '../application/dashboard_controller.dart';
import '../domain/dashboard_summary.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AsyncValue<DashboardSummary> summary =
        ref.watch(dashboardControllerProvider);
    final String name =
        ref.watch(authControllerProvider).valueOrNull?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              t.overview,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              name.isEmpty ? t.dashboard : t.greeting(name),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: '$e',
          retryLabel: t.retry,
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
                      tooltip: t.transactions,
                      icon: const Icon(Icons.receipt_long_outlined),
                      onPressed: () => context.push('/transactions'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              if (s.wallets.isEmpty)
                _EmptyWallets(label: t.noWalletsYet)
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
    final bool isOwner =
        ref.watch(authControllerProvider).valueOrNull?.isOwner ?? false;
    final List<_HubItem> items = [
      _HubItem(Icons.receipt_long_outlined, t.transactions, '/transactions'),
      _HubItem(Icons.bar_chart_outlined, t.statistics, '/stats'),
      _HubItem(Icons.calendar_month_outlined, t.calendar, '/calendar'),
      _HubItem(Icons.pie_chart_outline, t.budgets, '/budgets'),
      _HubItem(Icons.swap_horiz, t.transferMoney, '/transfers/new'),
      _HubItem(Icons.category_outlined, t.categories, '/categories'),
      _HubItem(Icons.people_outline, t.members, '/members'),
      _HubItem(Icons.mail_outline, t.invitations, '/invitations'),
      if (isOwner)
        _HubItem(Icons.group_add_outlined, t.addMember, '/members/add'),
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
  const _HubItem(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;
}

class _HubCell extends StatelessWidget {
  const _HubCell({required this.item});
  final _HubItem item;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(item.route),
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
  });

  final String netLabel;
  final int net;
  final String incomeLabel;
  final int income;
  final String expenseLabel;
  final int expense;

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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroStat(
                  icon: Icons.arrow_upward_rounded,
                  label: expenseLabel,
                  amount: expense,
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
  });

  final IconData icon;
  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.onPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
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
    // so they may delete it; a shared family wallet only by the family owner.
    final bool canDelete = isOwner || wallet.isPersonal;
    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, canDelete ? 4 : 16, 14),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                wallet.isPersonal
                    ? Icons.lock_outline
                    : Icons.account_balance_wallet_outlined,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                wallet.name,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              Money.format(wallet.balance),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            if (canDelete)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                onSelected: (_) => _confirmDelete(context, ref, t),
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: cs.error, size: 20),
                        const SizedBox(width: 10),
                        Text(t.deleteWallet, style: TextStyle(color: cs.error)),
                      ],
                    ),
                  ),
                ],
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: cs.error, size: 32),
        title: Text(t.deleteWallet),
        content: Text(t.deleteWalletConfirm(wallet.name, wallet.txnCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.deleteWallet),
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
  const _EmptyWallets({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 40, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
