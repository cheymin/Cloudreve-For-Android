class User {
  final String id;
  final String? email;
  final String nickname;
  final String? avatar;
  final DateTime? createdAt;
  final String? preferredTheme;
  final String? language;
  final bool? anonymous;
  final String? groupName;

  User({
    required this.id,
    this.email,
    required this.nickname,
    this.avatar,
    this.createdAt,
    this.preferredTheme,
    this.language,
    this.anonymous,
    this.groupName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      email: json['email']?.toString(),
      nickname: (json['nickname'] ?? json['nick'] ?? '').toString(),
      avatar: json['avatar']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      preferredTheme: json['preferred_theme']?.toString(),
      language: json['language']?.toString(),
      anonymous: json['anonymous'] as bool?,
      groupName: json['group']?['name']?.toString(),
    );
  }

  String get displayName => nickname.isNotEmpty ? nickname : (email ?? 'User');
}
