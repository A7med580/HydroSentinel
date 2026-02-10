import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/failures.dart';
import '../../auth/domain/user_entity.dart';

abstract class AuthRemoteDataSource {
  Future<UserEntity> signInWithEmail(String email, String password);
  Future<UserEntity> signUpWithEmail(String email, String password);
  Future<void> signOut();
  Future<UserEntity?> getCurrentUser();
  Future<void> resetPasswordForEmail(String email);
  Stream<UserEntity?> get authStateChanges;
}

class SupabaseAuthDataSource implements AuthRemoteDataSource {
  final SupabaseClient client;

  // Getter to expose client to repository for advanced checks (like getUser)
  SupabaseClient get supabaseClient => client;

  SupabaseAuthDataSource(this.client);

  @override
  Future<UserEntity> signInWithEmail(String email, String password) async {
    try {
      final response = await client.auth.signInWithPassword(email: email, password: password);
      if (response.user == null) throw const AuthFailure('Login failed: No user returned');
      return UserEntity(id: response.user!.id, email: response.user!.email ?? '');
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure(e.toString());
    }
  }

  @override
  Future<UserEntity> signUpWithEmail(String email, String password) async {
    try {
      final response = await client.auth.signUp(
        email: email, 
        password: password,
        emailRedirectTo: 'hydrosentinel://login-callback',
      );
      if (response.user == null) throw const AuthFailure('Sign up failed: No user returned');
      return UserEntity(id: response.user!.id, email: response.user!.email ?? '');
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure(e.toString());
    }
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
     try {
       await client.auth.resetPasswordForEmail(email);
     } on AuthException catch (e) {
       throw AuthFailure(e.message);
     } catch (e) {
       throw AuthFailure(e.toString());
     }
  }

  @override
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      throw const AuthFailure('Logout failed');
    }
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    try {
      // Use getUser() to verify the session with the server
      final response = await client.auth.getUser();
      final user = response.user;
      if (user == null) return null;
      return UserEntity(id: user.id, email: user.email ?? '');
    } catch (e) {
      // If server check fails (e.g. invalid session), return null so repo can handle logout
      return null;
    }
  }

  @override
  Stream<UserEntity?> get authStateChanges {
    return client.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      if (user == null) return null;
      return UserEntity(id: user.id, email: user.email ?? '');
    });
  }
}
