/// The signed-in account, reduced to what the UI shows.
///
/// Fed by two sources: Google Sign-In, which only gives a display name and a
/// photo, and the app's own backend, which gives the name in two halves plus a
/// role and the bearer token every later call needs.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.name,
    this.photoUrl,
    this.firstName,
    this.lastName,
    this.role,
    this.accessToken,
  });

  final String id;
  final String email;
  final String? name;
  final String? photoUrl;
  final String? firstName;
  final String? lastName;
  final String? role;

  /// Bearer token issued by the backend. Null for a Google session, which the
  /// app authenticates on its own.
  final String? accessToken;

  /// Name when one is known — Google's display name, otherwise the two halves
  /// the backend stores — and the part before the `@` when neither is set.
  String get displayName {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;

    final full = [
      firstName?.trim() ?? '',
      lastName?.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;

    final local = email.split('@').first;
    return local.isEmpty ? email : local;
  }

  /// Single letter for the avatar fallback.
  String get initial =>
      displayName.isEmpty ? '?' : displayName[0].toUpperCase();

  AppUser copyWith({String? accessToken}) => AppUser(
    id: id,
    email: email,
    name: name,
    photoUrl: photoUrl,
    firstName: firstName,
    lastName: lastName,
    role: role,
    accessToken: accessToken ?? this.accessToken,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'photoUrl': photoUrl,
    'firstName': firstName,
    'lastName': lastName,
    'role': role,
    'accessToken': accessToken,
  };

  factory AppUser.fromJson(Map<String, Object?> json) => AppUser(
    id: _string(json['id']) ?? '',
    email: _string(json['email']) ?? '',
    name: _string(json['name']),
    photoUrl: _string(json['photoUrl']),
    firstName: _string(json['firstName']),
    lastName: _string(json['lastName']),
    role: _string(json['role']),
    accessToken: _string(json['accessToken']),
  );

  /// Reads the `user` object the backend returns, which spells its fields in
  /// snake_case and carries the token beside — not inside — the object.
  factory AppUser.fromApi(Map<String, Object?> json, {String? accessToken}) {
    // An avatar is optional and the backend sends the bare host when a user has
    // none, which is not an image; only a path worth loading is kept.
    final avatar = _string(json['avatar']);
    return AppUser(
      id: _string(json['id']) ?? '',
      email: _string(json['email']) ?? '',
      firstName: _string(json['first_name']),
      lastName: _string(json['last_name']),
      role: _string(json['role']),
      photoUrl: avatar != null && Uri.tryParse(avatar)?.hasEmptyPath == false
          ? avatar
          : null,
      accessToken: accessToken,
    );
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.email == email &&
      other.name == name &&
      other.photoUrl == photoUrl &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.role == role &&
      other.accessToken == accessToken;

  @override
  int get hashCode => Object.hash(
    id,
    email,
    name,
    photoUrl,
    firstName,
    lastName,
    role,
    accessToken,
  );
}
