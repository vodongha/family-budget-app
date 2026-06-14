import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/app_info.dart';

/// Publisher / "About" screen: app identity, version, developer, and a link to
/// the publisher website.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AsyncValue<dynamic> info = ref.watch(packageInfoProvider);
    final String version = info.maybeWhen(
      data: (i) => 'v${i.version}',
      orElse: () => '',
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.about)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  height: 84,
                  width: 84,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cs.primary, cs.tertiary],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(Icons.savings_outlined,
                      color: cs.onPrimary, size: 44),
                ),
                const SizedBox(height: 16),
                Text(
                  t.appTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (version.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    version,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t.appIntro,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 28),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.business_outlined, color: cs.primary),
                  title: Text(t.developer),
                  subtitle: Text(Publisher.name),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.public, color: cs.primary),
                  title: Text(t.website),
                  subtitle: Text(Publisher.website),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _open(context, t),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, AppLocalizations t) async {
    final messenger = ScaffoldMessenger.of(context);
    final bool ok = await launchUrl(
      Uri.parse(Publisher.website),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(t.openLinkFailed)));
    }
  }
}
