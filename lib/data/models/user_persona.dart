/// User persona model for KiraKira
class UserPersona {
  final String id;
  final String name;
  final String? description;
  final String? characterId;
  final String? avatarPath;
  final bool isDefault;
  final DateTime createdAt;

  const UserPersona({
    required this.id,
    required this.name,
    this.description,
    this.characterId,
    this.avatarPath,
    this.isDefault = false,
    required this.createdAt,
  });

  UserPersona copyWith({
    String? id,
    String? name,
    String? description,
    String? characterId,
    String? avatarPath,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return UserPersona(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      characterId: characterId ?? this.characterId,
      avatarPath: avatarPath ?? this.avatarPath,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'description': description,
    'characterId': characterId, 'avatarPath': avatarPath,
    'isDefault': isDefault, 'createdAt': createdAt.toIso8601String(),
  };

  factory UserPersona.fromJson(Map<String, dynamic> json) => UserPersona(
    id: json['id'] as String, name: json['name'] as String,
    description: json['description'] as String?,
    characterId: json['characterId'] as String?,
    avatarPath: json['avatarPath'] as String?,
    isDefault: json['isDefault'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
