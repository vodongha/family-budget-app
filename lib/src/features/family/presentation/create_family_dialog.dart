import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/error_text.dart';
import '../../auth/application/auth_controller.dart';

/// Prompts the signed-in account to create a family (it has none yet), e.g. when
/// they tap the Family tab or a family-only feature. Returns `true` if a family
/// was created. Also offers a shortcut to accept an invitation instead.
Future<bool> showCreateFamilyDialog(BuildContext context, WidgetRef ref) async {
  final bool? created = await showDialog<bool>(
    context: context,
    builder: (_) => const _CreateFamilyDialog(),
  );
  return created ?? false;
}

class _CreateFamilyDialog extends ConsumerStatefulWidget {
  const _CreateFamilyDialog();

  @override
  ConsumerState<_CreateFamilyDialog> createState() =>
      _CreateFamilyDialogState();
}

class _CreateFamilyDialogState extends ConsumerState<_CreateFamilyDialog> {
  final _name = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create(AppLocalizations t) async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(authControllerProvider.notifier).createFamily(name);
      navigator.pop(true);
    } catch (e) {
      if (mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
      }
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return AlertDialog(
      actionsOverflowButtonSpacing: 8,
      title: Text(t.setUpFamilyTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.setUpFamilyIntro,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: t.familyName,
              prefixIcon: const Icon(Icons.home_outlined),
            ),
            onSubmitted: (_) => _create(t),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving
                  ? null
                  : () {
                      Navigator.of(context).pop(false);
                      context.push('/invitations');
                    },
              icon: const Icon(Icons.mail_outline, size: 18),
              label: Text(t.checkInvitations),
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: _saving ? null : () => _create(t),
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t.createFamily),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(t.cancel),
        ),
      ],
    );
  }
}
