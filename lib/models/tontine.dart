/// Modèle pour représenter une tontine
class Tontine {
  final String id;
  final String name;
  final String description;
  final int memberCount;
  final double monthlyAmount;
  final String status; // 'active', 'pending', 'completed'
  final DateTime createdAt;
  final String creatorId;
  final int currentCycle;
  final String? frequency; // 'Mensuel', 'Hebdo', 'Journalier'
  final bool? _isDiscoverable; // visible dans l'écran Découvrir
  final double? rating; // 4.9, 4.8, etc.
  final String? creatorName; // Nom du créateur pour affichage
  final int? maxMembers; // Limite de membres
  final List<String> memberIds; // Identifiants des membres

  Tontine({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.monthlyAmount,
    required this.status,
    required this.createdAt,
    required this.creatorId,
    this.currentCycle = 0,
    this.frequency,
    bool? isDiscoverable,
    this.rating,
    this.creatorName,
    this.maxMembers,
    this.memberIds = const [],
  }) : _isDiscoverable = isDiscoverable;

  bool get isDiscoverable => _isDiscoverable ?? true;

  factory Tontine.fromJson(Map<String, dynamic> json) {
    return Tontine(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      memberCount: json['memberCount'] as int,
      monthlyAmount: (json['monthlyAmount'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      creatorId: json['creatorId'] as String,
        currentCycle: (json['currentCycle'] as num?)?.toInt() ??
          (json['cycleActuel'] as num?)?.toInt() ??
          0,
      frequency: json['frequency'] as String?,
      isDiscoverable: json['isDiscoverable'] as bool?,
      rating: (json['rating'] as num?)?.toDouble(),
      creatorName: json['creatorName'] as String?,
      maxMembers: json['maxMembers'] as int?,
      memberIds: List<String>.from(json['memberIds'] ?? json['membres'] ?? const []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'memberCount': memberCount,
      'monthlyAmount': monthlyAmount,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'creatorId': creatorId,
      'currentCycle': currentCycle,
      'frequency': frequency,
      'isDiscoverable': isDiscoverable,
      'rating': rating,
      'creatorName': creatorName,
      'maxMembers': maxMembers,
      'memberIds': memberIds,
    };
  }
}
