import 'package:dartz/dartz.dart';
import '../../../core/failures.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/user_entity.dart';
import 'supabase_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource dataSource;

  AuthRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, UserEntity>> signInWithEmail(String email, String password) async {
    try {
      final user = await dataSource.signInWithEmail(email, password);
      return Right(user);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signUpWithEmail(String email, String password) async {
    try {
      final user = await dataSource.signUpWithEmail(email, password);
      return Right(user);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await dataSource.signOut();
      return const Right(null);
    } on Failure catch (e) {
      return Left(e);
    } catch (e) {
      return const Left(ServerFailure('Logout failed'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final user = await dataSource.getCurrentUser();
      if (user != null) {
        return Right(user);
      } else {
        return const Left(AuthFailure('No user logged in'));
      }
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<UserEntity?> get authStateChanges => dataSource.authStateChanges;
}
