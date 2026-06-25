import 'dart:convert';

import 'package:family_budget_app/src/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AuthUser survives a toJson/fromJson round-trip (session cache)', () {
    const user = AuthUser(
      rid: '01HZX',
      email: 'a@example.com',
      displayName: 'Alice',
      phone: '+84912345678',
      role: 'owner',
      hasFamily: true,
      hasPassword: false,
      familyName: 'Vo Family',
    );

    // Mirrors how the cached profile is persisted and read back on resume.
    final copy = AuthUser.fromJson(
      (jsonDecode(jsonEncode(user.toJson())) as Map).cast<String, dynamic>(),
    );

    expect(copy.rid, user.rid);
    expect(copy.email, user.email);
    expect(copy.displayName, user.displayName);
    expect(copy.phone, user.phone);
    expect(copy.role, user.role);
    expect(copy.hasFamily, user.hasFamily);
    expect(copy.hasPassword, user.hasPassword);
    expect(copy.familyName, user.familyName);
    expect(copy.isOwner, isTrue);
  });

  test('AuthUser round-trips a family-less account with null phone/family', () {
    const user = AuthUser(
      rid: '01HZY',
      email: 'b@example.com',
      displayName: 'Bob',
      role: 'member',
      hasFamily: false,
      hasPassword: true,
    );

    final copy = AuthUser.fromJson(
      (jsonDecode(jsonEncode(user.toJson())) as Map).cast<String, dynamic>(),
    );

    expect(copy.phone, isNull);
    expect(copy.familyName, isNull);
    expect(copy.hasFamily, isFalse);
    expect(copy.isOwner, isFalse);
  });
}
