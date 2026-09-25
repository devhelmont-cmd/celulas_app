import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';

abstract class IUserRepository{
  Future<UserEntity> syncUserData(UserEntity user);
  Future<void> updateUserRoles(String userId, List<UserRole> roles);
}