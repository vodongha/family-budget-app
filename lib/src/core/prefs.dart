import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'money.dart';

/// Provides the SharedPreferences instance. Overridden in main() after it has
/// been loaded, so the rest of the app can read it synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
      'sharedPreferencesProvider must be overridden in main()');
});

/// Holds the user's chosen UI language. ``null`` means "follow the device".
/// Persisted so the choice survives restarts.
class LocaleController extends Notifier<Locale?> {
  static const String _key = 'locale_code';

  @override
  Locale? build() {
    final String? code = ref.read(sharedPreferencesProvider).getString(_key);
    return code == null ? null : Locale(code);
  }

  Future<void> setLocale(Locale? locale) async {
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
    state = locale;
  }
}

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

/// Holds the light/dark/system theme preference, persisted across restarts.
/// Defaults to [ThemeMode.system].
class ThemeController extends Notifier<ThemeMode> {
  static const String _key = 'theme_mode';

  @override
  ThemeMode build() {
    final String? name = ref.read(sharedPreferencesProvider).getString(_key);
    return ThemeMode.values
        .firstWhere((m) => m.name == name, orElse: () => ThemeMode.system);
  }

  Future<void> setMode(ThemeMode mode) async {
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
    state = mode;
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

/// Holds the currency that cross-wallet **totals** are displayed in (dashboard,
/// stats, budgets). Per-wallet balances always stay in their own currency.
/// Persisted; defaults to the base currency (VND). Conversion happens on the
/// backend via the stored exchange rate — the app just sends this code.
class DisplayCurrencyController extends Notifier<String> {
  static const String _key = 'display_currency';

  @override
  String build() {
    final String? code = ref.read(sharedPreferencesProvider).getString(_key);
    return (code != null && Money.supportedCurrencies.contains(code))
        ? code
        : Money.baseCurrency;
  }

  Future<void> setCurrency(String code) async {
    await ref.read(sharedPreferencesProvider).setString(_key, code);
    state = code;
  }
}

final displayCurrencyControllerProvider =
    NotifierProvider<DisplayCurrencyController, String>(
        DisplayCurrencyController.new);
