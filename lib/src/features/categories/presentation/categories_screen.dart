import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/error_text.dart';
import '../../../core/app_error_view.dart';
import '../../../core/item_actions.dart';
import '../../../core/responsive.dart';
import '../../wallets/presentation/scope_toggle.dart';
import '../application/categories_controller.dart';
import '../domain/category.dart';

/// Manage categories (personal / family): list (grouped by kind), add, edit,
/// delete. Follows the personal/family scope toggle.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final cats = ref.watch(categoriesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.categories)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref, t),
        icon: const Icon(Icons.add),
        label: Text(t.addCategory),
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: ScopeToggle(),
            ),
            Expanded(
              child: cats.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => AppErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(categoriesControllerProvider),
                ),
                data: (list) {
                  final expense = list.where((c) => c.isExpense).toList();
                  final income = list.where((c) => !c.isExpense).toList();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                    children: [
                      _SectionHeader(label: t.expense),
                      ...expense.map((c) => _CategoryTile(category: c)),
                      const SizedBox(height: 12),
                      _SectionHeader(label: t.income),
                      ...income.map((c) => _CategoryTile(category: c)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
  ) async {
    final name = TextEditingController();
    final icon = TextEditingController();
    String kind = 'expense';
    final messenger = ScaffoldMessenger.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          actionsOverflowButtonSpacing: 8,
          title: Text(t.addCategory),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'expense', label: Text(t.expense)),
                  ButtonSegment(value: 'income', label: Text(t.income)),
                ],
                selected: {kind},
                onSelectionChanged: (s) => setState(() => kind = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                autofocus: true,
                decoration: InputDecoration(labelText: t.categoryName),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: icon,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: t.iconOptional,
                  hintText: '🍜',
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.create),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel),
            ),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) {
      return;
    }
    try {
      await ref.read(categoriesControllerProvider.notifier).create(
            name: name.text.trim(),
            kind: kind,
            icon: icon.text.trim().isEmpty ? null : icon.text.trim(),
          );
    } catch (e) {
      if (context.mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        height: 40,
        width: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: category.colorOr(cs.primary).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            Text(category.icon ?? '🏷️', style: const TextStyle(fontSize: 18)),
      ),
      title: Text(category.label(t)),
      onLongPress: () => showItemActions(context, [
        ItemAction(
          icon: Icons.edit_outlined,
          label: t.editCategory,
          onTap: () => _editDialog(context, ref, t),
        ),
        ItemAction(
          icon: Icons.delete_outline,
          label: t.delete,
          destructive: true,
          onTap: () => _deleteDialog(context, ref, t),
        ),
      ]),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
        onSelected: (v) {
          if (v == 'edit') {
            _editDialog(context, ref, t);
          } else if (v == 'delete') {
            _deleteDialog(context, ref, t);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'edit', child: Text(t.editCategory)),
          PopupMenuItem(
            value: 'delete',
            child: Text(t.delete, style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _editDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
  ) async {
    final name = TextEditingController(text: category.label(t));
    final icon = TextEditingController(text: category.icon ?? '🏷️');
    final messenger = ScaffoldMessenger.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowButtonSpacing: 8,
        title: Text(t.editCategory),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(labelText: t.categoryName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: icon,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: t.iconOptional,
                hintText: '🍜',
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.save),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) {
      return;
    }
    try {
      await ref.read(categoriesControllerProvider.notifier).edit(
            category.rid,
            name: name.text.trim(),
            icon: icon.text.trim().isEmpty ? null : icon.text.trim(),
          );
    } catch (e) {
      if (context.mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
      }
    }
  }

  Future<void> _deleteDialog(
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
        title: Text(t.deleteCategory),
        content: Text(t.deleteCategoryConfirm(category.label(t))),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete),
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
      await ref
          .read(categoriesControllerProvider.notifier)
          .delete(category.rid);
    } catch (e) {
      if (context.mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
      }
    }
  }
}
