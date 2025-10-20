import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  Future<AuthResponse> signInWithEmail({required String email, required String password});
  Future<AuthResponse> signUpWithEmail({required String email, required String password, String? displayName, String? zip});
  Future<void> signOut();
  Session? currentSession();
  User? currentUser();
  Future<void> resendEmailConfirmation({required String email});
}


