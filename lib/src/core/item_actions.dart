import 'package:flutter/material.dart';

/// One row in the long-press action sheet.
class ItemAction {
  const ItemAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Renders in the error colour (for Delete and similar).
  final bool destructive;
}

/// Shows a bottom sheet of edit/delete (and similar) actions for a list item.
///
/// Wired to `onLongPress` on the app's list tiles so every screen offers the
/// same long-press-to-edit/delete gesture. The chosen action runs after the
/// sheet closes.
Future<void> showItemActions(BuildContext context, List<ItemAction> actions) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in actions)
            ListTile(
              leading: Icon(
                a.icon,
                color: a.destructive ? cs.error : cs.onSurfaceVariant,
              ),
              title: Text(
                a.label,
                style: a.destructive ? TextStyle(color: cs.error) : null,
              ),
              onTap: () {
                Navigator.pop(ctx);
                a.onTap();
              },
            ),
        ],
      ),
    ),
  );
}
