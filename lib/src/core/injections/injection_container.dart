import 'package:celulas_app/src/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:celulas_app/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:celulas_app/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/get_current_user.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/login_with_email.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/login_with_google.dart';
import 'package:celulas_app/src/features/auth/domain/usecases/sign_out.dart';
import 'package:celulas_app/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  // DataSources
  // -----------------------------------------------------------------------
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      firebaseAuth: getIt<FirebaseAuth>(),
      googleSignIn: getIt<GoogleSignIn>(),
    ),
  );

  // -----------------------------------------------------------------------
  // Repositories
  // -----------------------------------------------------------------------
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: getIt<AuthRemoteDataSource>()),
  );

  // -----------------------------------------------------------------------
  // UseCases
  // -----------------------------------------------------------------------
  getIt.registerLazySingleton<LoginWithEmailUseCase>(
    () => LoginWithEmailUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<LoginWithGoogleUseCase>(
    () => LoginWithGoogleUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<SignOutUseCase>(
    () => SignOutUseCase(getIt<AuthRepository>()),
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
      loginWithGoogleUseCase: getIt<LoginWithGoogleUseCase>(),
      signOutUseCase: getIt<SignOutUseCase>(),
      getCurrentUserUseCase: getIt<GetCurrentUserUseCase>(),
    ),
  );
}
