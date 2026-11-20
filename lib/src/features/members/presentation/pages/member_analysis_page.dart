// lib/src/features/members/presentation/pages/member_analysis_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';
import 'package:celulas_app/src/features/cells/data/models/member_period_model.dart';
import 'package:celulas_app/src/core/utils/gender_helper.dart';
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
  bool _hasCell = false;
  bool _hasAccount = false;
  String? _currentCellId; // Armazena o ID da célula atual para referência

  List<MemberPeriodModel> _memberPeriods = [];
  List<CellModel> _allCells = [];

  bool get _isPastorOrCoordinator => widget.currentUser.isPastorOrCoordinator;
  String get _memberId => widget.memberData['id'] ?? '';

  @override
  void initState() {
    super.initState();
    _loadFullMemberProfile();
  }

  Future<void> _loadFullMemberProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = widget.memberData['userId'] as String?;
      final memberId = _memberId;
      final cellId = (widget.memberData['cellId'] ?? widget.memberData['primaryCellId']) as String?;
      _memberRole = widget.memberData['role'] as String? ?? 'membro';

      _hasAccount = userId != null && userId.trim().isNotEmpty;
      Map<String, dynamic> mergedMap = Map<String, dynamic>.from(widget.memberData);

      if (_hasAccount) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          userData.forEach((key, value) {
            if (value != null) mergedMap[key] = value;
          });
          if (userData['phone'] != null || userData['whatsapp'] != null) {
            mergedMap['phone'] = userData['phone'] ?? userData['whatsapp'];
          }
          if (userData['photoUrl'] != null) {
            mergedMap['photoUrl'] = userData['photoUrl'];
          }
          if (userData['primaryCellId'] != null && (cellId == null || cellId.isEmpty)) {
            mergedMap['cellId'] = userData['primaryCellId'];
          }
        }
      }

      _targetUserEntity = UserModel.fromMap(mergedMap, userId ?? memberId ?? '');
      final effectiveCellId = mergedMap['cellId'] ?? mergedMap['primaryCellId'] ?? _targetUserEntity?.primaryCellId;

      _currentCellId = effectiveCellId;

      if (effectiveCellId != null && effectiveCellId.trim().isNotEmpty && effectiveCellId != 'null') {
        try {
          final cell = await _cellDataSource.getCellById(effectiveCellId);
          _cellName = cell.name ?? 'Célula sem Nome';
          _hasCell = true;
          if (cell.leaderId != null && cell.leaderId!.isNotEmpty) {
            _cellLeaderName = await _cellDataSource.getUserNameById(cell.leaderId!, cellId: cell.id);
          }
        } catch (_) {
          _cellName = 'Sem Célula Vinculada';
          _hasCell = false;
        }
      } else {
        _cellName = 'Sem Célula';
        _hasCell = false;
      }

      if (memberId.isNotEmpty) {
        _memberPeriods = await _cellDataSource.getMemberPeriods(memberId);
      }

      // Carrega todas as células e ordena alfabeticamente pelo nome
      _allCells = await _cellDataSource.getCells(currentUser: widget.currentUser);
      _allCells.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Erro ao carregar análise do membro: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPeriodDialog({MemberPeriodModel? periodToEdit}) async {
    // Define a célula inicial predefinida: Célula atual do membro, ou a do período a ser editado, ou a primeira da lista alfabética
    String? selectedCellId = periodToEdit?.cellId ??
        (_currentCellId != null && _allCells.any((c) => c.id == _currentCellId)
            ? _currentCellId
            : (_allCells.isNotEmpty ? _allCells.first.id : null));

    DateTime startDate = periodToEdit?.startDate ?? DateTime.now();
    DateTime? endDate = periodToEdit?.endDate;

    String initialRole = periodToEdit?.role?.toLowerCase().trim() ?? 'membro';
    if (!['membro', 'lider', 'colider', 'anfitriao'].contains(initialRole)) {
      initialRole = 'membro';
    }
    String role = initialRole;

    final Map<String, String> validRoles = {
      'membro': 'Membro',
      'lider': 'Líder',
      'colider': 'Co-líder',
      'anfitriao': 'Anfitrião',
    };

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(periodToEdit == null ? 'Adicionar Período' : 'Editar Período'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCellId,
                  decoration: const InputDecoration(labelText: 'Célula', border: OutlineInputBorder()),
                  items: _allCells.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name ?? ''))).toList(),
                  onChanged: (val) => setDialogState(() => selectedCellId = val),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Data de Início'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(startDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2015),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setDialogState(() => startDate = picked);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Data de Término (Opcional)'),
                  subtitle: Text(endDate != null ? DateFormat('dd/MM/yyyy').format(endDate!) : 'Ativo / Atual'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (endDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.red),
                          onPressed: () => setDialogState(() => endDate = null),
                        ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endDate ?? DateTime.now(),
                      firstDate: DateTime(2015),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setDialogState(() => endDate = picked);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Função no Período', border: OutlineInputBorder()),
                  items: validRoles.entries
                      .map((entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => role = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (selectedCellId == null) return;
                final cellObj = _allCells.firstWhere((c) => c.id == selectedCellId);

                final newPeriod = MemberPeriodModel(
                  id: periodToEdit?.id ?? '',
                  cellId: selectedCellId!,
                  cellName: cellObj.name ?? 'Célula',
                  startDate: startDate,
                  endDate: endDate,
                  role: role,
                );

                Navigator.pop(ctx);

                try {
                  await _cellDataSource.saveMemberPeriod(
                    memberId: _memberId,
                    period: newPeriod,
                    isPastorOrCoordinator: _isPastorOrCoordinator,
                  );
                  await _loadFullMemberProfile();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Período salvo com sucesso!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Conflito ou Erro de Validação'),
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        actions: [
                          ElevatedButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
                        ],
                      ),
                    );
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePeriod(MemberPeriodModel period) async {
    final bool isCurrentPeriod = period.endDate == null;
    final message = isCurrentPeriod
        ? '⚠️ Este é o PERÍODO ATUAL do membro na célula ${period.cellName}. Excluir este período irá DESVINCULAR O MEMBRO da célula atual. As funções exercidas em reuniões dentro deste intervalo serão transferidas para o líder da célula. Deseja realmente continuar?'
        : 'Deseja realmente excluir o período na célula ${period.cellName}? As funções exercidas em reuniões dentro deste intervalo serão transferidas para o líder da célula para manter a integridade.';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCurrentPeriod ? 'Excluir Período Atual?' : 'Excluir Período'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _cellDataSource.deleteMemberPeriod(
          memberId: _memberId,
          periodId: period.id,
          isPastorOrCoordinator: _isPastorOrCoordinator,
        );
        await _loadFullMemberProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Período excluído com sucesso.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir período: $e'), backgroundColor: Colors.red),
          );
        }
      }
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
    final name = user?.displayName ?? GenderHelper.formatMemberName(name: widget.memberData['name'], role: _memberRole ?? 'membro', gender: user?.gender);
    final photoUrl = user?.photoUrl ?? widget.memberData['photoUrl'] as String?;
    final phone = user?.phone ?? widget.memberData['phone'] as String? ?? 'Não informado';

    // Condição para exibir o MemberAnalyticsWidget:
    // Exibe se tiver célula OU se estiver sem célula mas possuir histórico de períodos gravados (_memberPeriods.isNotEmpty)
    final bool showAnalyticsCard = (_hasCell || _memberPeriods.isNotEmpty) && user != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil Gerencial do Membro'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
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
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _hasAccount ? Colors.indigo.shade50 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _hasAccount ? Colors.indigo.shade200 : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  _hasAccount ? 'Com conta no sistema' : 'Sem conta no sistema',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _hasAccount ? Colors.indigo.shade800 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SEÇÃO DE MÉTRICAS E DESEMPENHO (Exibido se tiver célula OU se estiver sem célula mas tiver histórico)
            if (showAnalyticsCard) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: MemberAnalyticsWidget(
                    currentUser: user,
                    viewerUser: widget.currentUser,
                    isEmbedded: true,
                    showAvatar: false,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // SEÇÃO DE PERÍODOS DE CÉLULAS (Exclusivo para Pastores/Coordenadores)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Histórico de Períodos em Células', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        if (_isPastorOrCoordinator)
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.blue),
                            onPressed: () => _showPeriodDialog(),
                          ),
                      ],
                    ),
                    const Text('Períodos de permanência do membro nas células do sistema:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const Divider(height: 20),
                    _memberPeriods.isEmpty
                        ? const Text('Nenhum período cadastrado.')
                        : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _memberPeriods.length,
                      separatorBuilder: (_, __) => const Divider(height: 10),
                      itemBuilder: (context, index) {
                        final p = _memberPeriods[index];
                        final isActive = p.endDate == null;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.cellName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'De ${DateFormat('dd/MM/yyyy').format(p.startDate)} até ${p.endDate != null ? DateFormat('dd/MM/yyyy').format(p.endDate!) : 'Atual'} • Função: ${p.role.toUpperCase()}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isActive ? Colors.green.shade200 : Colors.grey.shade300),
                                ),
                                child: Text(
                                  isActive ? 'Ativo' : 'Encerrado',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? Colors.green.shade800 : Colors.grey.shade700),
                                ),
                              ),
                              if (_isPastorOrCoordinator) ...[
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                  onPressed: () => _showPeriodDialog(periodToEdit: p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                  onPressed: () => _confirmDeletePeriod(p),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

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

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Célula e Ministérios',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(Icons.groups_outlined, 'Célula Atual', _cellName),
                    _buildInfoRow(Icons.person_outline, 'Líder da Célula', _cellLeaderName ?? 'Sem líder informado'),
                    _buildInfoRow(Icons.perm_contact_calendar_outlined, 'Função na Célula', GenderHelper.formatRole(_memberRole ?? 'membro', gender: user?.gender)),
                    _buildInfoRow(Icons.volunteer_activism_outlined, 'Ministérios em que Serve', user!.ministry ?? 'Não informado'),
                    _buildInfoRow(Icons.admin_panel_settings_outlined, 'Cargos Ministeriais', user.displayRoles.join(', ') ?? 'Não informado'),
                    /*_buildInfoRow(
                      _hasAccount ? Icons.person_outline : Icons.person_off_outlined,
                      'Status da Conta',
                      _hasAccount ? 'Com conta cadastrada no sistema' : 'Membro sem conta no sistema',
                    ),*/
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

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
                    _buildInfoRow(Icons.account_balance_outlined, 'Igreja de Origem', user!.originChurch ?? 'Não informada'),
                    _buildInfoRow(
                      Icons.event_available_outlined,
                      'Data de Conversão',
                      user?.conversionDate != null ? DateFormat('dd/MM/yyyy').format(user.conversionDate!) : 'Não informada',
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