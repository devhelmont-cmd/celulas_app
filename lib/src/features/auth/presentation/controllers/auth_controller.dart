import 'package:celulas_app/src/features/auth/domain/usecases/get_current_user.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/login_with_email.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/login_with_google.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/sign_out.dart';
import 'package:celulas_app/src/features/auth/presentation/controllers/auth_state.dart';
import 'package:flutter/foundation.dart';

class AuthController extends ValueNotifier<AuthState> {
  final LoginWithEmailUseCase _loginWithEmailUseCase;
  final LoginWithGoogleUseCase _loginWithGoogleUseCase;
  final SignOutUseCase _signOutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;

  AuthController({
    required LoginWithEmailUseCase loginWithEmailUseCase,
    required LoginWithGoogleUseCase loginWithGoogleUseCase,
    required SignOutUseCase signOutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
  }) : _loginWithEmailUseCase = loginWithEmailUseCase,
       _loginWithGoogleUseCase = loginWithGoogleUseCase,
       _signOutUseCase = signOutUseCase,
       _getCurrentUserUseCase = getCurrentUserUseCase,
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

  Future<void> signOut() async {
    value = AuthLoadingState();
    try {
      await _signOutUseCase();
      value = AuthInitialState();
    } catch (e) {
      value = AuthErrorState(e.toString());
    }
  }

  Future<void> checkCurrentUser() async {
    value = AuthLoadingState();
    try {
      final user = await _getCurrentUserUseCase();
      if (user != null) {
        value = AuthSuccessState(user);
      } else {
        value = AuthInitialState();
      }
    } catch (e) {
      value = AuthInitialState();
    }
  }
}
