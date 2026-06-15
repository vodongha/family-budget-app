import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wallets/application/wallet_scope.dart';
import '../data/category_repository.dart';
import '../domain/category.dart';

/// Loads the categories of the current scope (personal / family), active only.
/// Mutations reload the list. Follows [walletScopeProvider].
class CategoriesController extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() {
    final WalletScope scope = ref.watch(walletScopeProvider);
    return ref.read(categoryRepositoryProvider).list(scope: scope.api);
  }

  Future<void> _reload() async {
    final WalletScope scope = ref.read(walletScopeProvider);
    state = await AsyncValue.guard(
      () => ref.read(categoryRepositoryProvider).list(scope: scope.api),
    );
  }

  Future<void> create({
    required String name,
    required String kind,
    String? icon,
    String? color,
  }) async {
    final WalletScope scope = ref.read(walletScopeProvider);
    await ref.read(categoryRepositoryProvider).create(
          name: name,
          kind: kind,
          scope: scope.api,
          icon: icon,
          color: color,
        );
    await _reload();
  }

  Future<void> edit(String rid, {required String name, String? icon}) async {
    await ref
        .read(categoryRepositoryProvider)
        .update(rid, name: name, icon: icon);
    await _reload();
  }

  Future<void> delete(String rid) async {
    await ref.read(categoryRepositoryProvider).delete(rid);
    await _reload();
  }
}

final categoriesControllerProvider =
    AsyncNotifierProvider<CategoriesController, List<Category>>(
  CategoriesController.new,
);

/// Categories filtered to one kind (`expense`/`income`) for the picker.
final categoriesByKindProvider =
    Provider.family<List<Category>, String>((ref, kind) {
  final cats = ref.watch(categoriesControllerProvider).valueOrNull ?? [];
  return cats.where((c) => c.kind == kind && !c.isArchived).toList();
});
