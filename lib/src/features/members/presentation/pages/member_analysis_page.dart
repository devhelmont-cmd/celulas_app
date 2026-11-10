import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/data/models/user_model.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/widgets/member_analytics_widget.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MemberAnalysisPage extends StatefulWidget {
  final Map<String, dynamic> memberData;
  final UserEntity currentUser;

  const MemberAnalysisPage({
    super.key,
    required this.memberData,
    required this.currentUser,
  });

  @override
  State<MemberAnalysisPage> createState() => _MemberAnalysisPageState();
}

class _MemberAnalysisPageState extends State<MemberAnalysisPage> {
  final _firestore = FirebaseFirestore.instance;
  final _cellDataSource = getIt<ICellRemoteDataSource>();

  bool _isLoading = true;
  UserEntity? _targetUserEntity;
  String _cellName = 'Sem Célula';
  String? _cellLeaderName;
  String? _memberRole;

  @override
  void initState() {
    super.initState();
    _loadFullMemberProfile();
  }

  Future<void> _loadFullMemberProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = widget.memberData['userId'] as String?;
      final memberId = widget.memberData['id'] as String?;
      final cellId = (widget.memberData['cellId'] ?? widget.memberData['primaryCellId']) as String?;
      _memberRole = widget.memberData['role'] as String? ?? 'membro';

      Map<String, dynamic> mergedMap = Map<String, dynamic>.from(widget.memberData);

      // 1. Busca os dados atualizados da coleção 'users' (se houver userId)
      if (userId != null && userId.trim().isNotEmpty) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          userData.forEach((key, value) {
            if (value != null) {
              mergedMap[key] = value;
            }
          });
          // Garante a uniformidade das chaves de telefone e foto
          if (userData['phone'] != null || userData['whatsapp'] != null) {
            mergedMap['phone'] = userData['phone'] ?? userData['whatsapp'];
          }
          if (userData['photoUrl'] != null) {
            mergedMap['photoUrl'] = userData['photoUrl'];
          }
        }
      }

      _targetUserEntity = UserModel.fromMap(
        mergedMap,
        userId ?? memberId ?? '',
      );

      // 2. Busca informações da célula vinculada
      if (cellId != null && cellId.trim().isNotEmpty) {
        try {
          final cell = await _cellDataSource.getCellById(cellId);
          _cellName = cell.name ?? 'Célula sem Nome';
          if (cell.leaderId != null && cell.leaderId!.isNotEmpty) {
            _cellLeaderName = await _cellDataSource.getUserNameById(cell.leaderId!, cellId: cell.id);
          }
        } catch (_) {
          _cellName = 'Sem Célula Vinculada';
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Erro ao carregar análise do membro: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Análise do Membro')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = _targetUserEntity;
    final name = user?.name ?? widget.memberData['name'] ?? 'Membro sem Nome';
    final photoUrl = user?.photoUrl ?? widget.memberData['photoUrl'] as String?;
    final phone = user?.phone ?? widget.memberData['phone'] as String? ?? 'Não informado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil Gerencial do Membro'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CABEÇALHO DO PERFIL
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text('Telefone: $phone', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              'Célula: $_cellName',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SEÇÃO 1: MÉTRICAS E DESEMPENHO NAS REUNIÕES (Frequência & Funções)
            if (user != null) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: MemberAnalyticsWidget(
                    currentUser: user,         // O membro cujo perfil está sendo analisado
                    viewerUser: widget.currentUser, // Quem está operando o app (Pastor ou Líder)
                    isEmbedded: true,
                    showAvatar: false, // Oculta a foto interna, pois o topo da página já possui uma
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // SEÇÃO 2: DADOS PESSOAIS E CONTATO
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informações de Contato e Pessoais',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(Icons.email_outlined, 'E-mail', user?.email.isNotEmpty == true ? user!.email : 'Sem e-mail cadastrado'),
                    _buildInfoRow(Icons.phone_outlined, 'Telefone / WhatsApp', phone),
                    _buildInfoRow(
                      Icons.cake_outlined,
                      'Data de Nascimento',
                      user?.birthDate != null ? DateFormat('dd/MM/yyyy').format(user!.birthDate!) : 'Não informada',
                    ),
                    _buildInfoRow(Icons.wc_outlined, 'Gênero', user?.gender ?? 'Não informado'),
                    _buildInfoRow(Icons.favorite_border, 'Estado Civil', user?.maritalStatus ?? 'Não informado'),
                    _buildInfoRow(Icons.work_outline, 'Profissão', user?.profession ?? 'Não informada'),
                    _buildInfoRow(Icons.home_outlined, 'Endereço', user?.address ?? 'Não informado'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SEÇÃO 3: JORNADA ESPIRITUAL
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jornada Espiritual & Origem',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.purple),
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(Icons.account_balance_outlined, 'Igreja de Origem', user?.originChurch ?? 'Não informada'),
                    _buildInfoRow(
                      Icons.event_available_outlined,
                      'Data de Conversão',
                      user?.conversionDate != null ? DateFormat('dd/MM/yyyy').format(user!.conversionDate!) : 'Não informada',
                    ),
                    _buildInfoRow(
                      Icons.water_drop_outlined,
                      'Batizado nas Águas',
                      user?.isWaterBaptized == true
                          ? (user?.waterBaptismDate != null
                          ? 'Sim (${DateFormat('dd/MM/yyyy').format(user!.waterBaptismDate!)})'
                          : 'Sim')
                          : 'Não',
                    ),
                    _buildInfoRow(
                      Icons.local_fire_department_outlined,
                      'Batizado no Espírito Santo',
                      user?.isHolySpiritBaptized == true ? 'Sim' : 'Não',
                    ),
                    _buildInfoRow(Icons.school_outlined, 'Cursos Concluídos', user?.completedCourses ?? 'Nenhum curso registrado'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SEÇÃO 4: HISTÓRICO E VÍNCULOS
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Histórico de Células & Liderança',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(Icons.groups_outlined, 'Célula Atual', _cellName),
                    _buildInfoRow(Icons.person_outline, 'Líder da Célula', _cellLeaderName ?? 'Sem líder informado'),
                    _buildInfoRow(Icons.admin_panel_settings_outlined, 'Função na Célula', _memberRole?.toUpperCase() ?? 'MEMBRO'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}