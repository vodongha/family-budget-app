/// One month of aggregated totals (integer đồng).
class MonthlyPoint {
  const MonthlyPoint({
    required this.month,
    required this.income,
    required this.expense,
  });

  /// "YYYY-MM".
  final String month;
  final int income;
  final int expense;

  /// "MM" — short label for chart axes.
  String get shortLabel => month.length >= 7 ? month.substring(5, 7) : month;

  factory MonthlyPoint.fromJson(Map<String, dynamic> json) {
    return MonthlyPoint(
      month: json['month'] as String,
      income: (json['income'] ?? 0) as int,
      expense: (json['expense'] ?? 0) as int,
    );
  }
}
