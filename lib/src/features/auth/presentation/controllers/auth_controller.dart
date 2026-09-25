import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/domain/repositories/i_user_repository.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/get_current_user.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/login_with_email.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/login_with_google.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/send_password_reset_email.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/sign_out.dart';
import 'package:celulas_app/src/features/auth/presentation/controllers/auth_state.dart';
import 'package:flutter/foundation.dart';

import '../../domain/usecases/sign_up_with_email.dart';

class AuthController extends ValueNotifier<AuthState> {
  final LoginWithEmailUseCase _loginWithEmailUseCase;
  final SignUpWithEmailUseCase _signUpWithEmailUseCase;
  final LoginWithGoogleUseCase _loginWithGoogleUseCase;
  final SignOutUseCase _signOutUseCase;
  final SendPasswordResetEmailUseCase _sendPasswordResetEmailUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;

  AuthController({
    required LoginWithEmailUseCase loginWithEmailUseCase,
    required SignUpWithEmailUseCase signUpWithEmailUseCase,
    required LoginWithGoogleUseCase loginWithGoogleUseCase,
    required SignOutUseCase signOutUseCase,
    required SendPasswordResetEmailUseCase sendPasswordResetEmailUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
  }) : _loginWithEmailUseCase = loginWithEmailUseCase,
       _signUpWithEmailUseCase = signUpWithEmailUseCase,
       _loginWithGoogleUseCase = loginWithGoogleUseCase,
       _signOutUseCase = signOutUseCase,
       _sendPasswordResetEmailUseCase = sendPasswordResetEmailUseCase,
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

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    value = AuthLoadingState();

    try {
      final user = await _signUpWithEmailUseCase(
        name: name,
        email: email,
        password: password,
      );
      value = AuthSuccessState(user);
    } catch (e) {
      final cleanError = e.toString().replaceAll('Exception: ', '');
      value = AuthErrorState(cleanError);
    }
  }

  Future<void> loginWithGoogle() async {
    value = AuthLoadingState();
    try {
      final rawUser = await _loginWithGoogleUseCase();
      if (rawUser != null) {
        final syncedUser = await getIt<IUserRepository>().syncUserData(rawUser);
        value = AuthSuccessState(syncedUser);
      } else {
        value = AuthInitialState();
      }
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

  Future<void> sendPasswordResetEmail(String email) async {
    value = AuthLoadingState();
    try {
      await _sendPasswordResetEmailUseCase(email);
      value = AuthInitialState();
    } catch (e) {
      value = AuthErrorState(e.toString().replaceAll('Exception: ', ' '));
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
      final cleanError = e.toString().replaceAll('Exception: ', '');
      value = AuthErrorState(cleanError);
    }
  }
}
