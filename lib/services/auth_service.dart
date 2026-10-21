import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'hardware_context.dart';
import 'navigation_service.dart';

/// Thin wrapper around Supabase Auth + database that every screen can import
/// without coupling directly to the Supabase SDK.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static const _kSessionLoginTime = 'auth_session_login_time';
  static const _kCachedRole = 'auth_cached_role';

  /// Initialize auth (listen to auth state changes).
  Future<void> init() async {
    // Listen to Supabase auth state changes to keep role cache in sync
    _client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        _resetRole();
      } else if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        // Refresh role in background
        final uid = _client.auth.currentUser?.id;
        if (uid != null) unawaited(_doFetchUserRole(uid));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Reactive session stream
  // ---------------------------------------------------------------------------

  /// Emits whenever the auth state changes (sign-in, sign-out, token refresh).
  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// The currently authenticated Supabase user, or `null` if signed out.
  User? get currentUser => _client.auth.currentUser;

  /// Convenience — the user's display name (from user_metadata).
  String get displayName =>
      (currentUser?.userMetadata?['full_name'] as String?)?.trim().isNotEmpty == true
          ? currentUser!.userMetadata!['full_name'] as String
          : 'User';

  /// Convenience — the user's email.
  String get email => currentUser?.email ?? '';

  /// Convenience — the current user's UID.
  String? get userId => currentUser?.id;

  String? _cachedRole;
  bool _isRoleLoading = false;
  Future<String?>? _roleFetchFuture;

  /// Cached user role ('Admin', 'Manager', 'Staff'), or null if not yet loaded.
  String? get userRole => _cachedRole;

  /// True while a role fetch is in flight.
  bool get isRoleLoading => _isRoleLoading;

  void _resetRole() {
    _cachedRole = null;
    _isRoleLoading = false;
    _roleFetchFuture = null;
    notifyListeners();
  }

  /// Checks if the session is still within the 1-week (7-day) limit.
  Future<bool> checkSessionValidity() async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final loginTimeMs = prefs.getInt(_kSessionLoginTime);

      if (loginTimeMs == null) {
        await prefs.setInt(
            _kSessionLoginTime, DateTime.now().millisecondsSinceEpoch);
        return true;
      }

      final loginDate = DateTime.fromMillisecondsSinceEpoch(loginTimeMs);
      final difference = DateTime.now().difference(loginDate);

      if (difference.inDays >= 7) {
        debugPrint(
            '[AuthService] 1-week session expired (${difference.inDays} days old). Signing out.');
        await signOut();
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[AuthService] checkSessionValidity error: $e');
      return true;
    }
  }

  /// Fetch user role from the `users` table.
  Future<String?> fetchUserRole({bool forceRefresh = false}) async {
    final uid = userId;
    if (uid == null) {
      _resetRole();
      return null;
    }

    if (!forceRefresh && _cachedRole != null) return _cachedRole;

    // Load from local preferences first to avoid flicker
    if (!forceRefresh && _cachedRole == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final local = prefs.getString(_kCachedRole);
        if (local != null && local.isNotEmpty) {
          _cachedRole = local;
        }
      } catch (_) {}
    }

    if (_roleFetchFuture != null) return _roleFetchFuture!;

    _roleFetchFuture = _doFetchUserRole(uid);
    try {
      final role = await _roleFetchFuture!;
      return role;
    } finally {
      _roleFetchFuture = null;
    }
  }

  Future<String?> _doFetchUserRole(String uid) async {
    _isRoleLoading = true;
    notifyListeners();

    try {
      final data = await _client
          .from('users')
          .select('role')
          .eq('id', uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));

      if (data != null && data['role'] != null) {
        final r = data['role'].toString().trim();
        _cachedRole = r.isNotEmpty
            ? r[0].toUpperCase() + r.substring(1).toLowerCase()
            : null;
        if (_cachedRole != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kCachedRole, _cachedRole!);
        }
      } else {
        // Demo account fallback
        if (email == _demoAdminEmail) {
          _cachedRole = 'Admin';
        } else if (email == _demoStaffEmail) {
          _cachedRole = 'Staff';
        } else {
          _cachedRole = null;
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Could not fetch user role: $e');
      if (_cachedRole == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          _cachedRole = prefs.getString(_kCachedRole);
        } catch (_) {}
        if (_cachedRole == null) {
          if (email == _demoAdminEmail) {
            _cachedRole = 'Admin';
          } else if (email == _demoStaffEmail) {
            _cachedRole = 'Staff';
          }
        }
      }
    } finally {
      _isRoleLoading = false;
      notifyListeners();
    }

    return _cachedRole;
  }

  /// True if the user has signed up but has not yet been assigned a role.
  bool get isPending =>
      currentUser != null && _cachedRole == null && !_isRoleLoading;

  /// Check if the logged in user is an Admin.
  bool get isAdmin => (_cachedRole ?? '').toLowerCase() == 'admin';

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Update user's role in the `users` table (Admin action).
  Future<void> updateUserRole(String targetUserId, String newRole) async {
    final formattedRole = newRole.toLowerCase();
    await _client
        .from('users')
        .update({'role': formattedRole})
        .eq('id', targetUserId)
        .timeout(const Duration(seconds: 8));
    if (targetUserId == userId) {
      _cachedRole =
          formattedRole[0].toUpperCase() + formattedRole.substring(1);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kCachedRole, _cachedRole!);
      } catch (_) {}
      notifyListeners();
    }
  }

  /// Update display name / profile info.
  Future<void> updateProfile({required String fullName}) async {
    final uid = userId;
    if (uid != null) {
      // 1. Update Supabase Auth user metadata
      await _client.auth.updateUser(
        UserAttributes(data: {'full_name': fullName}),
      ).timeout(const Duration(seconds: 8));
      // 2. Update users table
      await _client.from('users').upsert({
        'id': uid,
        'full_name': fullName,
        'email': email,
        'role': (_cachedRole ?? 'Staff').toLowerCase(),
      }).timeout(const Duration(seconds: 8));
      notifyListeners();
    }
  }

  /// Update user password.
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    ).timeout(const Duration(seconds: 8));
  }

  /// Create a new account with email, password and a display name.
  /// Also inserts/upserts a row into the `users` table.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String role = 'staff',
  }) async {
    _resetRole();

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    final user = response.user;
    if (user != null) {
      String assignedRole = role.toLowerCase().trim();
      if (assignedRole.isEmpty) assignedRole = 'staff';

      // The DB trigger auto-inserts the user row, but we upsert to set role
      try {
        await _client.from('users').upsert({
          'id': user.id,
          'full_name': fullName,
          'email': email,
          'role': assignedRole,
        }).timeout(const Duration(seconds: 8));

        final formatted = assignedRole[0].toUpperCase() +
            assignedRole.substring(1).toLowerCase();
        _cachedRole = formatted;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(
              _kSessionLoginTime, DateTime.now().millisecondsSinceEpoch);
          await prefs.setString(_kCachedRole, formatted);
        } catch (_) {}
      } catch (e) {
        debugPrint('[AuthService] Failed to create user document: $e');
      }

      notifyListeners();
    }

    return response;
  }

  /// Sign in with email & password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    _resetRole();

    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    ).timeout(const Duration(seconds: 10));

    if (response.user != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
            _kSessionLoginTime, DateTime.now().millisecondsSinceEpoch);
      } catch (_) {}
      await fetchUserRole(forceRefresh: true);
    }

    return response;
  }

  /// End the current session.
  Future<void> signOut() async {
    HardwareContext.instance.clearActiveHardware();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSessionLoginTime);
      await prefs.remove(_kCachedRole);
    } catch (_) {}
    try {
      await _client.auth.signOut().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[AuthService] signOut error: $e');
    }
    _resetRole();

    NavigationService.popToRoot();
  }

  // ---------------------------------------------------------------------------
  // Demo Login
  // ---------------------------------------------------------------------------

  static const _demoAdminEmail = 'demo-admin@stokado.app';
  static const _demoStaffEmail = 'demo-staff@stokado.app';
  static const _demoAdminPassword = 'DemoAdmin123!';
  static const _demoStaffPassword = 'DemoStaff123!';

  /// Sign in as a demo account. Auto-creates the account if it doesn't exist.
  Future<void> signInDemo({required String role}) async {
    final demoEmail = role == 'admin' ? _demoAdminEmail : _demoStaffEmail;
    final demoPassword =
        role == 'admin' ? _demoAdminPassword : _demoStaffPassword;
    try {
      await signIn(email: demoEmail, password: demoPassword);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid') || msg.contains('not found')) {
        await _createDemoAccount(
            email: demoEmail, password: demoPassword, role: role);
      } else if (msg.contains('not confirmed') || msg.contains('unconfirmed')) {
        throw const AuthException(
          'Demo account email is not confirmed in Supabase. Please run the Demo Accounts SQL script in your Supabase SQL editor.',
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> _createDemoAccount({
    required String email,
    required String password,
    required String role,
  }) async {
    _resetRole();
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': role == 'admin' ? 'Demo Admin' : 'Demo Staff'},
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException(
          'Could not create demo account. Please run the Demo Accounts SQL script in your Supabase SQL editor.',
        );
      }

      if (response.session != null) {
        final fullName = role == 'admin' ? 'Demo Admin' : 'Demo Staff';
        try {
          await _client.from('users').upsert({
            'id': user.id,
            'full_name': fullName,
            'email': email,
            'role': role,
            'is_demo': true,
          }).timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('[AuthService] Demo user profile upsert error: $e');
        }
        _cachedRole = role == 'admin' ? 'Admin' : 'Staff';
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(
              _kSessionLoginTime, DateTime.now().millisecondsSinceEpoch);
          await prefs.setString(_kCachedRole, _cachedRole!);
        } catch (_) {}
        notifyListeners();
      } else {
        throw const AuthException(
          'Email confirmation is enabled in your Supabase project. '
          'Please run the Demo Accounts SQL script in your Supabase SQL editor to create pre-confirmed demo accounts, or disable "Confirm email" under Authentication -> Providers -> Email.',
        );
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('rate limit')) {
        throw const AuthException(
          'Supabase email rate limit exceeded. Please run the Demo Accounts SQL script in the Supabase SQL editor (or disable "Confirm email" in Supabase Auth settings).',
        );
      }
      rethrow;
    }
  }

  /// Fetch all users from the `users` table (admin usage).
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final data = await _client
        .from('users')
        .select()
        .timeout(const Duration(seconds: 10));
    return List<Map<String, dynamic>>.from(data as List);
  }
}