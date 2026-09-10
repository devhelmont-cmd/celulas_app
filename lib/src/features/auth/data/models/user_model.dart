import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
  });

  //Mapeia o objeto nativo do Firebase Auth para nossa Entidade
  factory UserModel.fromFirebaseUser(firebase.User user) {
    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      name: user.displayName,
    );
  }
}
