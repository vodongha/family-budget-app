import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// The app's standard destructive-confirm dialog. Used for **every** delete so
/// they look identical: a warning icon, the red confirm button **on top**, and
/// Cancel **below it**, stacked with the app's standard 8px button spacing
/// (full-width actions force the vertical layout regardless of label length).
///
/// Returns `true` only when the user confirms.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
}) async {
  final t = AppLocalizations.of(context);
  final cs = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: cs.error, size: 32),
      title: Text(title),
      content: Text(message),
      actionsOverflowButtonSpacing: 8,
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel ?? t.delete),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}
