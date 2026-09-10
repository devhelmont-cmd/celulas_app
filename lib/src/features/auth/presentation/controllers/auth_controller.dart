import 'package:celulas_app/src/features/auth/domain/usecases/login_with_email.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/login_with_google.dart';
import 'package:celulas_app/src/features/auth/presentation/controllers/auth_state.dart';
import 'package:flutter/foundation.dart';

class AuthController extends ValueNotifier<AuthState> {
  final LoginWithEmailUseCase _loginWithEmailUseCase;
  final LoginWithGoogleUseCase _loginWithGoogleUseCase;

  AuthController({
    required LoginWithEmailUseCase loginWithEmailUseCase,
    required LoginWithGoogleUseCase loginWithGoogleUseCase,
  }) : _loginWithEmailUseCase = loginWithEmailUseCase,
       _loginWithGoogleUseCase = loginWithGoogleUseCase,
       super(AuthInitialState());

  Future<void> loginWithEmail(String email, String password) async {
    value = AuthLoadingState();
    try {
      final user = await _loginWithEmailUseCase(
        email: email,
        password: password,
      );
      value = AuthSuccessState(user);
    } catch (e) {
      value = AuthErrorState(e.toString().replaceAll('Exception', ''));
    }
  }

  Future<void> logingWithGoogle() async {
    value = AuthLoadingState();
    try {
      final user = await _loginWithGoogleUseCase();
      value = AuthSuccessState(user);
    } catch (e) {
      value = AuthErrorState(e.toString().replaceAll('Exception', ''));
    }
  }
}
