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

/// The currently selected scope. Defaults to the shared family view; the
/// dashboard toggle flips it, and family-scoped read providers watch it.
final walletScopeProvider = StateProvider<WalletScope>(
  (ref) => WalletScope.family,
);
