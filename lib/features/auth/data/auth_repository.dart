import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/profile.dart';
import '../../../core/supabase/supabase_service.dart';

class AuthRepository {
  SupabaseClient get _client => SupabaseService.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign in with email + password
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign up with email + password, then create profile
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    final resp = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    if (resp.user != null) {
      _pendingUsername = username.trim().isEmpty
          ? 'Player${resp.user!.id.substring(0, 6)}'
          : username.trim();
      await createProfile(resp.user!.id);
    }
    return resp;
  }

  /// Send OTP to phone number (format: +1234567890)
  Future<void> sendOtp(String phone) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  /// Verify OTP and sign in
  Future<AuthResponse> verifyOtp(String phone, String otp) async {
    return await _client.auth.verifyOTP(
      phone: phone,
      token: otp,
      type: OtpType.sms,
    );
  }

  /// Sign up with phone — creates profile row after verification
  Future<void> signUp({
    required String phone,
    required String username,
  }) async {
    await _client.auth.signInWithOtp(phone: phone);
    // Store username temporarily for profile creation after OTP verify
    _pendingUsername = username;
  }

  String? _pendingUsername;

  /// Call after verifyOtp on the register flow
  Future<Profile> createProfile(String userId) async {
    final username = _pendingUsername ?? 'Player${userId.substring(0, 6)}';
    _pendingUsername = null;
    final now = DateTime.now();
    final data = {
      'id': userId,
      'username': username,
      'level': 1,
      'xp': 0,
      'xp_to_next': 1000,
      'created_at': now.toIso8601String(),
    };
    await _client.from('profiles').upsert(data);
    return Profile.fromJson({...data, 'phone': null, 'avatar_url': null});
  }

  Future<Profile?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<void> updateProfile(Profile profile) async {
    await _client
        .from('profiles')
        .update(profile.toJson())
        .eq('id', profile.id);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
