import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'api_client.dart';

/// A friendly, centred error state with a retry button. Connection failures
/// (offline / server unreachable) get a dedicated icon + localized message
/// instead of a raw exception string.
///
/// Tapping **Retry** spins the button for a brief, guaranteed-visible moment
/// before reloading: a connection failure usually returns almost instantly, so
/// without this the loading state would flash for a single frame and the user
/// would think the button did nothing.
class AppErrorView extends StatefulWidget {
  const AppErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  State<AppErrorView> createState() => _AppErrorViewState();
}

class _AppErrorViewState extends State<AppErrorView> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) {
      return;
    }
    setState(() => _retrying = true);
    // Hold a short, perceptible spinner before triggering the reload so the
    // user always gets feedback, even when the failure comes back instantly.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) {
      return;
    }
    widget.onRetry();
    if (mounted) {
      setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;

    final bool offline = widget.error is ApiException &&
        (widget.error as ApiException).isConnection;
    final IconData icon =
        offline ? Icons.cloud_off_outlined : Icons.error_outline;
    final String message = offline
        ? t.connectionError
        : (widget.error is ApiException
            ? (widget.error as ApiException).message
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
              onPressed: _retrying ? null : _retry,
              icon: _retrying
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onSecondaryContainer,
                      ),
                    )
                  : const Icon(Icons.refresh),
              label: Text(t.retry),
            ),
          ],
        ),
      ),
    );
  }
}
