import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/app_error_view.dart';
import '../../../core/app_picker.dart';
import '../../../core/error_text.dart';
import '../../../core/money.dart';
import '../../../core/prefs.dart';
import '../../../core/responsive.dart';
import '../application/rate_refresh.dart';
import '../data/rates_repository.dart';
import '../domain/rates_info.dart';

/// A simple currency converter: enter an amount, pick "from" and "to"
/// currencies, see the converted value using the stored exchange rates. It only
/// displays — it never touches wallets or transactions.
class CurrencyConverterScreen extends ConsumerStatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  ConsumerState<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState
    extends ConsumerState<CurrencyConverterScreen> {
  final TextEditingController _amount = TextEditingController();
  String? _from;
  String? _to;
  bool _refreshing = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  List<PickerOption<String>> _currencyOptions() => [
        for (final String c in Money.supportedCurrencies)
          PickerOption(value: c, label: Money.currencyLabel(c)),
      ];

  void _swap() {
    setState(() {
      final String? t = _from;
      _from = _to;
      _to = t;
    });
  }

  Future<void> _refresh() async {
    final AppLocalizations t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _refreshing = true);
    try {
      await refreshRates(ref);
      messenger.showSnackBar(SnackBar(content: Text(t.ratesRefreshed)));
    } catch (e) {
      if (mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    // Default: from the current display currency, to the base (or USD if the
    // display currency is already the base).
    _from ??= ref.read(displayCurrencyControllerProvider);
    _to ??= _from == Money.baseCurrency ? 'USD' : Money.baseCurrency;
    final AsyncValue<RatesInfo> info = ref.watch(ratesInfoProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.currencyConverter)),
      body: ResponsiveCenter(
        child: info.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorView(
            error: e,
            onRetry: () => ref.invalidate(ratesInfoProvider),
          ),
          data: (rates) => _body(context, t, rates),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations t, RatesInfo rates) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String from = _from!;
    final String to = _to!;
    final int? amountMinor = Money.parseIn(_amount.text, from);
    final int? resultMinor =
        amountMinor == null ? null : rates.convertMinor(amountMinor, from, to);
    // Rate line. "1 from = X to", but if one unit of `from` rounds to ~0 in `to`
    // (e.g. 1 VND in USD), show the inverse ("1 to = Y from") so it's meaningful.
    String? rateLine;
    final int? fwd =
        rates.convertMinor(_pow10(Money.decimalsFor(from)), from, to);
    if (fwd != null && fwd > 0) {
      rateLine = '1 $from ≈ ${Money.formatIn(fwd, to)}';
    } else {
      final int? inv =
          rates.convertMinor(_pow10(Money.decimalsFor(to)), to, from);
      if (inv != null) {
        rateLine = '1 $to ≈ ${Money.formatIn(inv, from)}';
      }
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _amount,
          // Match the other amount fields: grouped digits for 0-decimal
          // currencies (1.234.567), a decimal point for the rest.
          keyboardType: TextInputType.numberWithOptions(
            decimal: Money.decimalsFor(from) > 0,
          ),
          inputFormatters: Money.inputFormattersFor(from),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: t.amountLabel,
            suffixText: Money.symbolFor(from),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AppPicker<String>(
                label: t.convertFrom,
                value: from,
                searchable: true,
                options: _currencyOptions(),
                onChanged: (v) => setState(() => _from = v),
              ),
            ),
            IconButton(
              tooltip: t.swap,
              icon: const Icon(Icons.swap_horiz),
              onPressed: _swap,
            ),
            Expanded(
              child: AppPicker<String>(
                label: t.convertTo,
                value: to,
                searchable: true,
                options: _currencyOptions(),
                onChanged: (v) => setState(() => _to = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Text(
                  resultMinor == null ? '—' : Money.formatIn(resultMinor, to),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (rateLine != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    rateLine,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                rates.updatedAt == null
                    ? t.ratesNeverUpdated
                    : t.ratesUpdatedAt(
                        DateFormat('d MMM y, HH:mm').format(rates.updatedAt!)),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // A compact icon button (not a wide labelled button) so the date
            // text always keeps its width.
            _refreshing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: t.refreshRates,
                    icon: const Icon(Icons.refresh),
                    onPressed: _refresh,
                  ),
          ],
        ),
      ],
    );
  }

  static int _pow10(int n) {
    int r = 1;
    for (int i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }
}
