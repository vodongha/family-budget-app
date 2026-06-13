import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/money.dart';
import '../application/transactions_controller.dart';
import '../domain/transaction.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final AsyncValue<List<Transaction>> txns =
        ref.watch(transactionsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.transactions)),
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
            return Center(child: Text(t.noTransactionsYet));
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
    final bool income = txn.type.isIncome;
    final Color color = income ? Colors.green : Colors.red;
    final String sign = income ? '+' : '−';
    final String date =
        '${txn.occurredOn.year}-${txn.occurredOn.month.toString().padLeft(2, '0')}-${txn.occurredOn.day.toString().padLeft(2, '0')}';
    final String? categoryName = txn.category?.label(t);
    final String title = (txn.note == null || txn.note!.isEmpty)
        ? (categoryName ?? (income ? t.income : t.expense))
        : txn.note!;
    final String subtitle =
        categoryName == null ? date : '$date · $categoryName';

    final String? emoji = txn.category?.icon;
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
              income
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
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
    );
  }
}
