import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/auth/domain/repositories/auth_repository.dart';

class LoginWithEmailUseCase {
  final AuthRepository repository;

  LoginWithEmailUseCase(this.repository);

  Future<UserEntity> call({
    required String email,
    required String password,
  }) async {
    //Validações de regra de negócios adicionais podem ser inseridas aqui
    return await repository.loginWithEmail(email: email, password: password);
  }
}
