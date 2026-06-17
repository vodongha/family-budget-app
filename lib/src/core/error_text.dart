import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import 'api_client.dart';

/// Maps any thrown error to a short, localized, user-facing message.
///
/// This is the single place the UI turns an exception into text — so technical
/// details (HTTP 500, DioException dumps, stack traces) never reach the user.
/// A server-supplied client-error reason (`ApiException.serverDetail`) is shown
/// as-is because it is specific and actionable (e.g. "phone already in use");
/// everything else collapses to a friendly generic message.
String friendlyError(BuildContext context, Object error) {
  final AppLocalizations t = AppLocalizations.of(context);
  final ApiException e =
      error is ApiException ? error : ApiException('request-failed');

  if (e.isConnection) {
    return t.errorNoConnection;
  }
  final int code = e.statusCode ?? 0;
  if (code >= 500) {
    return t.errorServer;
  }
  if (code == 401) {
    return t.errorSession;
  }
  if (e.serverDetail) {
    return e.message;
  }
  return t.errorGeneric;
}
