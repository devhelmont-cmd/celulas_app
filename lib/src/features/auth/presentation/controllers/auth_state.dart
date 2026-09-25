import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';

sealed class AuthState {}

class AuthInitialState extends AuthState {}

class AuthLoadingState extends AuthState {}

class AuthSuccessState extends AuthState {
  final UserEntity user;

  AuthSuccessState(this.user);
}

class AuthErrorState extends AuthState {
  final String message;

  AuthErrorState(this.message);
}

class AuthUnauthenticatedState extends AuthState {}
