import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/budget_repository.dart';
import '../domain/budget.dart';

/// Family-level monthly category budgets with current-month spend.
class BudgetsController extends AsyncNotifier<List<Budget>> {
  @override
  Future<List<Budget>> build() {
    return ref.read(budgetRepositoryProvider).list();
  }

  Future<void> create(
      {required String categoryRid, required int amount}) async {
    await ref
        .read(budgetRepositoryProvider)
        .create(categoryRid: categoryRid, amount: amount);
    ref.invalidateSelf();
    await future;
  }

  Future<void> edit({required String rid, required int amount}) async {
    await ref.read(budgetRepositoryProvider).update(rid: rid, amount: amount);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(String rid) async {
    await ref.read(budgetRepositoryProvider).delete(rid);
    ref.invalidateSelf();
    await future;
  }
}

final budgetsControllerProvider =
    AsyncNotifierProvider<BudgetsController, List<Budget>>(
  BudgetsController.new,
);
