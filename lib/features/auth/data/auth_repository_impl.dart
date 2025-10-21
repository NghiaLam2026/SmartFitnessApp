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
        final Map<String, dynamic> payload = {
          'user_id': user.id,
          'updated_at': DateTime.now().toIso8601String(),
        };
        final metaName = (user.userMetadata?['display_name'] as String?)?.trim();
        final effectiveName = ((displayName ?? '').trim().isNotEmpty)
            ? displayName!.trim()
            : (metaName ?? '');
        if (effectiveName.isNotEmpty) {
          payload['display_name'] = effectiveName;
        }
        if ((zip ?? '').trim().isNotEmpty) {
          payload['zip_code'] = zip!.trim();
        }
        await _client.from('profiles').upsert(payload);
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
      data: {
        if ((displayName ?? '').trim().isNotEmpty) 'display_name': displayName!.trim(),
        if ((zip ?? '').trim().isNotEmpty) 'zip_code': zip!.trim(),
      },
    );

    // Step 2: Bootstrap profile and dashboard prefs via SECURITY DEFINER RPC
    // This avoids RLS issues and works even before first login.
    final newUserId = response.user?.id;
    if (newUserId != null) {
      try {
        await _client.rpc('post_auth_bootstrap', params: {
          'p_user_id': newUserId,
          'p_display_name': displayName ?? '',
          'p_zip': zip ?? '',
        });
      } catch (_) {
        // Non-fatal: UI will still work; profile will be ensured on first sign-in as a fallback
      }
    }

    print('🆕 New user created: ${response.user?.id}');
    return response;
  }

  // 🔹 Sign out
  @override
  Future<void> signOut({bool global = false}) async {
    await _client.auth.signOut(scope: global ? SignOutScope.global : SignOutScope.local);
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

  // 🔹 Reset password (magic link)
  @override
  Future<void> resetPassword({required String email, String? redirectTo}) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectTo,
    );
  }
}


