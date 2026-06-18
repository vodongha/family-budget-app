import '../../../core/money.dart';

/// Mirrors `GET /rates` — status of the stored exchange rates plus every rate,
/// so the client can convert any pair (the currency converter tool).
class RatesInfo {
  const RatesInfo({
    required this.baseCurrency,
    required this.updatedAt,
    required this.count,
    required this.rateToBase,
  });

  final String baseCurrency;

  /// When the rates were last refreshed (local time), or null if never.
  final DateTime? updatedAt;
  final int count;

  /// `currency -> base-currency major units per 1 major unit of it` (e.g.
  /// `USD -> 25000`). The base currency is implicitly rate 1 and not in the map.
  final Map<String, double> rateToBase;

  factory RatesInfo.fromJson(Map<String, dynamic> json) {
    final String? ts = json['updated_at'] as String?;
    final Map<String, double> rates = {
      for (final dynamic r in (json['rates'] ?? []) as List)
        (r as Map)['currency'] as String:
            ((r)['rate_to_base'] as num).toDouble(),
    };
    return RatesInfo(
      baseCurrency: (json['base_currency'] ?? 'VND') as String,
      updatedAt: ts == null ? null : _parseUtc(ts),
      count: (json['count'] ?? 0) as int,
      rateToBase: rates,
    );
  }

  /// Base-major units per 1 major unit of [code] (base currency → 1). Null when
  /// the currency has no stored rate.
  double? _rate(String code) => code == baseCurrency ? 1.0 : rateToBase[code];

  /// Convert [minorFrom] (minor units of [from]) into minor units of [to] using
  /// the stored rates, via the base currency. Null if either rate is missing.
  /// Mirrors the backend's integer conversion (round once on the target).
  int? convertMinor(int minorFrom, String from, String to) {
    if (from == to) {
      return minorFrom;
    }
    final double? rf = _rate(from);
    final double? rt = _rate(to);
    if (rf == null || rt == null) {
      return null;
    }
    final double majorFrom = minorFrom / _pow10(Money.decimalsFor(from));
    final double base = majorFrom * rf; // value in base major units
    final double majorTo = base / rt;
    return (majorTo * _pow10(Money.decimalsFor(to))).round();
  }

  static int _pow10(int n) {
    int r = 1;
    for (int i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  /// The backend stores a naive UTC timestamp; interpret it as UTC (not local)
  /// and convert to the device's local time for display.
  static DateTime _parseUtc(String ts) {
    final bool hasTz =
        ts.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(ts);
    return (hasTz ? DateTime.parse(ts) : DateTime.parse('${ts}Z')).toLocal();
  }
}
