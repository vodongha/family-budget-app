/// The authenticated user, as returned by `GET /auth/me`.
class AuthUser {
  const AuthUser({
    required this.rid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.hasFamily,
    required this.hasPassword,
    this.phone,
    this.familyName,
  });

  final String rid;
  final String email;
  final String displayName;

  /// Optional contact number in E.164 (e.g. `+84912345678`), or null.
  final String? phone;

  /// `owner` or `member`. Owners may manage invitations.
  final String role;

  /// Whether the account belongs to a family yet. A freshly registered (or new
  /// Google) account has none until it creates or joins one; the personal tab
  /// works without one.
  final bool hasFamily;

  /// The family's display name, or null when the user has no family.
  final String? familyName;

  /// Whether a password is set. False for Google-only accounts, which see a
  /// "set password" form (no current password) instead of "change password".
  final bool hasPassword;

  bool get isOwner => role == 'owner';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      rid: json['rid'] as String,
      email: json['email'] as String,
      displayName: (json['display_name'] ?? '') as String,
      phone: json['phone'] as String?,
      role: (json['role'] ?? 'member') as String,
      hasFamily: (json['has_family'] ?? false) as bool,
      hasPassword: (json['has_password'] ?? true) as bool,
      familyName: json['family_name'] as String?,
    );
  }

  /// Round-trips through [AuthUser.fromJson] (same keys as `GET /auth/me`), so a
  /// cached copy can resume the session when the server is briefly unreachable.
  Map<String, dynamic> toJson() {
    return {
      'rid': rid,
      'email': email,
      'display_name': displayName,
      'phone': phone,
      'role': role,
      'has_family': hasFamily,
      'has_password': hasPassword,
      'family_name': familyName,
    };
  }
}
