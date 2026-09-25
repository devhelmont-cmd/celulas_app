import 'package:celulas_app/src/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:celulas_app/src/features/auth/domain/repositories/auth_repository.dart';

import '../../domain/entities/user_entity.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserEntity> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return await remoteDataSource.loginWithEmail(email, password);
  }

  @override
  Future<UserEntity> signUpWithEmail({
    required name,
    required email,
    required password,
  }) async {
    return await remoteDataSource.signUpWithEmail(
      name: name,
      email: email,
      password: password,
    );
  }

  @override
  Future<UserEntity> loginWithGoogle() async {
    return await remoteDataSource.loginWithGoogle();
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail({required email}) async {
    try {
      await remoteDataSource.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    return await remoteDataSource.getCurrentUser();
  }
}
