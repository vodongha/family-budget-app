import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which slice of spending the viewing surfaces (dashboard, transactions,
/// stats) show: shared **family** wallets or the user's **personal** (private)
/// wallets. Maps to the backend `?scope=` query parameter.
enum WalletScope {
  family,
  personal;

  /// The API value (`family` / `personal`).
  String get api => name;
}

/// The currently selected scope. Defaults to the **personal** view — a new
/// account has no family yet, and personal works without one; switching to the
/// family tab prompts to create a family if there isn't one.
final walletScopeProvider =
    NotifierProvider<WalletScopeNotifier, WalletScope>(WalletScopeNotifier.new);

class WalletScopeNotifier extends Notifier<WalletScope> {
  @override
  WalletScope build() => WalletScope.personal;

  void set(WalletScope scope) => state = scope;
}
