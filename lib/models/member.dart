/// Modèle pour représenter un membre d'une tontine
class Member {
  final String id;
  final String? tontineId;
  final String name;
  final String email;
  final String phone;
  final String profileImageUrl;
  final String role; // 'organizer', 'participant'
  final DateTime joinedAt;
  final bool isPaid; // pour le mois actuel
  final int allocationOrder; // ordre de réception (1, 2, 3, ...)
  final String allocationStatus; // 'waiting', 'current', 'received'

  Member({
    required this.id,
    this.tontineId,
    required this.name,
    required this.email,
    required this.phone,
    required this.profileImageUrl,
    required this.role,
    required this.joinedAt,
    required this.isPaid,
    this.allocationOrder = 0,
    this.allocationStatus = 'waiting',
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      tontineId: json['tontineId'] as String?,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      profileImageUrl: json['profileImageUrl'] as String,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      isPaid: json['isPaid'] as bool,
      allocationOrder: json['allocationOrder'] as int? ?? 0,
      allocationStatus: json['allocationStatus'] as String? ?? 'waiting',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tontineId': tontineId,
      'name': name,
      'email': email,
      'phone': phone,
      'profileImageUrl': profileImageUrl,
      'role': role,
      'joinedAt': joinedAt.toIso8601String(),
      'isPaid': isPaid,
      'allocationOrder': allocationOrder,
      'allocationStatus': allocationStatus,
    };
  }
}
