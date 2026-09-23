import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    super.name,
    super.photoUrl,
    super.roles,
    super.primaryCellId,
  });

  factory UserModel.fromFirebaseUser(firebase.User user) {
    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      name: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}
