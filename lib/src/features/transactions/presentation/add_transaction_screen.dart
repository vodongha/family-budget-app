import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/money.dart';
import '../../categories/application/categories_controller.dart';
import '../../categories/domain/category.dart';
import '../../wallets/application/wallets_controller.dart';
import '../../wallets/domain/wallet.dart';
import '../application/transactions_controller.dart';
import '../domain/transaction.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

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

  Future<void> _createWallet(AppLocalizations t) async {
    final TextEditingController name = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.newWallet),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: InputDecoration(labelText: t.walletName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, name.text.trim()),
            child: Text(t.create),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ref.read(walletsControllerProvider.notifier).create(result);
    }
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
      await ref.read(transactionsControllerProvider.notifier).add(
            walletRid: _walletRid!,
            type: _type,
            amount: amount,
            note: _note.text.trim(),
            categoryRid: _categoryRid,
            occurredOn: _date,
          );
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
      appBar: AppBar(title: Text(t.addTransaction)),
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
              data: (list) => Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _walletRid ??
                          (list.isNotEmpty ? list.first.rid : null),
                      decoration: InputDecoration(labelText: t.wallet),
                      items: list
                          .map((w) => DropdownMenuItem(
                                value: w.rid,
                                child: Text(w.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _walletRid = v),
                    ),
                  ),
                  IconButton(
                    tooltip: t.newWallet,
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _createWallet(t),
                  ),
                ],
              ),
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
    return DropdownButtonFormField<String?>(
      initialValue: selectedRid,
      isExpanded: true,
      decoration: InputDecoration(labelText: t.categoryOptional),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(t.noCategory)),
        ...cats.map(
          (c) => DropdownMenuItem<String?>(
            value: c.rid,
            child: Text('${c.icon ?? ''} ${c.label(t)}'.trim()),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
