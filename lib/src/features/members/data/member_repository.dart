import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../domain/family_member.dart';

class MemberRepository {
  MemberRepository(this._dio);

  final Dio _dio;

  /// All active members of the caller's family.
  Future<List<FamilyMember>> list() async {
    try {
      final Response<dynamic> res = await _dio.get('/members');
      return (res.data as List)
          .map((e) => FamilyMember.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Hand ownership to another member (owner-only). The caller becomes a member.
  Future<void> transferOwnership(String targetRid) async {
    try {
      await _dio.post(
        '/families/transfer-ownership',
        data: {'target_rid': targetRid},
      );
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Rename the family (owner-only).
  Future<void> renameFamily(String name) async {
    try {
      await _dio.patch('/families', data: {'name': name});
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Remove a member from the family (owner-only). Their personal data stays.
  Future<void> removeMember(String rid) async {
    try {
      await _dio.delete('/families/members/$rid');
    } catch (e) {
      throw toApiException(e);
    }
  }
}

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(ref.watch(dioProvider));
});
