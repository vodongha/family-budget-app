import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/app_picker.dart';
import '../../../core/money.dart';
import '../../categories/application/categories_controller.dart';
import '../../categories/domain/category.dart';
import '../../wallets/application/wallet_scope.dart';
import '../../wallets/application/wallets_controller.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/wallet_edit_sheet.dart';
import '../application/transactions_controller.dart';
import '../domain/transaction.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.existing});

  /// When set, the screen edits this transaction instead of creating a new one.
  final Transaction? existing;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _walletRid;
  String? _categoryRid;
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final Transaction? e = widget.existing;
    if (e != null) {
      _type =
          e.type.isIncome ? TransactionType.income : TransactionType.expense;
      _amount.text = Money.group(e.amount);
      _note.text = e.note ?? '';
      _walletRid = e.walletRid;
      _categoryRid = e.category?.rid;
      _date = e.occurredOn;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _createWallet() {
    // Default the new wallet to the slice you're currently adding to, so a
    // wallet created from the family tab is shared and one from the personal
    // tab is private.
    showWalletEditSheet(
      context,
      ref,
      initialPersonal: ref.read(walletScopeProvider) == WalletScope.personal,
    );
  }

  Future<void> _submit(AppLocalizations t) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_walletRid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.pickWalletFirst)));
      return;
    }
    final int? amount = Money.parse(_amount.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.enterAmountGtZero)));
      return;
    }

    setState(() => _saving = true);
    try {
      final notifier = ref.read(transactionsControllerProvider.notifier);
      if (_isEdit) {
        await notifier.edit(
          rid: widget.existing!.rid,
          walletRid: _walletRid!,
          type: _type,
          amount: amount,
          note: _note.text.trim(),
          categoryRid: _categoryRid,
          occurredOn: _date,
        );
      } else {
        await notifier.add(
          walletRid: _walletRid!,
          type: _type,
          amount: amount,
          note: _note.text.trim(),
          categoryRid: _categoryRid,
          occurredOn: _date,
        );
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmDelete(AppLocalizations t) async {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowButtonSpacing: 8,
        icon: Icon(Icons.warning_amber_rounded, color: cs.error, size: 32),
        title: Text(t.deleteTransaction),
        content: Text(t.deleteTransactionConfirm),
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
    setState(() => _saving = true);
    try {
      await ref
          .read(transactionsControllerProvider.notifier)
          .remove(widget.existing!.rid);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final AsyncValue<List<Wallet>> wallets =
        ref.watch(walletsControllerProvider);

    // Drop a stale selection if it no longer matches the current kind.
    final List<Category> kindCats =
        ref.watch(categoriesByKindProvider(_type.api));
    if (_categoryRid != null && !kindCats.any((c) => c.rid == _categoryRid)) {
      _categoryRid = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? t.editTransaction : t.addTransaction),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: t.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : () => _confirmDelete(t),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<TransactionType>(
              segments: [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text(t.expense),
                  icon: const Icon(Icons.north_east),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text(t.income),
                  icon: const Icon(Icons.south_west),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                // Categories are kind-specific — reset when switching.
                _categoryRid = null;
              }),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: InputDecoration(
                labelText: t.amountLabel,
                hintText: t.amountHint,
              ),
              validator: (v) {
                final int? a = Money.parse(v ?? '');
                return (a == null || a <= 0) ? t.enterAmountGtZero : null;
              },
            ),
            const SizedBox(height: 16),
            wallets.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (allWallets) {
                // Only offer wallets that belong to the slice being added to:
                // family (shared) on the family tab, personal (private) on the
                // personal tab — so a transaction can't land in the wrong scope.
                final WalletScope scope = ref.watch(walletScopeProvider);
                final List<Wallet> list = allWallets
                    .where((w) => scope == WalletScope.personal
                        ? w.isPersonal
                        : !w.isPersonal)
                    .toList();
                // When editing, keep the transaction's own wallet selectable
                // even if it belongs to the other scope.
                if (_isEdit &&
                    _walletRid != null &&
                    !list.any((w) => w.rid == _walletRid)) {
                  list.addAll(allWallets.where((w) => w.rid == _walletRid));
                }
                // Default to the first in-scope wallet; re-default if the prior
                // choice is no longer valid for this scope.
                if (_walletRid == null ||
                    !list.any((w) => w.rid == _walletRid)) {
                  _walletRid = list.isNotEmpty ? list.first.rid : null;
                }
                return Row(
                  children: [
                    Expanded(
                      child: AppPicker<String>(
                        label: t.wallet,
                        value: _walletRid ?? '',
                        options: [
                          for (final w in list)
                            PickerOption(
                              value: w.rid,
                              label: w.name,
                              icon: w.isPersonal ? Icons.lock_outline : null,
                            ),
                        ],
                        onChanged: (v) => setState(() => _walletRid = v),
                      ),
                    ),
                    IconButton(
                      tooltip: t.newWallet,
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _createWallet,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _CategoryPicker(
              kind: _type.api,
              selectedRid: _categoryRid,
              onChanged: (rid) => setState(() => _categoryRid = rid),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              decoration: InputDecoration(labelText: t.noteOptional),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(t.date),
              trailing: Text(
                '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : () => _submit(t),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.save),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dropdown of the family's categories for the given [kind], plus a
/// "no category" option. Reports the selected category rid (or null).
class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({
    required this.kind,
    required this.selectedRid,
    required this.onChanged,
  });

  final String kind;
  final String? selectedRid;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final List<Category> cats = ref.watch(categoriesByKindProvider(kind));
    return AppPicker<String?>(
      label: t.categoryOptional,
      value: selectedRid,
      options: [
        PickerOption<String?>(value: null, label: t.noCategory),
        for (final c in cats)
          PickerOption<String?>(value: c.rid, label: c.label(t), emoji: c.icon),
      ],
      onChanged: onChanged,
    );
  }
}
