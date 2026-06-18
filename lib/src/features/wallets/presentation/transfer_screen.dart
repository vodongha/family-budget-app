import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/app_date_picker.dart';
import '../../../core/error_text.dart';
import '../../../core/app_picker.dart';
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
    final String? from =
        _fromRid ?? (wallets.isNotEmpty ? wallets.first.rid : null);
    final String? to = _toRid;
    if (from == null || to == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.pickWalletFirst)));
      return;
    }
    if (from == to) {
      messenger.showSnackBar(SnackBar(content: Text(t.transferSameWallet)));
      return;
    }
    final int? amount = Money.parseIn(_amount.text, _currencyOf(wallets, from));
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
        messenger
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
        setState(() => _saving = false);
      }
    }
  }

  String _currencyOf(List<Wallet> wallets, String? rid) {
    for (final Wallet w in wallets) {
      if (w.rid == rid) {
        return w.currency;
      }
    }
    return Money.baseCurrency;
  }

  List<PickerOption<String>> _options(
    List<Wallet> wallets, {
    String? onlyCurrency,
  }) {
    return [
      for (final w in wallets)
        if (onlyCurrency == null || w.currency == onlyCurrency)
          PickerOption(
            value: w.rid,
            label: '${w.name} · ${w.currency}',
            icon: w.isPersonal ? Icons.lock_outline : null,
          ),
    ];
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
        error: (e, _) => Center(child: Text(friendlyError(context, e))),
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
          final String fromCurrency = _currencyOf(list, _fromRid);
          // A transfer is same-currency only — drop a destination whose currency
          // no longer matches the source.
          if (_toRid != null && _currencyOf(list, _toRid) != fromCurrency) {
            _toRid = null;
          }
          final bool decimalAmount = Money.decimalsFor(fromCurrency) > 0;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppPicker<String>(
                label: t.fromWallet,
                value: _fromRid ?? '',
                options: _options(list),
                onChanged: (v) => setState(() => _fromRid = v),
              ),
              const SizedBox(height: 16),
              AppPicker<String>(
                label: t.toWallet,
                value: _toRid ?? '',
                // Only wallets sharing the source currency (cross-currency
                // transfers aren't supported).
                options: _options(list, onlyCurrency: fromCurrency),
                onChanged: (v) => setState(() => _toRid = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                keyboardType:
                    TextInputType.numberWithOptions(decimal: decimalAmount),
                inputFormatters: decimalAmount
                    ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
                    : [ThousandsSeparatorInputFormatter()],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t.amountLabel,
                  hintText: t.amountHint,
                  suffixText: Money.symbolFor(fromCurrency),
                  helperText: () {
                    final int? a = Money.parseIn(_amount.text, fromCurrency);
                    return (a == null || a == 0)
                        ? null
                        : Money.formatIn(a, fromCurrency);
                  }(),
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
                  final DateTime? picked = await showAppDatePicker(
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
