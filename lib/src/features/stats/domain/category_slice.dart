import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../categories/domain/category.dart';

/// One slice of the by-category chart: a category's total over the window
/// (integer đồng). [categoryRid] is null for the uncategorized bucket.
class CategorySlice {
  const CategorySlice({
    required this.amount,
    this.categoryRid,
    this.name,
    this.icon,
    this.color,
    this.defaultKey,
  });

  final int amount;
  final String? categoryRid;
  final String? name;
  final String? icon;
  final String? color;

  /// Seeded-default key, or `"uncategorized"` for the catch-all bucket.
  final String? defaultKey;

  bool get isUncategorized => categoryRid == null;

  /// Localized display name: the seeded label, the custom [name], or the
  /// "no category" label for the uncategorized bucket.
  String label(AppLocalizations t) {
    if (defaultKey == 'uncategorized') {
      return t.noCategory;
    }
    return defaultCategoryLabel(t, defaultKey) ?? name ?? t.noCategory;
  }

  /// Parsed [color] (AARRGGBB), falling back to [fallback] when unset/invalid.
  Color colorOr(Color fallback) {
    final String? hex = color;
    if (hex == null || hex.isEmpty) {
      return fallback;
    }
    final int? value = int.tryParse(hex, radix: 16);
    return value == null ? fallback : Color(value);
  }

  factory CategorySlice.fromJson(Map<String, dynamic> json) {
    return CategorySlice(
      amount: (json['amount'] ?? 0) as int,
      categoryRid: json['category_rid'] as String?,
      name: json['name'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      defaultKey: json['default_key'] as String?,
    );
  }
}
