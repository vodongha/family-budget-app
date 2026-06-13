import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/category.dart';

class CategoryRepository {
  CategoryRepository(this._dio);

  final Dio _dio;

  Future<List<Category>> list({bool includeArchived = false}) async {
    try {
      final Response<dynamic> res = await _dio.get(
        '/categories',
        queryParameters: {if (includeArchived) 'include_archived': true},
      );
      return (res.data as List)
          .map((e) => Category.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<Category> create({
    required String name,
    required String kind,
    String? icon,
    String? color,
  }) async {
    try {
      final Response<dynamic> res = await _dio.post('/categories', data: {
        'name': name,
        'kind': kind,
        if (icon != null && icon.isNotEmpty) 'icon': icon,
        if (color != null && color.isNotEmpty) 'color': color,
      });
      return Category.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<Category> update(
    String rid, {
    String? name,
    String? icon,
    bool? isArchived,
  }) async {
    try {
      final Response<dynamic> res = await _dio.patch('/categories/$rid', data: {
        if (name != null) 'name': name,
        if (icon != null) 'icon': icon,
        if (isArchived != null) 'is_archived': isArchived,
      });
      return Category.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> delete(String rid) async {
    try {
      await _dio.delete('/categories/$rid');
    } catch (e) {
      throw toApiException(e);
    }
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(dioProvider));
});
