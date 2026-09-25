import 'package:celulas_app/src/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:celulas_app/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:celulas_app/src/features/auth/data/repositories/user_repository_impl.dart';
import 'package:celulas_app/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/get_current_user.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/login_with_email.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/login_with_google.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/send_password_reset_email.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/sign_out.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/sign_up_with_email.dart';
import 'package:celulas_app/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../features/auth/domain/repositories/i_user_repository.dart';

final getIt = GetIt.instance;

Future<void> initInjection() async {
  // -----------------------------------------------------------------------
  // External / SDKs
  // -----------------------------------------------------------------------
  getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  getIt.registerLazySingleton<GoogleSignIn>(
    () => GoogleSignIn(
      clientId:
          '695992616108-8pgag7mr0sgb6alqnjtubk15t8aj6q5e.apps.googleusercontent.com',
    ),
  );

  // -----------------------------------------------------------------------
  // Firebase
  // -----------------------------------------------------------------------
  getIt.registerLazySingleton<FirebaseFirestore>(
    () => FirebaseFirestore.instance,
  );

  // -----------------------------------------------------------------------
  // DataSources
  // -----------------------------------------------------------------------
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      firebaseAuth: getIt<FirebaseAuth>(),
      googleSignIn: getIt<GoogleSignIn>(),
      firestore: getIt<FirebaseFirestore>(),
    ),
  );

  // -----------------------------------------------------------------------
  // Repositories
  // -----------------------------------------------------------------------
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: getIt<AuthRemoteDataSource>()),
  );
  getIt.registerLazySingleton<IUserRepository>(
    () => UserRepositoryImpl(getIt<FirebaseFirestore>()),
  );

  // -----------------------------------------------------------------------
  // UseCases
  // -----------------------------------------------------------------------
  getIt.registerLazySingleton<LoginWithEmailUseCase>(
    () => LoginWithEmailUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<SignUpWithEmailUseCase>(
    () => SignUpWithEmailUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<LoginWithGoogleUseCase>(
    () => LoginWithGoogleUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<SignOutUseCase>(
    () => SignOutUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<SendPasswordResetEmailUseCase>(
    () => SendPasswordResetEmailUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<GetCurrentUserUseCase>(
    () => GetCurrentUserUseCase(getIt<AuthRepository>()),
  );

  // -----------------------------------------------------------------------
  // Controllers / Presenters
  // -----------------------------------------------------------------------
  getIt.registerLazySingleton<AuthController>(
    () => AuthController(
      loginWithEmailUseCase: getIt<LoginWithEmailUseCase>(),
      signUpWithEmailUseCase: getIt<SignUpWithEmailUseCase>(),
      loginWithGoogleUseCase: getIt<LoginWithGoogleUseCase>(),
      signOutUseCase: getIt<SignOutUseCase>(),
      sendPasswordResetEmailUseCase: getIt<SendPasswordResetEmailUseCase>(),
      getCurrentUserUseCase: getIt<GetCurrentUserUseCase>(),
    ),
  );
}
