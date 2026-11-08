// lib/src/core/utils/gender_helper.dart

class GenderHelper {
  /// Retorna o gênero normalizado: 'masculino', 'feminino' ou null
  static String? normalizeGender(String? gender) {
    if (gender == null) return null;
    final g = gender.toLowerCase().trim();
    if (g == 'masculino' || g == 'm') return 'masculino';
    if (g == 'feminino' || g == 'f') return 'feminino';
    return null;
  }

  /// Retorna o título pastoral apropriado com base no gênero.
  /// Masculino: 'Pr.' | Feminino: 'Pra.' | Omitido/Neutro: 'Pr.(a)'
  static String getPastorPrefix(String? gender) {
    final normGender = normalizeGender(gender);
    if (normGender == 'masculino') return 'Pr.';
    if (normGender == 'feminino') return 'Pra.';
    return 'Pr.(a)';
  }

  /// Formata o nome para exibição pública no aplicativo.
  /// Se a pessoa possuir o papel de Pastor, adiciona o prefixo 'Pr.' ou 'Pra.' automaticamente.
  /// Para outros cargos (Líder, Coordenador, Membro), mantém o nome limpo original.
  static String formatDisplayName({
    required String? name,
    required bool isPastor,
    String? gender,
    String defaultIfEmpty = 'Nome não informado',
  }) {
    if (name == null || name.trim().isEmpty) {
      return defaultIfEmpty;
    }

    final cleanName = name.trim();

    if (isPastor) {
      // Evita duplicar o prefixo caso o usuário já tenha digitado 'Pr.' ou 'Pastor' no cadastro
      final lowerName = cleanName.toLowerCase();
      if (lowerName.startsWith('pr.') ||
          lowerName.startsWith('pra.') ||
          lowerName.startsWith('pastor ') ||
          lowerName.startsWith('pastora ')) {
        return cleanName;
      }

      final prefix = getPastorPrefix(gender);
      return '$prefix $cleanName';
    }

    return cleanName;
  }

  /// Retorna o termo apropriado para o cargo/função com base no gênero.
  static String formatRole(String roleKey, {String? gender}) {
    final normGender = normalizeGender(gender);
    final key = roleKey.toLowerCase().trim();

    switch (key) {
      case 'pastor':
      case 'pastora':
        if (normGender == 'masculino') return 'Pastor';
        if (normGender == 'feminino') return 'Pastora';
        return 'Pastor(a)';

      case 'coordenador':
      case 'coordenadora':
      case 'coordinator':
        if (normGender == 'masculino') return 'Coordenador';
        if (normGender == 'feminino') return 'Coordenadora';
        return 'Coordenador(a)';

      case 'lider':
      case 'líder':
      case 'leader':
        if (normGender == 'masculino') return 'Líder';
        if (normGender == 'feminino') return 'Líder';
        return 'Líder';

      case 'anfitriao':
      case 'anfitrião':
      case 'anfitria':
      case 'anfitriã':
      case 'host':
        if (normGender == 'masculino') return 'Anfitrião';
        if (normGender == 'feminino') return 'Anfitriã';
        return 'Anfitrião(ã)';

      case 'colider':
      case 'co-líder':
      case 'colíder':
      case 'co-leader':
        if (normGender == 'masculino') return 'Co-líder';
        if (normGender == 'feminino') return 'Co-líder';
        return 'Co-líder';

      case 'membro':
      case 'membra':
      case 'member':
        if (normGender == 'masculino') return 'Membro';
        if (normGender == 'feminino') return 'Membra';
        return 'Membro(a)';

      default:
        return roleKey;
    }
  }

  /// Formata uma frase completa ou rótulo composto. Ex: "Pastor / Líder de Célula"
  static String formatCompositeRoles({
    required bool isPastor,
    required bool isCoordinator,
    required bool isLeader,
    String? gender,
  }) {
    final pastorStr = formatRole('pastor', gender: gender);
    final coordStr = formatRole('coordenador', gender: gender);
    final leaderStr = formatRole('líder', gender: gender);
    final memberStr = formatRole('membro', gender: gender);

    if (isPastor && isLeader) return '$pastorStr / $leaderStr de Célula';
    if (isCoordinator && isLeader) return '$coordStr / $leaderStr de Célula';
    if (isPastor) return pastorStr;
    if (isCoordinator) return coordStr;
    if (isLeader) return '$leaderStr de Célula';
    return memberStr;
  }
}