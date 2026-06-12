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
    final String title = (txn.note == null || txn.note!.isEmpty)
        ? (income ? t.income : t.expense)
        : txn.note!;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(
          income ? Icons.south_west : Icons.north_east,
          color: color,
        ),
      ),
      title: Text(title),
      subtitle: Text(
        '${txn.occurredOn.year}-${txn.occurredOn.month.toString().padLeft(2, '0')}-${txn.occurredOn.day.toString().padLeft(2, '0')}',
      ),
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
