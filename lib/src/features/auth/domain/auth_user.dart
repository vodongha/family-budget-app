/// The authenticated user, as returned by `GET /auth/me`.
class AuthUser {
  const AuthUser({
    required this.rid,
    required this.email,
    required this.displayName,
    required this.role,
  });

  final String rid;
  final String email;
  final String displayName;

  /// `owner` or `member`. Owners may manage invitations.
  final String role;

  bool get isOwner => role == 'owner';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      rid: json['rid'] as String,
      email: json['email'] as String,
      displayName: (json['display_name'] ?? '') as String,
      role: (json['role'] ?? 'member') as String,
    );
  }
}
