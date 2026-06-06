class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.fullName,
  });

  final int id;
  final String email;
  final String? fullName;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
    );
  }
}
