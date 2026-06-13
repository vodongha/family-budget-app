/// A member of the current family, as returned by `GET /members`.
class FamilyMember {
  const FamilyMember({
    required this.rid,
    required this.displayName,
    required this.email,
    required this.role,
    this.phone,
  });

  final String rid;
  final String displayName;
  final String email;
  final String? phone;

  /// `owner` or `member`.
  final String role;

  bool get isOwner => role == 'owner';

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      rid: json['rid'] as String,
      displayName: (json['display_name'] ?? '') as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: (json['role'] ?? 'member') as String,
    );
  }
}
