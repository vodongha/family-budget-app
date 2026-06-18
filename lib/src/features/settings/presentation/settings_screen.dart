import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/app_info.dart';
import '../../../core/money.dart';
import '../../../core/prefs.dart';
import '../../../core/responsive.dart';
import '../../auth/application/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ThemeMode mode = ref.watch(themeControllerProvider);
    final Locale? locale = ref.watch(localeControllerProvider);
    final String version = ref.watch(packageInfoProvider).maybeWhen(
          data: (i) => 'v${i.version}',
          orElse: () => '',
        );
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String displayCurrency = ref.watch(displayCurrencyControllerProvider);
    final bool hasPassword =
        ref.watch(authControllerProvider).valueOrNull?.hasPassword ?? true;

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader(t.appearance),
            _OptionCard(
              children: [
                _ChoiceTile(
                  icon: Icons.brightness_auto_outlined,
                  label: t.systemDefault,
                  selected: mode == ThemeMode.system,
                  onTap: () => ref
                      .read(themeControllerProvider.notifier)
                      .setMode(ThemeMode.system),
                ),
                _ChoiceTile(
                  icon: Icons.light_mode_outlined,
                  label: t.light,
                  selected: mode == ThemeMode.light,
                  onTap: () => ref
                      .read(themeControllerProvider.notifier)
                      .setMode(ThemeMode.light),
                ),
                _ChoiceTile(
                  icon: Icons.dark_mode_outlined,
                  label: t.dark,
                  selected: mode == ThemeMode.dark,
                  onTap: () => ref
                      .read(themeControllerProvider.notifier)
                      .setMode(ThemeMode.dark),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeader(t.language),
            _OptionCard(
              children: [
                _ChoiceTile(
                  icon: Icons.translate_outlined,
                  label: t.systemDefault,
                  selected: locale == null,
                  onTap: () => ref
                      .read(localeControllerProvider.notifier)
                      .setLocale(null),
                ),
                _ChoiceTile(
                  icon: Icons.language,
                  label: t.english,
                  selected: locale?.languageCode == 'en',
                  onTap: () => ref
                      .read(localeControllerProvider.notifier)
                      .setLocale(const Locale('en')),
                ),
                _ChoiceTile(
                  icon: Icons.language,
                  label: t.vietnamese,
                  selected: locale?.languageCode == 'vi',
                  onTap: () => ref
                      .read(localeControllerProvider.notifier)
                      .setLocale(const Locale('vi')),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeader(t.primaryCurrency),
            _OptionCard(
              children: [
                ListTile(
                  leading: Icon(Icons.payments_outlined, color: cs.primary),
                  title: Text(t.primaryCurrency),
                  subtitle: Text(t.primaryCurrencyNote),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$displayCurrency  ${Money.symbolFor(displayCurrency)}',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _pickCurrency(context, ref, t, displayCurrency),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeader(t.account),
            _OptionCard(
              children: [
                ListTile(
                  leading: Icon(Icons.lock_outline, color: cs.primary),
                  title: Text(hasPassword ? t.changePassword : t.setPassword),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/change-password'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeader(t.about),
            _OptionCard(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline, color: cs.primary),
                  title: Text(t.about),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/about'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.tag, color: cs.primary),
                  title: Text(t.version),
                  subtitle: Text(t.openOnPlayStore),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(version,
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(width: 8),
                      Icon(Icons.open_in_new, size: 18, color: cs.primary),
                    ],
                  ),
                  onTap: () => _openPlayStore(context, t),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCurrency(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    String current,
  ) async {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                t.primaryCurrency,
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final String code in Money.supportedCurrencies)
              ListTile(
                leading: SizedBox(
                  width: 28,
                  child: Text(
                    Money.symbolFor(code),
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ),
                title: Text(code),
                trailing: code == current
                    ? Icon(Icons.check_circle, color: cs.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, code),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked != current) {
      await ref
          .read(displayCurrencyControllerProvider.notifier)
          .setCurrency(picked);
    }
  }

  Future<void> _openPlayStore(BuildContext context, AppLocalizations t) async {
    final messenger = ScaffoldMessenger.of(context);
    final bool ok = await launchUrl(
      Uri.parse(Publisher.playStoreUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(t.openLinkFailed)));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle, color: cs.primary)
          : const Icon(Icons.circle_outlined, color: Colors.transparent),
      onTap: onTap,
    );
  }
}
