import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/money.dart';
import '../../categories/application/categories_controller.dart';
import '../../categories/domain/category.dart';
import '../application/transactions_controller.dart';
import '../domain/transaction.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final AsyncValue<List<Transaction>> txns =
        ref.watch(transactionsControllerProvider);
    final bool filterActive = ref.watch(txnFilterProvider) != emptyTxnFilter;

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
        onPressed: () => context.push('/transactions/new'),
        child: const Icon(Icons.add),
      ),
      body: txns.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () =>
                      ref.invalidate(transactionsControllerProvider),
                  child: Text(t.retry),
                ),
              ],
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(filterActive ? t.noMatches : t.noTransactionsYet),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(transactionsControllerProvider);
              await ref.read(transactionsControllerProvider.future);
            },
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _TransactionTile(txn: list[i]),
            ),
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.txn});
  final Transaction txn;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool transfer = txn.type.isTransfer;
    final bool inflow = txn.type.isInflow;
    final Color color =
        transfer ? cs.onSurfaceVariant : (inflow ? Colors.green : Colors.red);
    final String sign = inflow ? '+' : '−';
    final String date =
        '${txn.occurredOn.year}-${txn.occurredOn.month.toString().padLeft(2, '0')}-${txn.occurredOn.day.toString().padLeft(2, '0')}';
    final String? categoryName = txn.category?.label(t);

    final String title;
    if (transfer) {
      title =
          txn.type == TransactionType.transferIn ? t.transferIn : t.transferOut;
    } else {
      title = (txn.note == null || txn.note!.isEmpty)
          ? (categoryName ?? (inflow ? t.income : t.expense))
          : txn.note!;
    }
    final String subtitle =
        (!transfer && categoryName != null) ? '$date · $categoryName' : date;

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
      subtitle: Text(subtitle),
      trailing: Text(
        '$sign${Money.format(txn.amount)}',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
      // Transfers are managed via wallets; only normal transactions are editable.
      onTap: transfer
          ? null
          : () => context.push('/transactions/edit', extra: txn),
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

  Future<DateTime?> _pick(DateTime? initial) => showDatePicker(
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
            DropdownButtonFormField<String?>(
              initialValue: _categoryRid,
              isExpanded: true,
              decoration: InputDecoration(labelText: t.categoryOptional),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(t.all)),
                ...cats.map((c) => DropdownMenuItem<String?>(
                      value: c.rid,
                      child: Text('${c.icon ?? ''} ${c.label(t)}'.trim()),
                    )),
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
            Row(
              children: [
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
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      ref.read(txnFilterProvider.notifier).state = (
                        type: _type,
                        categoryRid: _categoryRid,
                        from: _from,
                        to: _to,
                      );
                      Navigator.pop(context);
                    },
                    child: Text(t.apply),
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
