import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/error_text.dart';
import '../../../core/money.dart';
import '../../auth/application/auth_controller.dart';
import '../application/wallets_controller.dart';
import '../domain/wallet.dart';

/// Preset wallet colours (hex). Kept short so the swatch row stays tidy.
const List<String> kWalletColors = <String>[
  '#5B5BF0',
  '#06B6D4',
  '#22C55E',
  '#F59E0B',
  '#EF4444',
  '#EC4899',
  '#A855F7',
  '#64748B',
];

/// Create or edit a wallet (name, optional icon emoji, optional colour).
/// When [existing] is null it creates (with a shared/private choice, defaulting
/// to [initialPersonal]); otherwise it edits that wallet (visibility is fixed).
Future<void> showWalletEditSheet(
  BuildContext context,
  WidgetRef ref, {
  Wallet? existing,
  bool initialPersonal = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _WalletEditSheet(existing: existing, initialPersonal: initialPersonal),
  );
}

class _WalletEditSheet extends ConsumerStatefulWidget {
  const _WalletEditSheet({this.existing, this.initialPersonal = false});

  final Wallet? existing;
  final bool initialPersonal;

  @override
  ConsumerState<_WalletEditSheet> createState() => _WalletEditSheetState();
}

class _WalletEditSheetState extends ConsumerState<_WalletEditSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _icon =
      TextEditingController(text: widget.existing?.icon ?? '');
  late String? _color = widget.existing?.color;
  late bool _personal = widget.existing?.isPersonal ?? widget.initialPersonal;
  late String _currency = widget.existing?.currency ?? Money.baseCurrency;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _icon.dispose();
    super.dispose();
  }

  Future<void> _save(AppLocalizations t) async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final String icon = _icon.text.trim();
    try {
      final notifier = ref.read(walletsControllerProvider.notifier);
      if (_isEdit) {
        await notifier.edit(
          widget.existing!.rid,
          name: name,
          icon: icon, // empty string clears it
          color: _color,
        );
      } else {
        // No family â†’ only a personal wallet is possible.
        final bool hasFamily =
            ref.read(authControllerProvider).value?.hasFamily ?? false;
        final bool personal = _personal || !hasFamily;
        await notifier.create(
          name,
          visibility: personal ? 'personal' : 'family',
          icon: icon.isEmpty ? null : icon,
          color: _color,
          currency: _currency,
        );
      }
      navigator.pop();
    } catch (e) {
      if (mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    // Without a family there's no "shared" option â€” only personal wallets.
    final bool hasFamily =
        ref.watch(authControllerProvider).value?.hasFamily ?? false;
    final bool showVisibility = !_isEdit && hasFamily;
    // Scrollable so the Save button is always reachable even when the sheet is
    // taller than the viewport (e.g. a short window on web). Width-capped and
    // centred so it isn't a giant strip on wide screens.
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // stretch â†’ children (incl. the action Row) get a tight full width,
              // so the Expanded "Save" button fills instead of collapsing.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEdit ? t.editWallet : t.newWallet,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  autofocus: !_isEdit,
                  decoration: InputDecoration(labelText: t.walletName),
                ),
                const SizedBox(height: 12),
                // Currency is chosen at creation and fixed afterwards (changing it
                // would reinterpret the wallet's stored amounts).
                if (!_isEdit)
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: InputDecoration(labelText: t.currency),
                    items: [
                      for (final String c in Money.supportedCurrencies)
                        DropdownMenuItem<String>(
                          value: c,
                          child: Text('$c  ·  ${Money.symbolFor(c)}'),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _currency = v ?? _currency),
                  )
                else
                  InputDecorator(
                    decoration: InputDecoration(labelText: t.currency),
                    child: Text('$_currency  ·  ${Money.symbolFor(_currency)}'),
                  ),
                const SizedBox(height: 12),
                if (showVisibility)
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(t.sharedWallet),
                        icon: const Icon(Icons.people_outline),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(t.privateWallet),
                        icon: const Icon(Icons.lock_outline),
                      ),
                    ],
                    selected: {_personal},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _personal = s.first),
                  ),
                if (showVisibility) const SizedBox(height: 12),
                TextField(
                  controller: _icon,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: t.iconOptional,
                    hintText: '💵',
                  ),
                ),
                const SizedBox(height: 4),
                Text(t.colorOptional,
                    style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final hex in kWalletColors)
                      _ColorDot(
                        hex: hex,
                        selected: _color == hex,
                        onTap: () => setState(
                          () => _color = _color == hex ? null : hex,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // Full-width stacked buttons. Using SizedBox(infinity) instead of
                // a Row+Expanded guarantees the button can't collapse to ~0 width
                // (which made the "LÆ°u" label wrap vertically) regardless of the
                // parent's width constraints.
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : () => _save(t),
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEdit ? t.save : t.create),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(t.cancel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int value = int.parse('FF${hex.replaceAll('#', '')}', radix: 16);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: Color(value),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? cs.onSurface : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
