import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/category_repository.dart';
import '../domain/category.dart';

/// Loads the family's categories (active only). Mutations reload the list.
class CategoriesController extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() {
    return ref.read(categoryRepositoryProvider).list();
  }

  Future<void> _reload() async {
    state = await AsyncValue.guard(
      () => ref.read(categoryRepositoryProvider).list(),
    );
  }

  Future<void> create({
    required String name,
    required String kind,
    String? icon,
    String? color,
  }) async {
    await ref
        .read(categoryRepositoryProvider)
        .create(name: name, kind: kind, icon: icon, color: color);
    await _reload();
  }

  Future<void> rename(String rid, String name) async {
    await ref.read(categoryRepositoryProvider).update(rid, name: name);
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
