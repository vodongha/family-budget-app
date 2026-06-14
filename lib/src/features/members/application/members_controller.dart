import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/member_repository.dart';
import '../domain/family_member.dart';

/// Loads the family's members; lets an owner transfer ownership.
class MembersController extends AsyncNotifier<List<FamilyMember>> {
  @override
  Future<List<FamilyMember>> build() {
    return ref.read(memberRepositoryProvider).list();
  }

  /// Transfer ownership to [targetRid]. Refreshes the member list and the
  /// signed-in user (whose role changes). Throws [ApiException] on failure.
  Future<void> transferOwnership(String targetRid) async {
    await ref.read(memberRepositoryProvider).transferOwnership(targetRid);
    await ref.read(authControllerProvider.notifier).refreshUser();
    state = await AsyncValue.guard(
      () => ref.read(memberRepositoryProvider).list(),
    );
  }

  /// Remove [rid] from the family (owner-only). Refreshes the member list.
  Future<void> removeMember(String rid) async {
    await ref.read(memberRepositoryProvider).removeMember(rid);
    state = await AsyncValue.guard(
      () => ref.read(memberRepositoryProvider).list(),
    );
  }

  /// Rename the family (owner-only).
  Future<void> renameFamily(String name) async {
    await ref.read(memberRepositoryProvider).renameFamily(name);
  }
}

final membersControllerProvider =
    AsyncNotifierProvider<MembersController, List<FamilyMember>>(
  MembersController.new,
);
