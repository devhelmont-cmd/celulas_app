import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> loginWithEmail({
    required String email,
    required String password,
  });

  Future<UserEntity> signUpWithEmail({
    required name,
    required email,
    required password,
  });

  Future<UserEntity> loginWithGoogle();

  Future<void> signOut();

  Future<UserEntity?> getCurrentUser();

  Future<void> sendPasswordResetEmail({required String email});
}
