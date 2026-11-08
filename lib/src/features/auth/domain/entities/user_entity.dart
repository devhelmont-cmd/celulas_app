// lib/src/features/auth/domain/entities/user_entity.dart

enum UserRole { member, leader, coordinator, pastor }

class UserEntity {
  final String id;
  final String email;
  final String? name;
  final String? photoUrl;
  final List<UserRole> roles;
  final String? primaryCellId;

  // NOVOS CAMPOS DO PERFIL
  final String? phone;
  final DateTime? birthDate;
  final String? gender; // 'masculino', 'feminino'
  final String? maritalStatus; // 'solteiro', 'casado', 'divorciado', 'viuvo'
  final String? profession;
  final String? address;

  // CAMPOS ESPIRITUAIS / PASTORAIS
  final DateTime? conversionDate;
  final bool? isWaterBaptized;
  final DateTime? waterBaptismDate;
  final bool? isHolySpiritBaptized;
  final String? originChurch;
  final String? ministry;
  final String? completedCourses; // <--- NOVO CAMPO ADICIONADO

  const UserEntity({
    required this.id,
    required this.email,
    this.name,
    this.photoUrl,
    this.roles = const [UserRole.member],
    this.primaryCellId,
    this.phone,
    this.birthDate,
    this.gender,
    this.maritalStatus,
    this.profession,
    this.address,
    this.conversionDate,
    this.isWaterBaptized,
    this.waterBaptismDate,
    this.isHolySpiritBaptized,
    this.originChurch,
    this.ministry,
    this.completedCourses, // <--- NOVO CAMPO ADICIONADO
  });

  bool get isPastorOrCoordinator =>
      roles.contains(UserRole.pastor) || roles.contains(UserRole.coordinator);

  bool get isLeader => roles.contains(UserRole.leader);

  bool get isMember => roles.contains(UserRole.member);

  /// Verifica se os campos obrigatórios para acompanhamento básico foram preenchidos
  bool get isProfileComplete {
    final hasName = name != null && name!.trim().length >= 3;
    final hasPhone = phone != null && phone!.trim().isNotEmpty;
    final hasBirthDate = birthDate != null;
    final hasGender = gender != null && gender!.trim().isNotEmpty;
    return hasName && hasPhone && hasBirthDate && hasGender;
  }
}