import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/failures.dart';
import '../../auth/domain/user_entity.dart';

abstract class AuthRemoteDataSource {
  Future<UserEntity> signInWithEmail(String email, String password);
  Future<UserEntity> signUpWithEmail(String email, String password);
  Future<void> signOut();
  Future<UserEntity?> getCurrentUser();
  Stream<UserEntity?> get authStateChanges;
}

class SupabaseAuthDataSource implements AuthRemoteDataSource {
  final SupabaseClient client;

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
      final response = await client.auth.signUp(email: email, password: password);
      if (response.user == null) throw const AuthFailure('Sign up failed: No user returned');
      return UserEntity(id: response.user!.id, email: response.user!.email ?? '');
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
    final user = client.auth.currentUser;
    if (user == null) return null;
    return UserEntity(id: user.id, email: user.email ?? '');
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
