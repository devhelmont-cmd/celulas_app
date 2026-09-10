import 'package:celulas_app/src/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:celulas_app/src/features/auth/domain/repositories/auth_repository.dart';

import '../../domain/entities/user_entity.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl(this.remoteDataSource);

  @override
  Future<UserEntity> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return await remoteDataSource.loginWithEmail(email, password);
  }

  @override
  Future<UserEntity> loginWithGoogle() async {
    return await remoteDataSource.loginWithGoogle();
  }

  @override
  Future<void> logout() async {
    // TODO: implementação do logout no datasource
  }
}
