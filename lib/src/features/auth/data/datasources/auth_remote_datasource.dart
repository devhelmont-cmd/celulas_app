import 'package:celulas_app/src/features/auth/data/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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

  Future<void> sendEmailVerification();

  Future<UserModel?> getCurrentUser();

  Future<void> updateUserProfile(UserModel user);

  Future<String> uploadProfilePhoto(String userId, XFile imageFile, String? oldPhotoUrl);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  AuthRemoteDataSourceImpl({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<UserModel> loginWithEmail(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Usuário não encontrado.');
      }

      // Recarrega o usuário para garantir o status de verificação atualizado
      await user.reload();
      final updatedUser = _firebaseAuth.currentUser ?? user;

      // EXIGÊNCIA DE E-MAIL REAL: Verifica se o e-mail foi confirmado
      if (!updatedUser.emailVerified) {
        // Desloga o usuário não verificado para não manter a sessão ativa
        await _firebaseAuth.signOut();
        throw Exception(
          'Seu e-mail ainda não foi verificado. Por favor, acesse sua caixa de entrada e confirme seu e-mail antes de entrar.',
        );
      }

      // Busca os dados e papéis no Firestore
      final doc = await _firestore.collection('users').doc(updatedUser.uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, updatedUser.uid);
      }

      return UserModel.fromFirebaseUser(updatedUser);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      // Repassa a exceção de e-mail não verificado ou erros customizados
      if (e is Exception) rethrow;
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

      // Envia o e-mail de verificação imediatamente no cadastro
      await user.sendEmailVerification();
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

      // Desloga o novo usuário para forçá-lo a verificar o e-mail antes do primeiro login
      await _firebaseAuth.signOut();

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
        throw Exception('Login com Google cancelado pelo usuário.');
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
        throw Exception('Falha ao registrar usuário com o Google.');
      }

      // Contas do Google já vêm verificadas por padrão
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
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception('Erro ao enviar e-mail de redefinição: ${e.toString()}');
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception('Erro ao reenviar e-mail de verificação: ${e.toString()}');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.reload();
      final updatedUser = _firebaseAuth.currentUser ?? user;

      // Se for login via e-mail/senha e o e-mail ainda não for verificado
      final isGoogleUser = updatedUser.providerData.any((p) => p.providerId == 'google.com');
      if (!isGoogleUser && !updatedUser.emailVerified) {
        await _firebaseAuth.signOut();
        return null;
      }

      final doc = await _firestore.collection('users').doc(updatedUser.uid).get();

      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, updatedUser.uid);
      }

      return UserModel.fromFirebaseUser(updatedUser);
    }
    return null;
  }

  Future<void> updateUserProfile(UserModel user) async {
    try {
      final batch = _firestore.batch();

      // 1. Atualiza a coleção 'users'
      final userRef = _firestore.collection('users').doc(user.id);
      batch.set(userRef, user.toMap(), SetOptions(merge: true));

      // 2. Sincroniza o nome atualizado na coleção 'members' (se o nome foi preenchido)
      if (user.name != null && user.name!.trim().isNotEmpty) {
        final membersSnap = await _firestore
            .collection('members')
            .where('userId', isEqualTo: user.id)
            .get();

        for (var doc in membersSnap.docs) {
          batch.update(doc.reference, {'name': user.name!.trim()});
        }
      }

      await batch.commit();

      // 3. Se o nome foi alterado, atualiza o displayName no Firebase Auth
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null && user.name != null) {
        await currentUser.updateDisplayName(user.name);
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception('Erro ao atualizar dados do perfil: ${e.toString()}');
    }
  }

  @override
  Future<String> uploadProfilePhoto(
      String userId,
      XFile imageFile,
      String? oldPhotoUrl,
      ) async {
    try {
      // 1. Só tenta apagar se a foto antiga pertencer explicitamente ao Firebase Storage do app
      if (oldPhotoUrl != null && oldPhotoUrl.isNotEmpty) {
        if (!oldPhotoUrl.contains('googleusercontent.com') &&
            (oldPhotoUrl.contains('firebasestorage.googleapis.com') ||
                oldPhotoUrl.contains('firebasestorage.app'))) {
          try {
            final oldRef = FirebaseStorage.instance.refFromURL(oldPhotoUrl);
            await oldRef.delete();
          } catch (e) {
            debugPrint('Arquivo antigo não encontrado no Storage, ignorando: $e');
          }
        }
      }

      // 2. Faz o upload da nova foto recortada com timestamp único
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users_photos')
          .child(userId)
          .child('profile_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final bytes = await imageFile.readAsBytes();

      final uploadTask = storageRef.putData(bytes, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // 3. Atualiza também no Firebase Auth currentUser
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        await currentUser.updatePhotoURL(downloadUrl);
      }

      return downloadUrl;
    } catch (e) {
      throw Exception('Erro ao fazer upload da foto de perfil: ${e.toString()}');
    }
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