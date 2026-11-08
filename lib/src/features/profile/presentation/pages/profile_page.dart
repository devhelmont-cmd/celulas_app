// lib/src/features/profile/presentation/pages/profile_page.dart

import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/profile/presentation/pages/fill_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatelessWidget {
  final UserEntity user;
  final VoidCallback onProfileUpdated;

  const ProfilePage({
    super.key,
    required this.user,
    required this.onProfileUpdated,
  });

  /// Calcula a porcentagem de preenchimento considerando os 14 campos do perfil
  double _calculateProfileCompletion() {
    int totalFields = 14; // Atualizado para incluir os 3 novos campos espirituais
    int filledFields = 0;

    // Dados Pessoais & Foto (5)
    if (user.photoUrl != null && user.photoUrl!.trim().isNotEmpty) filledFields++;
    if (user.name != null && user.name!.trim().length >= 3) filledFields++;
    if (user.phone != null && user.phone!.trim().isNotEmpty) filledFields++;
    if (user.birthDate != null) filledFields++;
    if (user.gender != null && user.gender!.trim().isNotEmpty) filledFields++;

    // Informações Complementares (3)
    if (user.maritalStatus != null && user.maritalStatus!.trim().isNotEmpty) filledFields++;
    if (user.profession != null && user.profession!.trim().isNotEmpty) filledFields++;
    if (user.address != null && user.address!.trim().isNotEmpty) filledFields++;

    // Jornada Espiritual & Ministerial (6)
    if (user.originChurch != null && user.originChurch!.trim().isNotEmpty) filledFields++;
    if (user.conversionDate != null) filledFields++;
    if (user.isWaterBaptized != null) filledFields++;
    if (user.isHolySpiritBaptized != null) filledFields++;
    if (user.completedCourses != null && user.completedCourses!.trim().isNotEmpty) filledFields++;
    if (user.ministry != null && user.ministry!.trim().isNotEmpty) filledFields++;

    return filledFields / totalFields;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _calculateProfileCompletion();
    final bool isComplete = progress >= 1.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar Perfil',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FillProfilePage(
                    user: user,
                    onProfileUpdated: onProfileUpdated,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // CABEÇALHO DO PERFIL
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 45)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user.name?.isNotEmpty == true ? user.name! : 'Nome não informado',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // BARRA DE PROGRESSO E AVISO DISCRETO
          if (!isComplete) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Perfil incompleto',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Preencha seus dados para ajudar seu líder a cuidar de você.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FillProfilePage(
                              user: user,
                              onProfileUpdated: onProfileUpdated,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Completar perfil agora'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // SEÇÃO: DADOS PESSOAIS
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dados Pessoais',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const Divider(height: 20),
                  _buildInfoRow(
                    Icons.phone_outlined,
                    'WhatsApp / Telefone',
                    user.phone,
                  ),
                  _buildInfoRow(
                    Icons.cake_outlined,
                    'Data de Nascimento',
                    user.birthDate != null
                        ? DateFormat('dd/MM/yyyy').format(user.birthDate!)
                        : null,
                  ),
                  _buildInfoRow(
                    Icons.wc_outlined,
                    'Sexo',
                    user.gender != null
                        ? (user.gender == 'masculino' ? 'Masculino' : 'Feminino')
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // SEÇÃO: INFORMAÇÕES COMPLEMENTARES
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informações Complementares',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 20),
                  _buildInfoRow(
                    Icons.favorite_border,
                    'Estado Civil',
                    _formatMaritalStatus(user.maritalStatus),
                  ),
                  _buildInfoRow(
                    Icons.work_outline,
                    'Profissão',
                    user.profession,
                  ),
                  _buildInfoRow(
                    Icons.home_outlined,
                    'Endereço',
                    user.address,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // SEÇÃO: JORNADA ESPIRITUAL
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jornada Espiritual & Ministerial',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  const Divider(height: 20),
                  _buildInfoRow(
                    Icons.account_balance_outlined,
                    'Igreja de Origem / Sede',
                    user.originChurch,
                  ),
                  _buildInfoRow(
                    Icons.event_available_outlined,
                    'Data de Conversão / Decisão',
                    user.conversionDate != null
                        ? DateFormat('dd/MM/yyyy').format(user.conversionDate!)
                        : null,
                  ),
                  _buildInfoRow(
                    Icons.water_drop_outlined,
                    'Batizado nas Águas',
                    user.isWaterBaptized == true
                        ? (user.waterBaptismDate != null
                        ? 'Sim (${DateFormat('dd/MM/yyyy').format(user.waterBaptismDate!)})'
                        : 'Sim')
                        : 'Não',
                  ),
                  _buildInfoRow(
                    Icons.local_fire_department_outlined,
                    'Batizado no Espírito Santo',
                    user.isHolySpiritBaptized == true ? 'Sim' : 'Não',
                  ),
                  _buildInfoRow(
                    Icons.school_outlined,
                    'Cursos / Trilhas Concluídas',
                    user.completedCourses,
                  ),
                  _buildInfoRow(
                    Icons.volunteer_activism_outlined,
                    'Ministério em que Serve',
                    user.ministry,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    final hasValue = value != null && value.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  hasValue ? value : 'Não informado',
                  style: TextStyle(
                    fontSize: 14,
                    color: hasValue ? Colors.black87 : Colors.grey.shade400,
                    fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _formatMaritalStatus(String? status) {
    if (status == null) return null;
    switch (status.toLowerCase()) {
      case 'solteiro':
        return 'Solteiro(a)';
      case 'casado':
        return 'Casado(a)';
      case 'divorciado':
        return 'Divorciado(a)';
      case 'viuvo':
        return 'Viúvo(a)';
      default:
        return status;
    }
  }
}