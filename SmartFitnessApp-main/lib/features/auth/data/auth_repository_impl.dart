import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _client;
  AuthRepositoryImpl({SupabaseClient? client}) : _client = client ?? supabase;

  // 🔹 User sign-in
  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
    String? displayName,
    String? zip,

  }) async {
    // Step 1: Sign in the user
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    // Step 2: Once logged in, insert or update their profile
    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        await _client.from('profiles').upsert({
          'user_id': user.id,
          'display_name': displayName ?? '', // optional, can be filled later in profile page
          'zip_code': zip ?? '',
          'updated_at': DateTime.now().toIso8601String(),
        });
        print('✅ Profile ensured for ${user.id}');
      } catch (e) {
        print('❌ Profile upsert failed: $e');
      }
    }

    return response;
  }

  // 🔹 User sign-up
  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
    String? zip,
  }) async {
    // Step 1: Create a new account
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );

    // Step 2: Do NOT insert profile here (RLS will block it)
    // Profile will be created automatically when the user signs in later.

    print('🆕 New user created: ${response.user?.id}');
    return response;
  }

  // 🔹 Sign out
  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // 🔹 Current session getter
  @override
  Session? currentSession() => _client.auth.currentSession;

  // 🔹 Current user getter
  @override
  User? currentUser() => _client.auth.currentUser;

  // 🔹 Resend confirmation email
  @override
  Future<void> resendEmailConfirmation({required String email}) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
    );
  }
}


