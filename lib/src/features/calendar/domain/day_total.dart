/// One calendar day's income/expense totals, in the chosen display currency.
/// Mirrors an item of `GET /stats/calendar`.
class DayTotal {
  const DayTotal({
    required this.date,
    required this.income,
    required this.expense,
  });

  final DateTime date;
  final int income;
  final int expense;

  int get net => income - expense;

  factory DayTotal.fromJson(Map<String, dynamic> json) {
    final DateTime d = DateTime.parse(json['day'] as String);
    return DayTotal(
      date: DateTime(d.year, d.month, d.day),
      income: (json['income'] ?? 0) as int,
      expense: (json['expense'] ?? 0) as int,
    );
  }
}
