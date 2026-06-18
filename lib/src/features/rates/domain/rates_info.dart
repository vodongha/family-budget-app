/// Mirrors `GET /rates` — status of the stored exchange rates.
class RatesInfo {
  const RatesInfo({
    required this.baseCurrency,
    required this.updatedAt,
    required this.count,
  });

  final String baseCurrency;

  /// When the rates were last refreshed (local time), or null if never.
  final DateTime? updatedAt;
  final int count;

  factory RatesInfo.fromJson(Map<String, dynamic> json) {
    final String? ts = json['updated_at'] as String?;
    return RatesInfo(
      baseCurrency: (json['base_currency'] ?? 'VND') as String,
      updatedAt: ts == null ? null : _parseUtc(ts),
      count: (json['count'] ?? 0) as int,
    );
  }

  /// The backend stores a naive UTC timestamp; interpret it as UTC (not local)
  /// and convert to the device's local time for display.
  static DateTime _parseUtc(String ts) {
    final bool hasTz =
        ts.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(ts);
    return (hasTz ? DateTime.parse(ts) : DateTime.parse('${ts}Z')).toLocal();
  }
}
