// lib/src/features/auth/domain/entities/user_entity.dart

import 'package:celulas_app/src/core/utils/gender_helper.dart';

enum UserRole { member, leader, coordinator, pastor }

class UserEntity {
  final String id;
  final String email;
  final String? name;
  final String? photoUrl;
  final List<UserRole> roles;
  final String? primaryCellId;

  // DADOS PESSOAIS
  final String? phone;
  final DateTime? birthDate;
  final String? gender; // 'masculino', 'feminino' ou null (Não informado)
  final String? maritalStatus;
  final String? profession;
  final String? address;

  // JORNADA ESPIRITUAL
  final DateTime? conversionDate;
  final bool? isWaterBaptized;
  final DateTime? waterBaptismDate;
  final bool? isHolySpiritBaptized;
  final String? originChurch;
  final String? ministry;
  final String? completedCourses;

  // CARGOS / FUNÇÕES DE TEXTO LIVRE
  final String? customRoles;

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
    this.completedCourses,
    this.customRoles,
  });

  bool get isPastorOrCoordinator =>
      roles.contains(UserRole.pastor) || roles.contains(UserRole.coordinator);

  bool get isLeader => roles.contains(UserRole.leader);

  bool get isMember => roles.contains(UserRole.member);

  /// Retorna os cargos e funções formatados dinamicamente por gênero.
  List<String> get displayRoles {
    final List<String> list = [];

    // Roles do sistema tratadas com o helper de gênero
    if (roles.contains(UserRole.pastor)) {
      list.add(GenderHelper.formatRole('pastor', gender: gender));
    }
    if (roles.contains(UserRole.coordinator)) {
      list.add(GenderHelper.formatRole('coordenador', gender: gender));
    }
    if (roles.contains(UserRole.leader)) {
      list.add('${GenderHelper.formatRole('líder', gender: gender)} de Célula');
    }

    // Roles customizados (texto livre)
    if (customRoles != null && customRoles!.trim().isNotEmpty) {
      final customList = customRoles!
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      for (final item in customList) {
        if (!list.contains(item)) {
          list.add(item);
        }
      }
    }

    // Oculta a palavra "Membro" caso haja outro cargo qualquer.
    if (list.isEmpty) {
      list.add(GenderHelper.formatRole('membro', gender: gender));
    }

    return list;
  }

  /// Sexo é Opcional. Consideramos o perfil suficiente se tiver Nome Completo, Telefone e Nascimento.
  bool get isProfileComplete {
    final hasName = name != null && name!.trim().length >= 3;
    final hasPhone = phone != null && phone!.trim().isNotEmpty;
    final hasBirthDate = birthDate != null;
    return hasName && hasPhone && hasBirthDate;
  }
}