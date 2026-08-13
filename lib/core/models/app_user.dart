/// The signed-in Google account, reduced to what the UI shows.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.name,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String? name;
  final String? photoUrl;

  /// Name when Google gave one, otherwise the part before the `@`.
  String get displayName {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final local = email.split('@').first;
    return local.isEmpty ? email : local;
  }

  /// Single letter for the avatar fallback.
  String get initial =>
      displayName.isEmpty ? '?' : displayName[0].toUpperCase();

  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'photoUrl': photoUrl,
  };

  factory AppUser.fromJson(Map<String, Object?> json) => AppUser(
    id: json['id'] is String ? json['id'] as String : '',
    email: json['email'] is String ? json['email'] as String : '',
    name: json['name'] is String ? json['name'] as String : null,
    photoUrl: json['photoUrl'] is String ? json['photoUrl'] as String : null,
  );

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.email == email &&
      other.name == name &&
      other.photoUrl == photoUrl;

  @override
  int get hashCode => Object.hash(id, email, name, photoUrl);
}
