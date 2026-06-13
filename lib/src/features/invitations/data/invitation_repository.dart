import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/token_storage.dart';
import '../domain/invitation.dart';

class InvitationRepository {
  InvitationRepository(this._dio, this._storage);

  final Dio _dio;
  final TokenStorage _storage;

  /// Owner creates an invitation (email and/or phone; at least one).
  Future<FamilyInvitation> create({String? email, String? phone}) async {
    try {
      final Response<dynamic> res = await _dio.post('/invitations', data: {
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });
      return FamilyInvitation.fromJson(
          (res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Pending in-app invites addressed to the signed-in account.
  Future<List<InboxInvitation>> inbox() async {
    try {
      final Response<dynamic> res = await _dio.get('/invitations/inbox');
      return (res.data as List)
          .map((e) =>
              InboxInvitation.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Accept an in-app invite: join the inviting family. Stores the returned JWT
  /// (the new family scope). Re-read the auth controller afterwards.
  Future<void> acceptExisting(String rid) async {
    try {
      final Response<dynamic> res =
          await _dio.post('/invitations/$rid/accept-existing');
      await _storage.write((res.data as Map)['access_token'] as String);
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Decline an in-app invite.
  Future<void> decline(String rid) async {
    try {
      await _dio.post('/invitations/$rid/decline');
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Public — read an invitation by token to show the landing page.
  Future<InvitationPublic> getPublic(String token) async {
    try {
      final Response<dynamic> res = await _dio.get('/invitations/$token');
      return InvitationPublic.fromJson(
          (res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw toApiException(e);
    }
  }

  /// Accept an invitation: creates the invitee's account and stores the returned
  /// JWT (auto-login). Re-read the auth controller afterwards to enter the app.
  Future<void> accept({
    required String token,
    required String password,
    required String displayName,
    String? email,
  }) async {
    try {
      final Response<dynamic> res =
          await _dio.post('/invitations/accept', data: {
        'token': token,
        'password': password,
        'display_name': displayName,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      await _storage.write((res.data as Map)['access_token'] as String);
    } catch (e) {
      throw toApiException(e);
    }
  }
}

final invitationRepositoryProvider = Provider<InvitationRepository>((ref) {
  return InvitationRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});
