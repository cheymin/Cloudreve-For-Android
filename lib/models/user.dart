class User {
  final String id;
  final String nickname;
  final String email;
  final String avatar;
  final int storageUsed;
  final int storageTotal;
  final String? group;

  User({
    required this.id,
    required this.nickname,
    required this.email,
    required this.avatar,
    required this.storageUsed,
    required this.storageTotal,
    this.group,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? json;
    final policy = json['policy'] ?? json;
    return User(
      id: user['id']?.toString() ?? '',
      nickname: user['nick'] ?? user['nickname'] ?? '',
      email: user['email'] ?? '',
      avatar: user['avatar'] ?? '',
      storageUsed: policy['used'] ?? 0,
      storageTotal: policy['total'] ?? 0,
      group: user['group']?.toString(),
    );
  }

  String get displayName => nickname.isNotEmpty ? nickname : email;

  double get usagePercent {
    if (storageTotal <= 0) return 0;
    return (storageUsed / storageTotal).clamp(0.0, 1.0);
  }

  String get usageText {
    return '${_formatSize(storageUsed)} / ${_formatSize(storageTotal)}';
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
