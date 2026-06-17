import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/error_text.dart';
import '../../../core/config.dart';
import '../../../core/phone_field.dart';
import '../data/invitation_repository.dart';
import '../domain/invitation.dart';

/// Owner-only: invite someone by email or phone. If the contact matches an
/// existing account, the invite is delivered in-app (no link); otherwise a
/// shareable registration link is shown.
class AddMemberScreen extends ConsumerStatefulWidget {
  const AddMemberScreen({super.key});

  @override
  ConsumerState<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends ConsumerState<AddMemberScreen> {
  final _email = TextEditingController();
  String? _phone;
  bool _saving = false;
  FamilyInvitation? _created;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String _inviteLink(String token) {
    // The invite landing is the web app, served same-origin as the API at
    // AppConfig.apiBaseUrl. We must build from that fixed origin, not from
    // Uri.base â€” on mobile Uri.base is `file:///`, which would produce a
    // useless `file:///#/invite/...` link. The route is hash-based (default
    // URL strategy).
    final String origin = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$origin/#/invite/$token';
  }

  Future<void> _create(AppLocalizations t) async {
    final String email = _email.text.trim();
    final String? phone = _phone;
    if (email.isEmpty && (phone == null || phone.isEmpty)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.emailOrPhoneRequired)));
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final FamilyInvitation inv = await ref
          .read(invitationRepositoryProvider)
          .create(email: email, phone: phone);
      setState(() => _created = inv);
    } catch (e) {
      if (mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text(friendlyError(context, e))));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final FamilyInvitation? created = _created;

    return Scaffold(
      appBar: AppBar(title: Text(t.addMember)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            t.inviteByEmailOrPhone,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            enabled: created == null,
            decoration: InputDecoration(
              labelText: t.email,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          if (created == null)
            AppPhoneField(
              initialE164: null,
              label: t.phoneOptional,
              invalidMessage: t.invalidPhone,
              onChanged: (e164) => _phone = e164,
            ),
          const SizedBox(height: 24),
          if (created == null)
            FilledButton.icon(
              onPressed: _saving ? null : () => _create(t),
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt),
              label: Text(t.createInvite),
            )
          else if (created.inApp)
            const _InAppInviteCard()
          else
            _InviteLinkCard(link: _inviteLink(created.token)),
        ],
      ),
    );
  }
}

/// Shown when the invited contact already has an account: the invite lands in
/// their app and they accept it there â€” no link to share.
class _InAppInviteCard extends StatelessWidget {
  const _InAppInviteCard();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.inAppInviteSent,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(t.inAppInviteHint,
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _InviteLinkCard extends StatelessWidget {
  const _InviteLinkCard({required this.link});
  final String link;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  t.inviteLinkReady,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(t.inviteLinkHint,
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(t.linkCopied)));
                }
              },
              icon: const Icon(Icons.copy),
              label: Text(t.copyLink),
            ),
          ],
        ),
      ),
    );
  }
}
