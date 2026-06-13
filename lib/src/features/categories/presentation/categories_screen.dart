import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../application/categories_controller.dart';
import '../domain/category.dart';

/// Manage the family's categories: list (grouped by kind), add, rename, delete.
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
      body: cats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
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
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.create),
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
      messenger.showSnackBar(SnackBar(content: Text('$e')));
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
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
        onSelected: (v) {
          if (v == 'rename') {
            _renameDialog(context, ref, t);
          } else if (v == 'delete') {
            _deleteDialog(context, ref, t);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'rename', child: Text(t.rename)),
          PopupMenuItem(
            value: 'delete',
            child: Text(t.delete, style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _renameDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
  ) async {
    final controller = TextEditingController(text: category.label(t));
    final messenger = ScaffoldMessenger.of(context);
    final String? name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.rename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: t.categoryName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(t.save),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) {
      return;
    }
    try {
      await ref
          .read(categoriesControllerProvider.notifier)
          .rename(category.rid, name);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
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
        title: Text(t.deleteCategory),
        content: Text(t.deleteCategoryConfirm(category.label(t))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete),
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
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
