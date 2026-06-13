import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/invitation_repository.dart';
import '../domain/invitation.dart';

/// Pending in-app invites for the signed-in account. Accepting moves the user
/// into the inviting family; declining dismisses the invite.
class InboxController extends AsyncNotifier<List<InboxInvitation>> {
  @override
  Future<List<InboxInvitation>> build() {
    return ref.read(invitationRepositoryProvider).inbox();
  }

  /// Accept the invite and refresh the signed-in user (now in a new family).
  /// Throws [ApiException] on failure (e.g. 409 — must transfer ownership first).
  Future<void> accept(String rid) async {
    await ref.read(invitationRepositoryProvider).acceptExisting(rid);
    await ref.read(authControllerProvider.notifier).refreshUser();
    state = await AsyncValue.guard(
      () => ref.read(invitationRepositoryProvider).inbox(),
    );
  }

  Future<void> decline(String rid) async {
    await ref.read(invitationRepositoryProvider).decline(rid);
    state = await AsyncValue.guard(
      () => ref.read(invitationRepositoryProvider).inbox(),
    );
  }
}

final inboxControllerProvider =
    AsyncNotifierProvider<InboxController, List<InboxInvitation>>(
  InboxController.new,
);
