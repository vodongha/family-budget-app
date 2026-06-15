import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'api_client.dart';

/// A friendly, centred error state with a retry button. Connection failures
/// (offline / server unreachable) get a dedicated icon + localized message
/// instead of a raw exception string.
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;

    final bool offline =
        error is ApiException && (error as ApiException).isConnection;
    final IconData icon =
        offline ? Icons.cloud_off_outlined : Icons.error_outline;
    final String message = offline
        ? t.connectionError
        : (error is ApiException
            ? (error as ApiException).message
            : t.somethingWrong);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(t.retry),
            ),
          ],
        ),
      ),
    );
  }
}
