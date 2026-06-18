import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

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

/// Opens the rounded bottom-sheet picker and returns the chosen option's value,
/// or `null` if dismissed. Reusable outside [AppPicker] (e.g. a settings row).
/// Set [searchable] for long lists to show a filter box.
Future<T?> showAppPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<PickerOption<T>> options,
  required T selected,
  bool searchable = false,
}) async {
  final _Picked<T>? picked = await showModalBottomSheet<_Picked<T>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _PickerSheet<T>(
      title: title,
      options: options,
      selected: selected,
      searchable: searchable,
    ),
  );
  return picked?.value;
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
    this.searchable = false,
  });

  final String label;
  final T value;
  final List<PickerOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? sheetTitle;

  /// Show a search box in the sheet (for long option lists, e.g. currencies).
  final bool searchable;

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
        // Use the wrapper directly so a picked *null* (valid for nullable T,
        // e.g. an optional category) is distinct from dismissing the sheet.
        final _Picked<T>? picked = await showModalBottomSheet<_Picked<T>>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _PickerSheet<T>(
            title: sheetTitle ?? label,
            options: options,
            selected: value,
            searchable: searchable,
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

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    this.searchable = false,
  });

  final String title;
  final List<PickerOption<T>> options;
  final T selected;
  final bool searchable;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String q = _query.trim().toLowerCase();
    final List<PickerOption<T>> shown = q.isEmpty
        ? widget.options
        : widget.options
            .where((o) => o.label.toLowerCase().contains(q))
            .toList();
    return SafeArea(
      child: Padding(
        // Lift the sheet above the keyboard when the search field is focused.
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  widget.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (widget.searchable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
                      hintText:
                          MaterialLocalizations.of(context).searchFieldLabel,
                    ),
                  ),
                ),
              Flexible(
                child: shown.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          AppLocalizations.of(context).noResults,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final o in shown)
                            ListTile(
                              leading: (o.emoji != null && o.emoji!.isNotEmpty)
                                  ? Text(o.emoji!,
                                      style: const TextStyle(fontSize: 20))
                                  : (o.icon != null
                                      ? Icon(o.icon, color: cs.onSurfaceVariant)
                                      : null),
                              title: Text(o.label),
                              trailing: o.value == widget.selected
                                  ? Icon(Icons.check, color: cs.primary)
                                  : null,
                              onTap: () =>
                                  Navigator.pop(context, _Picked<T>(o.value)),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
