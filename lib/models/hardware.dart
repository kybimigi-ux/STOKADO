/// Permissions assigned to a member within a hardware workspace.
class MemberPermissions {
  final bool canAddProducts;
  final bool canEditProducts;
  final bool canRemoveProducts;
  final bool canAddTransactions;
  final bool canCancelTransactions;

  const MemberPermissions({
    this.canAddProducts = true,
    this.canEditProducts = true,
    this.canRemoveProducts = false,
    this.canAddTransactions = true,
    this.canCancelTransactions = false,
  });

  factory MemberPermissions.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const MemberPermissions();
    return MemberPermissions(
      canAddProducts: data['can_add_products'] as bool? ?? data['canAddProducts'] as bool? ?? true,
      canEditProducts: data['can_edit_products'] as bool? ?? data['canEditProducts'] as bool? ?? true,
      canRemoveProducts: data['can_remove_products'] as bool? ?? data['canRemoveProducts'] as bool? ?? false,
      canAddTransactions: data['can_add_transactions'] as bool? ?? data['canAddTransactions'] as bool? ?? true,
      canCancelTransactions: data['can_cancel_transactions'] as bool? ?? data['canCancelTransactions'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'can_add_products': canAddProducts,
        'can_edit_products': canEditProducts,
        'can_remove_products': canRemoveProducts,
        'can_add_transactions': canAddTransactions,
        'can_cancel_transactions': canCancelTransactions,
      };

  MemberPermissions copyWith({
    bool? canAddProducts,
    bool? canEditProducts,
    bool? canRemoveProducts,
    bool? canAddTransactions,
    bool? canCancelTransactions,
  }) {
    return MemberPermissions(
      canAddProducts: canAddProducts ?? this.canAddProducts,
      canEditProducts: canEditProducts ?? this.canEditProducts,
      canRemoveProducts: canRemoveProducts ?? this.canRemoveProducts,
      canAddTransactions: canAddTransactions ?? this.canAddTransactions,
      canCancelTransactions: canCancelTransactions ?? this.canCancelTransactions,
    );
  }
}

/// A member of a hardware workspace.
class HardwareMember {
  final String? id; // hardware_members PK
  final String userId;
  final String email;
  final String fullName;
  final String role; // 'admin' | 'staff'
  final DateTime? joinedAt;
  final MemberPermissions permissions;

  const HardwareMember({
    this.id,
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    this.joinedAt,
    this.permissions = const MemberPermissions(),
  });

  factory HardwareMember.fromJson(Map<String, dynamic> data) {
    // Supabase joins may nest the user info under a 'users' key
    final userData = data['users'] as Map<String, dynamic>?;
    final email = userData?['email'] as String? ?? data['email'] as String? ?? '';
    final fullName = userData?['full_name'] as String? ?? data['full_name'] as String? ?? data['fullName'] as String? ?? email;

    return HardwareMember(
      id: data['id']?.toString(),
      userId: data['user_id'] as String? ?? '',
      email: email,
      fullName: fullName,
      role: data['role'] as String? ?? 'staff',
      joinedAt: _parseDate(data['joined_at']),
      permissions: MemberPermissions.fromMap(data),
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'role': role,
        ...permissions.toMap(),
      };

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  String get initials {
    final parts = fullName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase());
    final joined = parts.join();
    return joined.isEmpty
        ? (email.isNotEmpty ? email[0].toUpperCase() : 'U')
        : joined;
  }

  bool get isAdmin => role.toLowerCase() == 'admin';

  bool get canAddProducts => isAdmin || permissions.canAddProducts;
  bool get canEditProducts => isAdmin || permissions.canEditProducts;
  bool get canRemoveProducts => isAdmin || permissions.canRemoveProducts;
  bool get canAddTransactions => isAdmin || permissions.canAddTransactions;
  bool get canCancelTransactions => isAdmin || permissions.canCancelTransactions;
}

/// A hardware workspace — the top-level store context that groups users together.
class Hardware {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final DateTime? createdAt;
  final List<String> memberIds;
  final Map<String, HardwareMember> members;
  final List<String> invitedEmails;

  const Hardware({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    this.createdAt,
    required this.memberIds,
    required this.members,
    required this.invitedEmails,
  });

  /// Build from a Supabase row + separately loaded members & invites.
  factory Hardware.fromJson(
    Map<String, dynamic> data, {
    List<HardwareMember> membersList = const [],
    List<String> invites = const [],
  }) {
    final members = <String, HardwareMember>{};
    final memberIds = <String>[];
    for (final m in membersList) {
      members[m.userId] = m;
      memberIds.add(m.userId);
    }

    return Hardware(
      id: data['id']?.toString() ?? '',
      name: data['name'] as String? ?? 'Unnamed Hardware',
      description: data['description'] as String? ?? '',
      createdBy: data['created_by'] as String? ?? '',
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString())
          : null,
      memberIds: memberIds,
      members: members,
      invitedEmails: invites,
    );
  }

  int get memberCount => members.length;

  List<HardwareMember> get memberList {
    final list = members.values.toList();
    list.sort((a, b) {
      if (a.isAdmin && !b.isAdmin) return -1;
      if (!a.isAdmin && b.isAdmin) return 1;
      return a.fullName.compareTo(b.fullName);
    });
    return list;
  }
}
