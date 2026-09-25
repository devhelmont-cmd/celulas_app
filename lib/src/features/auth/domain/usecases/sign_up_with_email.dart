import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/auth/domain/repositories/auth_repository.dart';

class SignUpWithEmailUseCase {
  final AuthRepository _repository;

  SignUpWithEmailUseCase(this._repository);

  Future<UserEntity> call({
    required String name,
    required String email,
    required String password,
  }) async {
    return await _repository.signUpWithEmail(
      name: name,
      email: email,
      password: password,
    );
  }
}
