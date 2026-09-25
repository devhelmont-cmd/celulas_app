import 'package:celulas_app/src/features/auth/data/models/user_model.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/auth/domain/repositories/i_user_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepositoryImpl implements IUserRepository {
  final FirebaseFirestore _firestore;

  UserRepositoryImpl(this._firestore);

  @override
  Future<UserEntity> syncUserData(UserEntity user) async {
    final docRef = _firestore.collection('users').doc(user.id);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      return UserModel.fromMap(snapshot.data()!, snapshot.id);
    } else {
      final newUserModel = UserModel(
        id: user.id,
        email: user.email,
        name: user.name,
        photoUrl: user.photoUrl,
        roles: user.roles,
        primaryCellId: user.primaryCellId,
      );
      await docRef.set(newUserModel.toMap());
      return newUserModel;
    }
  }

  @override
  Future<void> updateUserRoles(String userId, List<UserRole> roles) async {
    await _firestore.collection('users').doc(userId).update({
      'roles': roles.map((r) => r.name).toList(),
    });
  }
}
