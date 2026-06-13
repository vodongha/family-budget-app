import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// A family-scoped transaction category. Seeded defaults carry a [defaultKey]
/// so the UI can show a localized name; custom ones use [name] verbatim.
class Category {
  const Category({
    required this.rid,
    required this.name,
    required this.kind,
    this.icon,
    this.color,
    this.defaultKey,
    this.isArchived = false,
  });

  final String rid;
  final String name;

  /// `expense` or `income`.
  final String kind;

  /// Emoji icon (rendered as text), or null.
  final String? icon;

  /// Hex colour `AARRGGBB`, or null.
  final String? color;

  /// Non-null for seeded defaults — drives the localized label.
  final String? defaultKey;
  final bool isArchived;

  bool get isExpense => kind == 'expense';

  /// The localized display name: a localized label for seeded defaults,
  /// otherwise the stored [name].
  String label(AppLocalizations t) => _defaultLabel(t, defaultKey) ?? name;

  /// Parsed [color], falling back to [fallback] when unset/invalid.
  Color colorOr(Color fallback) {
    final String? hex = color;
    if (hex == null || hex.isEmpty) {
      return fallback;
    }
    final int? value = int.tryParse(hex, radix: 16);
    return value == null ? fallback : Color(value);
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      rid: json['rid'] as String,
      name: (json['name'] ?? '') as String,
      kind: (json['kind'] ?? 'expense') as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      defaultKey: json['default_key'] as String?,
      isArchived: (json['is_archived'] ?? false) as bool,
    );
  }
}

/// Maps a seeded category's [defaultKey] to its localized name (null if custom).
String? _defaultLabel(AppLocalizations t, String? key) {
  switch (key) {
    case 'food':
      return t.categoryFood;
    case 'transport':
      return t.categoryTransport;
    case 'shopping':
      return t.categoryShopping;
    case 'bills':
      return t.categoryBills;
    case 'housing':
      return t.categoryHousing;
    case 'health':
      return t.categoryHealth;
    case 'entertainment':
      return t.categoryEntertainment;
    case 'education':
      return t.categoryEducation;
    case 'otherExpense':
    case 'otherIncome':
      return t.categoryOther;
    case 'salary':
      return t.categorySalary;
    case 'bonus':
      return t.categoryBonus;
    default:
      return null;
  }
}
