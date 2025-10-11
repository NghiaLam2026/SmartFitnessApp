import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _client;
  AuthRepositoryImpl({SupabaseClient? client}) : _client = client ?? supabase;

  @override
  Future<AuthResponse> signInWithEmail({required String email, required String password}) async {
    return await _client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
    String? zip,
  }) async {
    final response = await _client.auth.signUp(email: email.trim(), password: password);

    // Bootstrap profile if sign-up succeeded
    final user = response.user;
    if (user != null) {
      // Prefer calling the bootstrap function if present; fall back to direct upsert
      try {
        await _client.rpc('post_auth_bootstrap', params: {
          'p_user_id': user.id,
          if (displayName != null && displayName.isNotEmpty) 'p_display_name': displayName,
          if (zip != null && zip.isNotEmpty) 'p_zip': zip,
        });
      } catch (_) {
        await _client.from('profiles').upsert({
          'user_id': user.id,
          if (displayName != null && displayName.isNotEmpty) 'display_name': displayName,
          if (zip != null && zip.isNotEmpty) 'zip_code': zip,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }
    return response;
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Session? currentSession() => _client.auth.currentSession;

  @override
  User? currentUser() => _client.auth.currentUser;

  @override
  Future<void> resendEmailConfirmation({required String email}) async {
    // Supabase v2: use auth.resend(ResendType.signup, email: ...)
    await _client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
    );
  }
}


