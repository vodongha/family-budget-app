import '../../categories/domain/category.dart';

/// A monthly spending limit for a category, with how much is spent this month.
class Budget {
  const Budget({
    required this.rid,
    required this.category,
    required this.amount,
    required this.spent,
  });

  final String rid;
  final Category category;

  /// Monthly limit and current-month spend, both integer đồng.
  final int amount;
  final int spent;

  double get progress =>
      amount <= 0 ? 0 : (spent / amount).clamp(0.0, 1.0).toDouble();
  bool get isOver => spent > amount;
  int get remaining => amount - spent;

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      rid: json['rid'] as String,
      category:
          Category.fromJson((json['category'] as Map).cast<String, dynamic>()),
      amount: (json['amount'] ?? 0) as int,
      spent: (json['spent'] ?? 0) as int,
    );
  }
}
