import 'package:celulas_app/src/features/auth/data/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> loginWithEmail(String email, String password);

  Future<UserModel> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  });

  Future<UserModel> loginWithGoogle();

  Future<void> signOut();

  Future<void> sendPasswordResetEmail({required String email});

  Future<UserModel?> getCurrentUser();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  AuthRemoteDataSourceImpl({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn(),
       _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<UserModel> loginWithEmail(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user == null) {
        throw Exception('Usuário não encontrado');
      }

      return UserModel.fromFirebaseUser(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception('Erro ao realizar login: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Não foi possível criar o usuário.');
      }

      await user.updateDisplayName(name.trim());
      await user.reload();

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name.trim(),
        'email': email.trim(),
        'photoUrl': null,
        'primaryCellId': null,
        'roles': ['member'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      final updateUser = _firebaseAuth.currentUser ?? user;

      return UserModel.fromFirebaseUser(updateUser);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception('Erro ao realizar cadastro: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> loginWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Login com google cancelado pelo usuário');
      }
      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      if (userCredential.user == null) {
        throw Exception('Falha ao registrar usuário com o Google');
      }

      return UserModel.fromFirebaseUser(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception('Erro ao realizar login com Google: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception('Erro ao enviar e-mail de redefinição: ${e.toString()}');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      return UserModel.fromFirebaseUser(user);
    }
    return null;
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado em outra conta.';
      case 'invalid-email':
        return 'O endereço de e-mail digitado é inválido.';
      case 'weak-password':
        return 'A senha é muito fraca. Escolha uma senha mais forte.';
      case 'user-disabled':
        return 'Esta conta foi desativada pelo administrador.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'too-many-requests':
        return 'Muitas tentativas consecutivas. Tente novamente mais tarde.';
      case 'network-request-failed':
        return 'Sem conexão com a internet. Verifique sua rede.';
      case 'operation-not-allowed':
        return 'Este método de autenticação está desativado no console do Firebase.';
      default:
        return e.message ??
            'Ocorreu um erro inesperado durante a autenticação.';
    }
  }
}
