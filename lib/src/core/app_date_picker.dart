import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// A date picker that matches the rest of the app instead of the platform
/// `showDatePicker` dialog. It wraps Material's [CalendarDatePicker] in an
/// [AlertDialog] whose action row follows the app convention — the primary
/// action ("Save") on the left, "Cancel" on the right, styled like every other
/// dialog — so the calendar's buttons are consistent everywhere.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final AppLocalizations t = AppLocalizations.of(context);
  DateTime selected = initialDate;
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => AlertDialog(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: 320,
        child: CalendarDatePicker(
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          onDateChanged: (d) => selected = d,
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx, selected),
          child: Text(t.save),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.cancel),
        ),
      ],
    ),
  );
}
