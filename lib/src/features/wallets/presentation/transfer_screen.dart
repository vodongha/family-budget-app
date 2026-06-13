import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/money.dart';
import '../../transactions/application/transactions_controller.dart';
import '../application/wallets_controller.dart';
import '../domain/wallet.dart';

/// Move money between two of the family's wallets.
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _fromRid;
  String? _toRid;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations t, List<Wallet> wallets) async {
    final messenger = ScaffoldMessenger.of(context);
    final String? from = _fromRid ?? (wallets.isNotEmpty ? wallets.first.rid : null);
    final String? to = _toRid;
    if (from == null || to == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.pickWalletFirst)));
      return;
    }
    if (from == to) {
      messenger.showSnackBar(SnackBar(content: Text(t.transferSameWallet)));
      return;
    }
    final int? amount = Money.parse(_amount.text);
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(SnackBar(content: Text(t.enterAmountGtZero)));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(transactionsControllerProvider.notifier).transfer(
            fromWalletRid: from,
            toWalletRid: to,
            amount: amount,
            note: _note.text.trim(),
            occurredOn: _date,
          );
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(t.transferDone)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
        setState(() => _saving = false);
      }
    }
  }

  List<DropdownMenuItem<String>> _items(List<Wallet> wallets) {
    return wallets
        .map((w) => DropdownMenuItem(
              value: w.rid,
              child: Row(
                children: [
                  if (w.isPersonal) ...[
                    const Icon(Icons.lock_outline, size: 16),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(w.name, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final AsyncValue<List<Wallet>> wallets =
        ref.watch(walletsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.transferMoney)),
      body: wallets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.length < 2) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.transferNeedsTwoWallets,
                    textAlign: TextAlign.center),
              ),
            );
          }
          _fromRid ??= list.first.rid;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _fromRid,
                decoration: InputDecoration(labelText: t.fromWallet),
                items: _items(list),
                onChanged: (v) => setState(() => _fromRid = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _toRid,
                decoration: InputDecoration(labelText: t.toWallet),
                items: _items(list),
                onChanged: (v) => setState(() => _toRid = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t.amountLabel,
                  hintText: t.amountHint,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
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
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _date = picked);
                  }
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : () => _submit(t, list),
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.swap_horiz),
                label: Text(t.transferMoney),
              ),
            ],
          );
        },
      ),
    );
  }
}
