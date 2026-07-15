import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/confirm.dart';
import '../../../core/error_text.dart';
import '../../../core/app_error_view.dart';
import '../../../core/app_picker.dart';
import '../../../core/item_actions.dart';
import '../../../core/money.dart';
import '../../../core/prefs.dart';
import '../../../core/responsive.dart';
import '../../categories/application/categories_controller.dart';
import '../../categories/domain/category.dart';
import '../../wallets/presentation/scope_toggle.dart';
import '../application/budgets_controller.dart';
import '../domain/budget.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final budgets = ref.watch(budgetsControllerProvider);
    // Budget limits/spend follow the chosen display currency.
    final String currency = ref.watch(displayCurrencyControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.budgets)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addBudget(context, ref, t),
        icon: const Icon(Icons.add),
        label: Text(t.addBudget),
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: ScopeToggle(),
            ),
            Expanded(
              child: budgets.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => AppErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(budgetsControllerProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Text(t.noBudgetsYet, textAlign: TextAlign.center),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _BudgetCard(
                      budget: list[i],
                      currency: currency,
                      onEdit: () => _editBudget(context, ref, t, list[i]),
                      onDelete: () => _deleteBudget(context, ref, t, list[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addBudget(
      BuildContext context, WidgetRef ref, AppLocalizations t) async {
    final messenger = ScaffoldMessenger.of(context);
    final budgeted = (ref.read(budgetsControllerProvider).value ?? [])
        .map((b) => b.category.rid)
        .toSet();
    // Categories load asynchronously â€” wait for them so we don't mistake a
    // not-yet-loaded list for "no categories available".
    final List<Category> all;
    try {
      all = await ref.read(categoriesControllerProvider.future);
    } catch (e) {
      if (context.mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    final List<Category> options = all
        .where((c) =>
            c.kind == 'expense' && !c.isArchived && !budgeted.contains(c.rid))
        .toList();
    if (options.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(t.noCategoryForBudget)));
      return;
    }
    final String currency = ref.read(displayCurrencyControllerProvider);
    String? categoryRid = options.first.rid;
    final amount = TextEditingController();

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          actionsOverflowButtonSpacing: 8,
          title: Text(t.addBudget),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppPicker<String>(
                label: t.category,
                value: categoryRid ?? '',
                options: [
                  for (final c in options)
                    PickerOption(
                        value: c.rid, label: c.label(t), emoji: c.icon),
                ],
                onChanged: (v) => setLocal(() => categoryRid = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                inputFormatters: Money.inputFormattersFor(currency),
                decoration: InputDecoration(
                  labelText: t.monthlyLimit,
                  suffixText: Money.symbolFor(currency),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true), child: Text(t.save)),
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.cancel)),
          ],
        ),
      ),
    );
    if (ok != true || categoryRid == null) {
      return;
    }
    final int? value = Money.parseIn(amount.text, currency);
    if (value == null || value <= 0) {
      messenger.showSnackBar(SnackBar(content: Text(t.enterAmountGtZero)));
      return;
    }
    try {
      await ref
          .read(budgetsControllerProvider.notifier)
          .create(categoryRid: categoryRid!, amount: value);
    } catch (e) {
      if (context.mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
      }
    }
  }

  Future<void> _editBudget(
      BuildContext context, WidgetRef ref, AppLocalizations t, Budget b) async {
    final String currency = ref.read(displayCurrencyControllerProvider);
    final amount =
        TextEditingController(text: Money.editText(b.amount, currency));
    final messenger = ScaffoldMessenger.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowButtonSpacing: 8,
        title: Text(b.category.label(t)),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          inputFormatters: Money.inputFormattersFor(currency),
          decoration: InputDecoration(
            labelText: t.monthlyLimit,
            suffixText: Money.symbolFor(currency),
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(t.save)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel)),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    final int? value = Money.parseIn(amount.text, currency);
    if (value == null || value <= 0) {
      messenger.showSnackBar(SnackBar(content: Text(t.enterAmountGtZero)));
      return;
    }
    try {
      await ref
          .read(budgetsControllerProvider.notifier)
          .edit(rid: b.rid, amount: value);
    } catch (e) {
      if (context.mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
      }
    }
  }

  Future<void> _deleteBudget(
      BuildContext context, WidgetRef ref, AppLocalizations t, Budget b) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDelete(
      context,
      title: t.deleteBudget,
      message: t.deleteBudgetConfirm,
    );
    if (!ok) {
      return;
    }
    await ref.read(budgetsControllerProvider.notifier).remove(b.rid);
    messenger.showSnackBar(SnackBar(content: Text(t.budgetDeleted)));
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  final Budget budget;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color barColor = budget.isOver ? cs.error : cs.primary;
    final String emoji = budget.category.icon ?? '';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onEdit,
        onLongPress: () => showItemActions(context, [
          ItemAction(
            icon: Icons.edit_outlined,
            label: t.edit,
            onTap: onEdit,
          ),
          ItemAction(
            icon: Icons.delete_outline,
            label: t.delete,
            destructive: true,
            onTap: onDelete,
          ),
        ]),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (emoji.isNotEmpty) ...[
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      budget.category.label(t),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: budget.progress,
                  minHeight: 10,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: barColor,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${Money.formatIn(budget.spent, currency)} / ${Money.formatIn(budget.amount, currency)}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                  Text(
                    budget.isOver
                        ? t.overBudgetBy(
                            Money.formatIn(-budget.remaining, currency))
                        : t.remainingAmount(
                            Money.formatIn(budget.remaining, currency)),
                    style: TextStyle(
                      color: budget.isOver ? cs.error : cs.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
}
