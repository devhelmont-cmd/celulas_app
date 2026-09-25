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
        roles: const[UserRole.member]
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      name: map['name'],
      photoUrl: map['photoUrl'],
      roles:
          (map['roles'] as List<dynamic>?)
              ?.map(
                (e) => UserRole.values.firstWhere(
                  (role) => role.name == e,
                  orElse: () => UserRole.member,
                ),
              )
              .toList() ??
          [UserRole.member],
      primaryCellId: map['primaryCellId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'roles': roles.map((r) => r.name).toList(),
      'primaryCellId': primaryCellId,
    };
  }
}
