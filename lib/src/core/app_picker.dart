import 'package:flutter/material.dart';

/// One selectable option for [AppPicker].
class PickerOption<T> {
  const PickerOption({
    required this.value,
    required this.label,
    this.emoji,
    this.icon,
  });

  final T value;
  final String label;
  final String? emoji;
  final IconData? icon;
}

/// A field that looks like a text input but opens a rounded bottom-sheet list to
/// pick a value — a modern replacement for `DropdownButtonFormField`. Works with
/// nullable `T` (e.g. an optional category).
class AppPicker<T> extends StatelessWidget {
  const AppPicker({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.sheetTitle,
  });

  final String label;
  final T value;
  final List<PickerOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? sheetTitle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    PickerOption<T>? selected;
    for (final o in options) {
      if (o.value == value) {
        selected = o;
        break;
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final _Picked<T>? picked = await showModalBottomSheet<_Picked<T>>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _PickerSheet<T>(
            title: sheetTitle ?? label,
            options: options,
            selected: value,
          ),
        );
        if (picked != null) {
          onChanged(picked.value);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            if (selected?.emoji != null && selected!.emoji!.isNotEmpty) ...[
              Text(selected.emoji!, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
            ] else if (selected?.icon != null) ...[
              Icon(selected!.icon, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                selected?.label ?? '',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Wrapper so the sheet can return a selected value (even `null`) distinctly
/// from being dismissed (which returns `null` from `showModalBottomSheet`).
class _Picked<T> {
  const _Picked(this.value);
  final T value;
}

class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<PickerOption<T>> options;
  final T selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    ListTile(
                      leading: (o.emoji != null && o.emoji!.isNotEmpty)
                          ? Text(o.emoji!, style: const TextStyle(fontSize: 20))
                          : (o.icon != null
                              ? Icon(o.icon, color: cs.onSurfaceVariant)
                              : null),
                      title: Text(o.label),
                      trailing: o.value == selected
                          ? Icon(Icons.check, color: cs.primary)
                          : null,
                      onTap: () => Navigator.pop(context, _Picked<T>(o.value)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
