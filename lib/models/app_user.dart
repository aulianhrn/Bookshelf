class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.username,
  });

  final String id;
  final String email;
  final String username;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'email': email, 'username': username};
  }
}
