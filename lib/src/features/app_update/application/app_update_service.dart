import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

import '../../../../l10n/app_localizations.dart';

/// Google Play In-App Updates (Play Core). Checks whether a newer build is live
/// on Play and walks the user through updating **inside the app** — the
/// background *flexible* flow by default, or the blocking *immediate* flow for
/// high-priority releases. A no-op anywhere Play Core isn't available (web, iOS,
/// sideloaded builds, no Play services) — every call is wrapped so a failure
/// just skips silently.
final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return const AppUpdateService();
});

class AppUpdateService {
  const AppUpdateService();

  /// We only nudge the user once per app process, not on every navigation.
  static bool _checkedThisSession = false;

  /// Release priority (set per release in the Play Console, 0–5) at or above
  /// which we use the blocking *immediate* flow instead of the background
  /// *flexible* one. Normal releases stay flexible (non-intrusive).
  static const int _immediatePriority = 4;

  /// Check Play for an update and, if one is available, start the right flow.
  /// Safe to call from a widget's first frame — it never throws.
  Future<void> checkAndPrompt(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid || _checkedThisSession) {
      return;
    }
    _checkedThisSession = true;

    final AppUpdateInfo info;
    try {
      info = await InAppUpdate.checkForUpdate();
    } catch (_) {
      // No Play services / sideloaded / offline — nothing we can do.
      return;
    }
    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      return;
    }

    final bool wantImmediate = info.updatePriority >= _immediatePriority &&
        info.immediateUpdateAllowed;

    try {
      if (wantImmediate) {
        // Play takes over the screen, downloads, installs, and restarts.
        await InAppUpdate.performImmediateUpdate();
        return;
      }
      if (info.flexibleUpdateAllowed) {
        // Downloads in the background while the user keeps using the app; the
        // future completes once the APK is downloaded.
        final AppUpdateResult result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success && context.mounted) {
          _promptInstall(context);
        }
      }
    } catch (_) {
      // User dismissed the Play dialog or the flow failed — leave it for next
      // launch.
    }
  }

  /// Flexible flow: the update is downloaded but not yet installed. Offer a
  /// persistent snackbar that completes the install (Play restarts the app).
  void _promptInstall(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.updateDownloaded),
        duration: const Duration(days: 1), // Stays until the user acts.
        action: SnackBarAction(
          label: t.updateRestart,
          onPressed: () {
            // Installs the staged update and restarts the app.
            InAppUpdate.completeFlexibleUpdate();
          },
        ),
      ),
    );
  }
}
