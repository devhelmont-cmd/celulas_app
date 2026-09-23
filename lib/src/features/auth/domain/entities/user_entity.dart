enum UserRole { member, leader, coordinator, pastor }

class UserEntity {
  final String id;
  final String email;
  final String? name;
  final String? photoUrl;
  final List<UserRole> roles;
  final String? primaryCellId;

  const UserEntity({
    required this.id,
    required this.email,
    this.name,
    this.photoUrl,
    this.roles = const [UserRole.member],
    this.primaryCellId,
  });

  bool get isPastorOrCoordinator =>
      roles.contains(UserRole.pastor) || roles.contains(UserRole.coordinator);

  bool get isLeader => roles.contains(UserRole.leader);

  bool get isMember => roles.contains(UserRole.member);
}
