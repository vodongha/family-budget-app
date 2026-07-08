import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/app_date_picker.dart';
import '../../../core/app_error_view.dart';
import '../../../core/app_picker.dart';
import '../../../core/confirm.dart';
import '../../../core/error_text.dart';
import '../../../core/item_actions.dart';
import '../../../core/money.dart';
import '../../../core/responsive.dart';
import '../../categories/application/categories_controller.dart';
import '../../categories/domain/category.dart';
import '../../wallets/application/wallet_scope.dart';
import '../application/transactions_controller.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';

/// The transactions list, grouped by day (bank-app style) and loaded a month at
/// a time: it starts with the current month and loads older months as you scroll
/// to the bottom, so the server never returns the whole history at once. A date
/// range filter switches to a single bounded query (no month pagination).
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  // Don't page back past this; also bounds empty-month scanning at history's end.
  static final DateTime _floor = DateTime(2020, 1);
  static const int _maxEmptyMonths = 12;

  final ScrollController _scroll = ScrollController();
  final List<Transaction> _items = [];
  late DateTime _nextMonth; // the next (older) month to fetch
  bool _loading = false;
  bool _hasMore = true;
  bool _rangeMode = false;
  Object? _error;
  TxnFilter _loadedFilter = emptyTxnFilter;
  String _loadedScope = 'all';

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final String scope = ref.read(walletScopeProvider).api;
    final TxnFilter f = ref.read(txnFilterProvider);
    final DateTime now = DateTime.now();
    setState(() {
      _items.clear();
      _error = null;
      _hasMore = true;
      _loadedFilter = f;
      _loadedScope = scope;
      _rangeMode = f.from != null || f.to != null;
      _nextMonth = DateTime(now.year, now.month);
    });
    await _loadMore(initial: true);
  }

  Future<void> _loadMore({bool initial = false}) async {
    if (_loading || (!_hasMore && !initial)) {
      return;
    }
    setState(() => _loading = true);
    final TransactionRepository repo = ref.read(transactionRepositoryProvider);
    final String scope = _loadedScope;
    final TxnFilter f = _loadedFilter;
    try {
      if (_rangeMode) {
        final List<Transaction> list = await repo.list(
          scope: scope,
          walletRid: f.walletRid,
          type: f.type,
          categoryRid: f.categoryRid,
          dateFrom: f.from,
          dateTo: f.to,
          limit: 500,
        );
        if (!mounted) return;
        setState(() {
          _items.addAll(list);
          _hasMore = false;
          _loading = false;
        });
        return;
      }
      // Walk back month by month until we collect some rows (or hit the floor /
      // a run of empty months), so each "load more" yields visible content.
      final List<Transaction> batch = [];
      DateTime cursor = _nextMonth;
      int empty = 0;
      bool reachedEnd = false;
      while (batch.isEmpty) {
        if (cursor.isBefore(_floor)) {
          reachedEnd = true;
          break;
        }
        final DateTime from = DateTime(cursor.year, cursor.month);
        final DateTime to = DateTime(cursor.year, cursor.month + 1, 0);
        final List<Transaction> monthList = await repo.list(
          scope: scope,
          walletRid: f.walletRid,
          type: f.type,
          categoryRid: f.categoryRid,
          dateFrom: from,
          dateTo: to,
          limit: 500,
        );
        cursor = DateTime(cursor.year, cursor.month - 1);
        if (monthList.isNotEmpty) {
          batch.addAll(monthList);
          break;
        }
        empty++;
        if (empty >= _maxEmptyMonths) {
          reachedEnd = true;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _items.addAll(batch);
        _nextMonth = cursor;
        if (reachedEnd || cursor.isBefore(_floor)) {
          _hasMore = false;
        }
        _loading = false;
      });
      _autoFill();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Keep loading older months until the list is long enough to scroll (or the
  /// history runs out). Without this, a sparse current month — e.g. right after
  /// a new month begins — leaves too little content to scroll, so the
  /// scroll-triggered pagination never fires and older months stay hidden.
  void _autoFill() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loading || !_hasMore || _rangeMode) {
        return;
      }
      if (_scroll.hasClients && _scroll.position.maxScrollExtent <= 0) {
        _loadMore();
      }
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _deleteTxn(String rid) async {
    final t = AppLocalizations.of(context);
    final ok = await confirmDelete(
      context,
      title: t.deleteTransaction,
      message: t.deleteTransactionConfirm,
    );
    if (!ok) {
      return;
    }
    try {
      await ref.read(transactionsControllerProvider.notifier).remove(rid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
      }
    }
    await _reload();
  }

  /// Net (income − expense, transfers excluded) per day, for the day headers.
  /// ``currency`` is the day's single currency, or null when the day mixes
  /// currencies (we can't sum across currencies client-side without rates, so the
  /// header then omits the amount).
  Map<DateTime, ({int net, String? currency})> _dayNet() {
    final Map<DateTime, int> net = {};
    final Map<DateTime, String?> currency = {};
    final Set<DateTime> mixed = {};
    for (final Transaction tx in _items) {
      if (tx.type.isTransfer) continue;
      final DateTime d = _dayOnly(tx.occurredOn);
      net[d] = (net[d] ?? 0) + tx.signedAmount;
      if (!currency.containsKey(d)) {
        currency[d] = tx.currency;
      } else if (currency[d] != tx.currency) {
        mixed.add(d);
      }
    }
    return {
      for (final DateTime d in net.keys)
        d: (net: net[d]!, currency: mixed.contains(d) ? null : currency[d]),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final bool filterActive = ref.watch(txnFilterProvider) != emptyTxnFilter;
    final bool showCreator =
        ref.watch(walletScopeProvider) == WalletScope.family;
    // Reload when the filter or the personal/family scope changes.
    ref.listen(txnFilterProvider, (_, __) => _reload());
    ref.listen(walletScopeProvider, (_, __) => _reload());

    // Flatten the items into [date header, txn, txn, date header, ...] rows.
    final Map<DateTime, ({int net, String? currency})> dayNet = _dayNet();
    final List<Object> rows = [];
    DateTime? lastDay;
    for (final Transaction tx in _items) {
      final DateTime d = _dayOnly(tx.occurredOn);
      if (lastDay == null || d != lastDay) {
        rows.add(d);
        lastDay = d;
      }
      rows.add(tx);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.transactions),
        actions: [
          IconButton(
            tooltip: t.filter,
            icon: Icon(
                filterActive ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => const _FilterSheet(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/transactions/new');
          await _reload();
        },
        child: const Icon(Icons.add),
      ),
      body: ResponsiveCenter(
        child: _buildBody(t, rows, dayNet, showCreator, filterActive),
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations t,
    List<Object> rows,
    Map<DateTime, ({int net, String? currency})> dayNet,
    bool showCreator,
    bool filterActive,
  ) {
    if (_items.isEmpty) {
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_error != null) {
        return AppErrorView(error: _error!, onRetry: _reload);
      }
      return Center(
        child: Text(filterActive ? t.noMatches : t.noTransactionsYet),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        controller: _scroll,
        itemCount: rows.length + 1, // +1 footer (loader / end)
        itemBuilder: (context, i) {
          if (i == rows.length) {
            if (_loading) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return const SizedBox(height: 24);
          }
          final Object row = rows[i];
          if (row is DateTime) {
            final info = dayNet[row];
            return _DateHeader(
              day: row,
              net: info?.net ?? 0,
              currency: info?.currency,
            );
          }
          final Transaction tx = row as Transaction;
          return _TransactionTile(
            txn: tx,
            showCreator: showCreator,
            onEdit: tx.canEdit && !tx.type.isTransfer
                ? () async {
                    await context.push('/transactions/edit', extra: tx);
                    await _reload();
                  }
                : null,
            onDelete: tx.canEdit && !tx.type.isTransfer
                ? () => _deleteTxn(tx.rid)
                : null,
          );
        },
      ),
    );
  }
}

/// A day separator with the day's net amount, like a bank statement. The amount
/// is shown only when the day has a single currency ([currency] non-null); a
/// mixed-currency day shows just the date (we can't sum across currencies here).
class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.day, required this.net, this.currency});
  final DateTime day;
  final int net;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String locale = Localizations.localeOf(context).toString();
    final String label = DateFormat('EEEE, d MMMM y', locale).format(day);
    final Color netColor = net >= 0 ? Colors.green : Colors.red;
    return Container(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          if (net != 0 && currency != null)
            Text(
              '${net >= 0 ? '+' : '−'}${Money.formatIn(net.abs(), currency!)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: netColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.txn,
    this.showCreator = false,
    this.onEdit,
    this.onDelete,
  });
  final Transaction txn;
  final bool showCreator;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool transfer = txn.type.isTransfer;
    final bool inflow = txn.type.isInflow;
    final Color color =
        transfer ? cs.onSurfaceVariant : (inflow ? Colors.green : Colors.red);
    final String sign = inflow ? '+' : '−';
    final String? categoryName = txn.category?.label(t);

    final String? note =
        (txn.note != null && txn.note!.isNotEmpty) ? txn.note : null;
    // The date lives in the day header; the subtitle carries the category (or,
    // for a transfer, its in/out label) and — in family scope — who created it.
    final List<String> subtitleParts = [];
    final String title;
    if (transfer) {
      final String transferLabel =
          txn.type == TransactionType.transferIn ? t.transferIn : t.transferOut;
      // Surface the note as the title so a transfer's purpose is visible, and
      // keep the in/out label in the subtitle. No note → the label is the title.
      title = note ?? transferLabel;
      if (note != null) {
        subtitleParts.add(transferLabel);
      }
    } else {
      title = note ?? (categoryName ?? (inflow ? t.income : t.expense));
      if (categoryName != null) {
        subtitleParts.add(categoryName);
      }
    }
    if (showCreator &&
        txn.createdBy != null &&
        txn.createdBy!.displayName.isNotEmpty) {
      subtitleParts.add(txn.createdBy!.displayName);
    }
    final String subtitle = subtitleParts.join(' · ');

    final String? emoji = transfer ? null : txn.category?.icon;
    final Widget leading = (emoji != null && emoji.isNotEmpty)
        ? Container(
            height: 44,
            width: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: txn.category!.colorOr(color).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          )
        : Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              transfer
                  ? Icons.swap_horiz
                  : (inflow
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded),
              color: color,
            ),
          );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: leading,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Text(
        '$sign${Money.formatIn(txn.amount, txn.currency)}',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
      // Transfers are managed via wallets; only the creator can edit a txn.
      onTap: onEdit,
      // Long-press surfaces edit/delete (B6).
      onLongPress: (onEdit == null && onDelete == null)
          ? null
          : () => showItemActions(context, [
                if (onEdit != null)
                  ItemAction(
                    icon: Icons.edit_outlined,
                    label: t.edit,
                    onTap: onEdit!,
                  ),
                if (onDelete != null)
                  ItemAction(
                    icon: Icons.delete_outline,
                    label: t.delete,
                    destructive: true,
                    onTap: onDelete!,
                  ),
              ]),
    );
  }
}

/// Bottom sheet to filter the transaction list by type, category and date range.
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late TransactionType? _type;
  late String? _categoryRid;
  late DateTime? _from;
  late DateTime? _to;

  @override
  void initState() {
    super.initState();
    final TxnFilter f = ref.read(txnFilterProvider);
    _type = f.type;
    _categoryRid = f.categoryRid;
    _from = f.from;
    _to = f.to;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<DateTime?> _pick(DateTime? initial) => showAppDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final List<Category> cats =
        ref.watch(categoriesControllerProvider).valueOrNull ?? [];
    // Keep a stale category selection from breaking the dropdown.
    if (_categoryRid != null && !cats.any((c) => c.rid == _categoryRid)) {
      _categoryRid = null;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.filter,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SegmentedButton<TransactionType?>(
              segments: [
                ButtonSegment(value: null, label: Text(t.all)),
                ButtonSegment(
                    value: TransactionType.expense, label: Text(t.expense)),
                ButtonSegment(
                    value: TransactionType.income, label: Text(t.income)),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            AppPicker<String?>(
              label: t.categoryOptional,
              value: _categoryRid,
              options: [
                PickerOption<String?>(value: null, label: t.all),
                for (final c in cats)
                  PickerOption<String?>(
                      value: c.rid, label: c.label(t), emoji: c.icon),
              ],
              onChanged: (v) => setState(() => _categoryRid = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.from),
                    subtitle: Text(_from == null ? '—' : _fmt(_from!)),
                    onTap: () async {
                      final d = await _pick(_from);
                      if (d != null) setState(() => _from = d);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.to),
                    subtitle: Text(_to == null ? '—' : _fmt(_to!)),
                    onTap: () async {
                      final d = await _pick(_to);
                      if (d != null) setState(() => _to = d);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Primary action (Apply) on the left, secondary (Clear) on the
            // right — consistent with the app's other dialogs.
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      ref.read(txnFilterProvider.notifier).state = (
                        type: _type,
                        categoryRid: _categoryRid,
                        // Preserve a wallet filter set by tapping a wallet tile.
                        walletRid: ref.read(txnFilterProvider).walletRid,
                        from: _from,
                        to: _to,
                      );
                      Navigator.pop(context);
                    },
                    child: Text(t.apply),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(txnFilterProvider.notifier).state =
                          emptyTxnFilter;
                      Navigator.pop(context);
                    },
                    child: Text(t.clear),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
