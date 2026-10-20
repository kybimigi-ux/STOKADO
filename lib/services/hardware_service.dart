import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hardware.dart';
import 'auth_service.dart';

/// Supabase-backed service for hardware workspace CRUD operations.
class HardwareService {
  HardwareService._();
  static final HardwareService instance = HardwareService._();

  static final SupabaseClient _client = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Create a new hardware workspace. The creator is automatically added as admin.
  Future<Hardware> createHardware({
    required String name,
    String description = '',
  }) async {
    final auth = AuthService.instance;
    final uid = auth.userId!;
    final email = auth.email.toLowerCase().trim();
    final fullName = auth.displayName;

    // 1. Insert hardware row
    final hwData = await _client
        .from('hardwares')
        .insert({
          'name': name.trim(),
          'description': description.trim(),
          'created_by': uid,
        })
        .select()
        .single();

    final hwId = hwData['id'] as String;

    // 2. Add creator as admin member
    await _client.from('hardware_members').insert({
      'hardware_id': hwId,
      'user_id': uid,
      'role': 'admin',
    });

    // Build the Hardware object from the inserted data
    final member = HardwareMember(
      userId: uid,
      email: email,
      fullName: fullName,
      role: 'admin',
      joinedAt: DateTime.now(),
    );
    return Hardware.fromJson(
      hwData,
      membersList: [member],
    );
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Returns all hardwares the current user belongs to.
  Future<List<Hardware>> getMyHardwares() async {
    final uid = AuthService.instance.userId;
    final email = AuthService.instance.email.toLowerCase().trim();
    if (uid == null) return [];

    // Accept any pending invites first
    await _acceptPendingInvites(uid: uid, email: email);

    try {
      // Get hardware_ids this user is a member of
      final memberRows = await _client
          .from('hardware_members')
          .select('hardware_id')
          .eq('user_id', uid);

      if ((memberRows as List).isEmpty) return [];

      final hwIds = memberRows
          .map((r) => r['hardware_id'] as String)
          .toList();

      // Fetch all matching hardware rows
      final hwRows = await _client
          .from('hardwares')
          .select()
          .inFilter('id', hwIds)
          .order('created_at', ascending: false);

      // Build Hardware objects with members + invites
      final List<Hardware> result = [];
      for (final hw in (hwRows as List)) {
        final hwId = hw['id'] as String;
        final hardware = await _buildHardware(hw as Map<String, dynamic>, hwId);
        result.add(hardware);
      }
      return result;
    } catch (e) {
      debugPrint('[HardwareService] getMyHardwares error: $e');
      return [];
    }
  }

  /// Auto-accept pending email invites.
  Future<void> _acceptPendingInvites({
    required String uid,
    required String email,
  }) async {
    if (email.isEmpty) return;
    try {
      final inviteRows = await _client
          .from('hardware_invites')
          .select('hardware_id')
          .eq('email', email);

      for (final row in (inviteRows as List)) {
        final hwId = row['hardware_id'] as String;

        // Check if already a member
        final existing = await _client
            .from('hardware_members')
            .select('id')
            .eq('hardware_id', hwId)
            .eq('user_id', uid)
            .maybeSingle();

        if (existing == null) {
          await _client.from('hardware_members').insert({
            'hardware_id': hwId,
            'user_id': uid,
            'role': 'staff',
          });
        }
        // Remove the invite
        await _client
            .from('hardware_invites')
            .delete()
            .eq('hardware_id', hwId)
            .eq('email', email);

        debugPrint('[HardwareService] Auto-accepted invite to hw $hwId');
      }
    } catch (e) {
      debugPrint('[HardwareService] _acceptPendingInvites error: $e');
    }
  }

  /// Fetch a single hardware workspace by ID.
  Future<Hardware?> getById(String hardwareId) async {
    try {
      final hw = await _client
          .from('hardwares')
          .select()
          .eq('id', hardwareId)
          .maybeSingle();
      if (hw == null) return null;
      return await _buildHardware(hw, hardwareId);
    } catch (e) {
      debugPrint('[HardwareService] getById error: $e');
      return null;
    }
  }

  /// Loads members + invites for a hardware row and constructs Hardware.
  Future<Hardware> _buildHardware(
      Map<String, dynamic> hw, String hwId) async {
    // Load members with their user profiles
    final memberRows = await _client
        .from('hardware_members')
        .select('*, users(email, full_name)')
        .eq('hardware_id', hwId);

    final members = (memberRows as List)
        .map((r) => HardwareMember.fromJson(r as Map<String, dynamic>))
        .toList();

    // Load pending invites
    final inviteRows = await _client
        .from('hardware_invites')
        .select('email')
        .eq('hardware_id', hwId);

    final invites = (inviteRows as List)
        .map((r) => r['email'] as String)
        .toList();

    return Hardware.fromJson(hw, membersList: members, invites: invites);
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  /// Update a hardware workspace name and description.
  Future<void> updateHardware(
    String hardwareId, {
    required String name,
    String description = '',
  }) async {
    await _client.from('hardwares').update({
      'name': name.trim(),
      'description': description.trim(),
    }).eq('id', hardwareId);
  }

  /// Invite a member by email.
  Future<void> inviteMemberByEmail(String hardwareId, String email) async {
    final normalizedEmail = email.toLowerCase().trim();
    await _client.from('hardware_invites').upsert({
      'hardware_id': hardwareId,
      'email': normalizedEmail,
    });
  }

  /// Remove a pending email invite.
  Future<void> removeInvite(String hardwareId, String email) async {
    await _client
        .from('hardware_invites')
        .delete()
        .eq('hardware_id', hardwareId)
        .eq('email', email.toLowerCase().trim());
  }

  /// Remove an existing member from a workspace.
  Future<void> removeMember(String hardwareId, String userId) async {
    await _client
        .from('hardware_members')
        .delete()
        .eq('hardware_id', hardwareId)
        .eq('user_id', userId);
  }

  /// Update permissions for a specific member in a hardware workspace.
  Future<void> updateMemberPermissions(
    String hardwareId,
    String userId,
    MemberPermissions permissions,
  ) async {
    await _client
        .from('hardware_members')
        .update(permissions.toMap())
        .eq('hardware_id', hardwareId)
        .eq('user_id', userId);
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  /// Permanently delete a hardware workspace.
  Future<void> deleteHardware(String hardwareId) async {
    await _client.from('hardwares').delete().eq('id', hardwareId);
  }
}
