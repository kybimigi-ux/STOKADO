class AppUser {
  final String id; // UUID from auth.users
  final String fullName;
  final String email;
  final String? role; // 'Admin', 'Manager', 'Staff'
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.role,
    this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// Initials from the full name (up to 2 letters).
  String get initials {
    final parts = fullName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase());
    return parts.join();
  }
}
