/// Modèle pour représenter un utilisateur
class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String profileImage;
  final String walletAddress;
  final double trustScore;
  final double totalSavings;
  final bool twoFactorEnabled;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.profileImage,
    required this.walletAddress,
    required this.trustScore,
    required this.totalSavings,
    required this.twoFactorEnabled,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      profileImage: json['profileImage'] as String,
      walletAddress: json['walletAddress'] as String,
      trustScore: (json['trustScore'] as num).toDouble(),
      totalSavings: (json['totalSavings'] as num).toDouble(),
      twoFactorEnabled: json['twoFactorEnabled'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'profileImage': profileImage,
      'walletAddress': walletAddress,
      'trustScore': trustScore,
      'totalSavings': totalSavings,
      'twoFactorEnabled': twoFactorEnabled,
    };
  }
}
