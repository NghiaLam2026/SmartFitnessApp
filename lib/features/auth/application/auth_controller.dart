import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/auth_repository.dart';
import '../data/auth_repository_impl.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

class AuthState {
  final bool loading;
  final User? user;
  final String? error;
  const AuthState({this.loading = false, this.user, this.error});

  AuthState copyWith({bool? loading, User? user, String? error}) =>
      AuthState(loading: loading ?? this.loading, user: user ?? this.user, error: error);
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AuthState> {
  final Ref _ref;
  AuthController(this._ref) : super(AuthState(user: supabase.auth.currentUser)) {
    // Listen to auth state changes and update
    supabase.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      state = state.copyWith(user: session?.user, loading: false);
    });
  }

  Future<void> signIn(BuildContext context, {required String email, required String password}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _ref.read(authRepositoryProvider).signInWithEmail(email: email, password: password);
      final user = res.user ?? supabase.auth.currentUser;
      state = state.copyWith(loading: false, user: user);
      if (context.mounted && user != null) context.go('/home');
    } on AuthException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Unexpected error');
      debugPrint(e.toString());
    }
  }

  Future<void> signUp(BuildContext context,
      {required String email, required String password, String? displayName, String? zip}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _ref.read(authRepositoryProvider)
          .signUpWithEmail(email: email, password: password, displayName: displayName, zip: zip);
      // Ensure users are not auto-logged-in after sign-up
      final session = _ref.read(authRepositoryProvider).currentSession();
      if (session != null) {
        await _ref.read(authRepositoryProvider).signOut();
      }
      // Stop loading and clear any user
      state = state.copyWith(loading: false, user: null);
      if (context.mounted) context.go('/login');
    } on AuthException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Unexpected error');
      debugPrint(e.toString());
    }
  }

  Future<void> signOut(BuildContext context) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _ref.read(authRepositoryProvider).signOut();
      state = state.copyWith(loading: false, user: null);
      if (context.mounted) context.go('/login');
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Unexpected error');
    }
  }

  Future<bool> resendEmailConfirmation(String email) async {
    try {
      await _ref.read(authRepositoryProvider).resendEmailConfirmation(email: email);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Unexpected error');
      return false;
    }
  }
}


