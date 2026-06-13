/// An invitation created by an owner (carries the share token).
class FamilyInvitation {
  const FamilyInvitation({
    required this.rid,
    required this.role,
    required this.status,
    required this.token,
    this.email,
    this.phone,
  });

  final String rid;
  final String role;
  final String status;
  final String token;
  final String? email;
  final String? phone;

  factory FamilyInvitation.fromJson(Map<String, dynamic> json) {
    return FamilyInvitation(
      rid: json['rid'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      token: json['token'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

/// The public view shown on the invite landing page (no account yet).
class InvitationPublic {
  const InvitationPublic({
    required this.familyName,
    required this.role,
    required this.status,
    this.email,
  });

  final String familyName;
  final String role;
  final String status;

  /// When set, the invite already carries an email and the invitee won't enter one.
  final String? email;

  bool get needsEmail => email == null || email!.isEmpty;

  factory InvitationPublic.fromJson(Map<String, dynamic> json) {
    return InvitationPublic(
      familyName: (json['family_name'] ?? '') as String,
      role: (json['role'] ?? 'member') as String,
      status: (json['status'] ?? 'pending') as String,
      email: json['email'] as String?,
    );
  }
}
