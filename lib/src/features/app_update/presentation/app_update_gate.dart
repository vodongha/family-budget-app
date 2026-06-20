import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/app_update_service.dart';

/// Runs a Google Play in-app update check once, after the first frame, then
/// just renders [child]. Wrap the signed-in home with it so the check fires the
/// moment the user lands in the app (and only there — not on the login/splash
/// screens). The check itself is a no-op off Android/Play, so this is safe on
/// every platform.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(appUpdateServiceProvider).checkAndPrompt(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
