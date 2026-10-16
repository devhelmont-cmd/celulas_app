import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/presentation/controllers/cell_member_controller.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_member_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/cells/data/models/prayer_request_model.dart';
import 'package:celulas_app/src/features/cells/data/models/unlinked_user_or_member_model.dart';

import '../../data/models/cell_join_request_model.dart';

class CellDetailPage extends StatefulWidget {
  final CellEntity cell;
  final UserEntity? currentUser;
  final int initialTabIndex;
  final bool autoOpenEditMeeting;

  const CellDetailPage({
    super.key,
    required this.cell,
    this.currentUser,
    this.initialTabIndex = 0,
    this.autoOpenEditMeeting = false,
  });

  @override
  State<CellDetailPage> createState() => _CellDetailPageState();
}

class _CellDetailPageState extends State<CellDetailPage>
    with SingleTickerProviderStateMixin {
  late final CellMembersController _membersController;
  late CellEntity _currentCell;
  late TabController _tabController;

  List<CellJoinRequestEntity> _pendingRequests = [];
  bool _isLoadingRequests = false;

  CellMeetingModel? _currentMeeting;
  List<PrayerRequestModel> _prayerRequests = [];
  bool _isLoadingMeetingData = false;

  @override
  void initState() {
    super.initState();
    _currentCell = widget.cell;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _membersController = getIt<CellMembersController>();
    _membersController.fetchMembers(_currentCell.id);
    _loadPendingRequests();
    _loadMeetingAndPrayerRequests().then((_) {
      if (widget.autoOpenEditMeeting && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showEditMeetingRolesDialog();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Calcula a próxima data de reunião com base no dia da semana configurado na célula
  DateTime _calculateNextMeetingDate(String? meetingDayStr) {
    final now = DateTime.now();
    if (meetingDayStr == null || meetingDayStr.trim().isEmpty) {
      return now;
    }

    int targetWeekday = 2; // Terça-feira por padrão
    final lower = meetingDayStr.toLowerCase().trim();
    if (lower.contains('segunda')) {
      targetWeekday = DateTime.monday;
    } else if (lower.contains('terça') || lower.contains('terca')) {
      targetWeekday = DateTime.tuesday;
    } else if (lower.contains('quarta')) {
      targetWeekday = DateTime.wednesday;
    } else if (lower.contains('quinta')) {
      targetWeekday = DateTime.thursday;
    } else if (lower.contains('sexta')) {
      targetWeekday = DateTime.friday;
    } else if (lower.contains('sábado') || lower.contains('sabado')) {
      targetWeekday = DateTime.saturday;
    } else if (lower.contains('domingo')) {
      targetWeekday = DateTime.sunday;
    }

    int daysUntil = targetWeekday - now.weekday;
    if (daysUntil < 0) {
      daysUntil += 7;
    }

    return DateTime(now.year, now.month, now.day).add(Duration(days: daysUntil));
  }

  bool _isMeetingExpired(CellMeetingModel? meeting) {
    if (meeting == null) return true;
    final targetDate = meeting.meetingDate;
    final expiry = DateTime(targetDate.year, targetDate.month, targetDate.day + 1);
    return DateTime.now().isAfter(expiry);
  }

  bool _hasUnassignedRolesOrPendingReport() {
    final rawMeeting = _currentMeeting;
    final m = _isMeetingExpired(rawMeeting) ? null : rawMeeting;
    if (m == null) return true;
    if (!m.isReportFilled) return true;

    final isNullOrEmpty = (String? val) => val == null || val.trim().isEmpty || val == 'Não definido';

    return isNullOrEmpty(m.initialPrayerName) ||
        isNullOrEmpty(m.icebreakerName) ||
        isNullOrEmpty(m.worshipName) ||
        isNullOrEmpty(m.wordName) ||
        isNullOrEmpty(m.finalPrayerName) ||
        isNullOrEmpty(m.snackName) ||
        isNullOrEmpty(m.officialPhotoName) ||
        isNullOrEmpty(m.reportFillerName);
  }

  Future<void> _loadPendingRequests() async {
    final bool canViewRequests =
        widget.currentUser != null &&
            (widget.currentUser!.isPastorOrCoordinator ||
                (widget.currentUser!.isLeader &&
                    _currentCell.leaderId == widget.currentUser!.id));

    if (!canViewRequests) return;

    setState(() => _isLoadingRequests = true);
    try {
      final dataSource = getIt<ICellRemoteDataSource>();
      final requests = await dataSource.getPendingRequestsForCell(
        _currentCell.id,
      );
      if (mounted) {
        setState(() {
          _pendingRequests = requests;
          _isLoadingRequests = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  Future<void> _loadMeetingAndPrayerRequests() async {
    setState(() => _isLoadingMeetingData = true);
    try {
      final dataSource = getIt<ICellRemoteDataSource>();
      final meeting = await dataSource.getLatestMeeting(_currentCell.id);
      final prayers = await dataSource.getPrayerRequests(_currentCell.id);

      if (mounted) {
        setState(() {
          _currentMeeting = meeting;
          _prayerRequests = prayers;
          _isLoadingMeetingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMeetingData = false);
    }
  }

  Future<void> _refreshCell() async {
    try {
      final dataSource = getIt<ICellRemoteDataSource>();
      final updatedCell = await dataSource.getCellById(_currentCell.id);
      if (mounted) {
        setState(() {
          _currentCell = updatedCell;
        });
      }
      await _loadPendingRequests();
      await _loadMeetingAndPrayerRequests();
      _membersController.fetchMembers(_currentCell.id);
    } catch (_) {}
  }

  String _formatMemberRole(String role) {
    final lower = role.toLowerCase().trim();
    switch (lower) {
      case 'lider':
      case 'leader':
      case 'líder':
        return 'Líder';
      case 'colider':
      case 'co-leader':
      case 'co-líder':
        return 'Co-líder';
      case 'anfitriao':
      case 'host':
      case 'anfitrião':
        return 'Anfitrião';
      default:
        return 'Membro';
    }
  }

  String _normalizeRole(String role) {
    final lower = role.toLowerCase().trim();
    if (lower == 'leader' || lower == 'lider' || lower == 'líder') {
      return 'lider';
    }
    if (lower == 'co-leader' || lower == 'colider' || lower == 'co-líder') {
      return 'colider';
    }
    if (lower == 'host' || lower == 'anfitriao' || lower == 'anfitrião') {
      return 'anfitriao';
    }
    return 'membro';
  }

  int _getRoleWeight(String role) {
    final lower = role.toLowerCase().trim();
    switch (lower) {
      case 'lider':
      case 'leader':
      case 'líder':
        return 1;
      case 'colider':
      case 'co-leader':
      case 'co-líder':
        return 2;
      case 'anfitriao':
      case 'host':
      case 'anfitrião':
        return 3;
      default:
        return 4;
    }
  }

  Future<void> _showEditCellDialog() async {
    final nameCtrl = TextEditingController(text: _currentCell.name);
    final addressCtrl = TextEditingController(text: _currentCell.address);
    final neighborhoodCtrl = TextEditingController(
      text: _currentCell.neighborhood,
    );

    String selectedDay = _currentCell.meetingDay ?? 'Terça-feira';
    String selectedTime = _currentCell.meetingTime ?? '19:30';
    String selectedCategory = _currentCell.category ?? 'Geral';

    final days = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo',
    ];
    if (!days.contains(selectedDay)) selectedDay = days.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Editar Célula'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Célula',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Endereço'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: neighborhoodCtrl,
                  decoration: const InputDecoration(labelText: 'Bairro'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedDay,
                  decoration: const InputDecoration(
                    labelText: 'Dia da Reunião',
                  ),
                  items: days
                      .map(
                        (d) => DropdownMenuItem(value: d, child: Text(d)),
                  )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) selectedDay = val;
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: selectedTime),
                  decoration: const InputDecoration(
                    labelText: 'Horário (HH:mm)',
                  ),
                  onChanged: (val) => selectedTime = val,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final updatedModel = CellModel(
        id: _currentCell.id,
        name: nameCtrl.text.trim(),
        leaderId: _currentCell.leaderId,
        coLeaderId: _currentCell.coLeaderId,
        hostId: _currentCell.hostId,
        address: addressCtrl.text.trim(),
        neighborhood: neighborhoodCtrl.text.trim(),
        meetingDay: selectedDay,
        meetingTime: selectedTime,
        category: selectedCategory,
        isActive: _currentCell.isActive,
        createdAt: _currentCell.createdAt,
      );

      final dataSource = getIt<ICellRemoteDataSource>();
      await dataSource.updateCell(updatedModel);
      await _refreshCell();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Célula atualizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _toggleCellStatus() async {
    final bool newStatus = !_currentCell.isActive;
    final String actionText = newStatus ? 'reativar' : 'inativar';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${newStatus ? "Reativar" : "Inativar"} Célula'),
        content: Text(
          newStatus
              ? 'Deseja reativar esta célula? Ela voltará a ficar visível para todos os membros.'
              : 'Ao inativar a célula, ela manterá o histórico, mas todos os membros e líderes ficarão avulsos (sem célula).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirmar $actionText'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final dataSource = getIt<ICellRemoteDataSource>();
      await dataSource.toggleCellStatus(_currentCell.id, newStatus);
      await _refreshCell();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Célula ${newStatus ? "reativada" : "inativada"}!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
  }

  Future<void> _deleteCellCompletely() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desfazer / Excluir Célula'),
        content: const Text(
          'ATENÇÃO: Esta ação é irreversível!\n\n'
              'A célula deixará de existir no sistema e todos os membros, líderes, co-líderes e anfitriões ficarão avulsos (sem célula).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Excluir Célula',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final dataSource = getIt<ICellRemoteDataSource>();
        await dataSource.deleteCell(_currentCell.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Célula excluída com sucesso!'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir célula: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _onTapAddButton() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar à Célula'),
        content: const Text(
          'Deseja cadastrar um novo membro sem conta ou adicionar uma pessoa avulsa sem célula?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'novo'),
            child: const Text('Novo Membro Sem Conta'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'avulso'),
            child: const Text('Adicionar Pessoa Sem Célula'),
          ),
        ],
      ),
    );

    if (choice == 'novo') {
      _showAddMemberDialog();
    } else if (choice == 'avulso') {
      _showAddUnlinkedPersonDialog();
    }
  }

  Future<void> _showAddUnlinkedPersonDialog() async {
    final dataSource = getIt<ICellRemoteDataSource>();
    List<UnlinkedUserOrMember> candidates = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      candidates = await dataSource.getUsersAndMembersWithoutCell();
      candidates.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } catch (e) {
      debugPrint('Erro ao buscar pessoas sem célula: $e');
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (candidates.isEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ninguém sem célula'),
          content: const Text(
            'Não foram encontrados membros ou usuários avulsos sem célula cadastrados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final selected = await showDialog<UnlinkedUserOrMember>(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = candidates.where((c) {
              return c.name.toLowerCase().contains(
                query.toLowerCase().trim(),
              );
            }).toList();

            return AlertDialog(
              title: const Text('Selecionar Pessoa Sem Célula'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nome',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setDialogState(() => query = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                        child: Text(
                          'Nenhuma pessoa avulsa encontrada.',
                        ),
                      )
                          : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final badge = item.isRegisteredUser
                              ? 'Com Conta no App'
                              : 'Membro Sem Conta';

                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                item.name.isNotEmpty
                                    ? item.name[0].toUpperCase()
                                    : 'P',
                              ),
                            ),
                            title: Text(item.name),
                            subtitle: Text(
                              '$badge ${item.email != null ? "(${item.email})" : ""}',
                            ),
                            onTap: () => Navigator.pop(ctx, item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      await dataSource.addExistingUserOrMemberToCell(
        cellId: _currentCell.id,
        item: selected,
        role: 'membro',
      );
      await _refreshCell();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected.name} adicionado(a) à célula!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showAddMemberDialog() async {
    final nameController = TextEditingController();
    String selectedRole = 'membro';

    final isPastorOrCoord = widget.currentUser?.isPastorOrCoordinator ?? false;
    final Map<String, String> roleOptions = isPastorOrCoord
        ? {
      'membro': 'Membro',
      'anfitriao': 'Anfitrião',
      'colider': 'Co-líder',
      'lider': 'Líder',
    }
        : {
      'membro': 'Membro',
      'anfitriao': 'Anfitrião',
      'colider': 'Co-líder',
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Adicionar Membro sem Conta'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome Completo',
                        hintText: 'Nome e sobrenome',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Função na Célula',
                        border: OutlineInputBorder(),
                      ),
                      items: roleOptions.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRole = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final rawName = nameController.text.trim();
                    if (rawName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Por favor, informe o nome do membro.'),
                        ),
                      );
                      return;
                    }

                    final words = rawName
                        .split(' ')
                        .where((w) => w.trim().isNotEmpty)
                        .toList();
                    if (words.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Informe seu nome completo (nome e sobrenome).',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Adicionar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final newMember = CellMemberModel(
        id: '',
        cellId: _currentCell.id,
        userId: null,
        name: nameController.text.trim(),
        role: selectedRole,
        joinedAt: DateTime.now(),
      );

      final success = await _membersController.addMember(newMember);
      if (mounted) {
        if (success) {
          await _refreshCell();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${newMember.name} adicionado(a) com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao adicionar membro.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _bindSelfToCell() async {
    final roleOptions = {
      'lider': 'Líder',
      'colider': 'Co-líder',
      'anfitriao': 'Anfitrião',
      'membro': 'Membro',
    };
    String selectedRole = 'lider';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Vincular-se à Célula'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Deseja se vincular a esta célula? Selecione sua função:',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Sua Função',
                      border: OutlineInputBorder(),
                    ),
                    items: roleOptions.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedRole = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Vincular'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && widget.currentUser != null) {
      final newMember = CellMemberModel(
        id: '',
        cellId: _currentCell.id,
        userId: widget.currentUser!.id,
        name: widget.currentUser!.name ??
            widget.currentUser!.email.split('@').first,
        role: selectedRole,
        joinedAt: DateTime.now(),
      );

      final success = await _membersController.addMember(newMember);
      if (mounted) {
        if (success) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.currentUser!.id)
                .update({'primaryCellId': _currentCell.id});
          } catch (_) {}

          await _refreshCell();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Você foi vinculado à célula com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao vincular-se à célula.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<CellMemberModel?> _showLinkMemberDialog({String? targetName}) async {
    final dataSource = getIt<ICellRemoteDataSource>();
    List<CellMemberModel> unlinkedMembers = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      unlinkedMembers = await dataSource.getUnlinkedMembers();
    } catch (e) {
      debugPrint('Erro ao buscar membros sem conta: $e');
    }

    if (!mounted) return null;
    Navigator.pop(context);

    if (unlinkedMembers.isEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nenhum Membro Sem Conta'),
          content: const Text(
            'Não existem membros avulsos cadastrados no sistema.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return null;
    }

    unlinkedMembers.sort((a, b) {
      if (targetName != null && targetName.trim().isNotEmpty) {
        final target = targetName.trim().toLowerCase();
        final nameA = a.name.trim().toLowerCase();
        final nameB = b.name.trim().toLowerCase();
        final bool matchA = nameA == target || nameA.contains(target);
        final bool matchB = nameB == target || nameB.contains(target);

        if (matchA && !matchB) return -1;
        if (!matchA && matchB) return 1;
        if (matchA && matchB) {
          return nameA.compareTo(nameB);
        }
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return showDialog<CellMemberModel>(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = unlinkedMembers.where((m) {
              return m.name.toLowerCase().contains(
                searchQuery.toLowerCase().trim(),
              );
            }).toList();

            return AlertDialog(
              title: const Text('Vincular a Membro sem Conta'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nome',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setDialogState(() => searchQuery = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                        child: Text('Nenhum membro encontrado.'),
                      )
                          : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final member = filtered[index];
                          final cellName = member.cellName ?? 'Sem Célula';
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                member.name.isNotEmpty
                                    ? member.name[0].toUpperCase()
                                    : 'M',
                              ),
                            ),
                            title: Text(member.name),
                            subtitle: Text(
                              'Origem: $cellName | Função: ${_formatMemberRole(member.role)}',
                            ),
                            onTap: () => Navigator.pop(ctx, member),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _onTapApproveRequest(CellJoinRequestEntity request) async {
    CellMemberModel? selectedMember;

    final option = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Aprovar ${request.userName}'),
        content: Text(
          'Deseja vincular ${request.userName} a um membro já existente (sem conta) ou aprová-lo(a) como um novo membro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'novo'),
            child: const Text('Aprovar como Novo Membro'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'vincular'),
            child: const Text('Vincular a Membro Existente'),
          ),
        ],
      ),
    );

    if (option == null) return;

    if (option == 'vincular') {
      selectedMember = await _showLinkMemberDialog(targetName: request.userName);
      if (selectedMember == null) return;
    }

    bool setAsLeader = false;
    final isLeaderEmpty =
        _currentCell.leaderId == null || _currentCell.leaderId!.trim().isEmpty;

    if (isLeaderEmpty) {
      final shouldBeLeader = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Definir como Líder?'),
          content: Text(
            'Esta célula ainda não possui um líder definido. Deseja aprovar ${request.userName} já definindo-o(a) como Líder desta célula?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Apenas como Membro'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sim, Definir como Líder'),
            ),
          ],
        ),
      );

      if (shouldBeLeader == null) return;
      setAsLeader = shouldBeLeader;
    }

    await _handleApproveRequest(
      request: request,
      setAsLeader: setAsLeader,
      matchedMemberId: selectedMember?.id,
    );
  }

  Future<void> _handleApproveRequest({
    required CellJoinRequestEntity request,
    required bool setAsLeader,
    String? matchedMemberId,
  }) async {
    try {
      final dataSource = getIt<ICellRemoteDataSource>();
      await dataSource.approveJoinRequest(
        requestId: request.id,
        cellId: _currentCell.id,
        userId: request.userId,
        matchedMemberId: matchedMemberId,
        memberName: request.userName,
        setAsLeader: setAsLeader,
      );

      if (!mounted) return;
      await _refreshCell();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            matchedMemberId != null
                ? '${request.userName} vinculado(a) e aprovado(a) na célula!'
                : setAsLeader
                ? '${request.userName} aprovado(a) como Líder!'
                : '${request.userName} aprovado(a) na célula!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao aprovar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _leaveCell(CellMemberEntity member) async {
    final bool isUserLeaderOfThisCell =
        widget.currentUser != null &&
            (_currentCell.leaderId == widget.currentUser!.id ||
                (widget.currentUser!.name != null &&
                    _currentCell.leaderId?.trim().toLowerCase() ==
                        widget.currentUser!.name!.trim().toLowerCase()));

    final message = isUserLeaderOfThisCell
        ? 'Você é o líder desta célula. Ao sair, a célula ficará sem líder e você será desvinculado. Deseja continuar?'
        : 'Tem certeza de que deseja sair desta célula? Você ficará sem célula vinculada.';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da Célula'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final dataSource = getIt<ICellRemoteDataSource>();
      await dataSource.removeCellMember(member.id, _currentCell.id);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao sair: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showRoleChangeDialog(CellMemberEntity member) async {
    final isPastorOrCoord = widget.currentUser?.isPastorOrCoordinator ?? false;

    final Map<String, String> roleOptions = isPastorOrCoord
        ? {
      'lider': 'Líder',
      'colider': 'Co-líder',
      'anfitriao': 'Anfitrião',
      'membro': 'Membro',
    }
        : {
      'colider': 'Co-líder',
      'anfitriao': 'Anfitrião',
      'membro': 'Membro',
    };

    String currentSelection = _normalizeRole(member.role);
    if (!roleOptions.containsKey(currentSelection)) {
      currentSelection = 'membro';
    }

    final newRole = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String tempSelection = currentSelection;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Alterar Função de ${member.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: roleOptions.entries.map((entry) {
                  return RadioListTile<String>(
                    title: Text(entry.value),
                    value: entry.key,
                    groupValue: tempSelection,
                    onChanged: (val) {
                      setState(() => tempSelection = val!);
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, tempSelection),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newRole != null && newRole != currentSelection) {
      if (_membersController.value is CellMemberLoadedState) {
        final currentMembers =
            (_membersController.value as CellMemberLoadedState).members;

        final bool isCurrentlyLeader = currentSelection == 'lider';
        if (isCurrentlyLeader && newRole != 'lider') {
          final confirmLeaderless = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Célula Sem Líder'),
              content: Text(
                'Ao alterar a função de ${member.name}, a célula ficará sem um líder definido. Deseja continuar?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirmar'),
                ),
              ],
            ),
          );

          if (confirmLeaderless != true) return;
        }

        if (newRole != 'membro') {
          final existingOccupant = currentMembers
              .cast<CellMemberEntity>()
              .firstWhere(
                (m) => _normalizeRole(m.role) == newRole && m.id != member.id,
            orElse: () => CellMemberEntity(
              id: '',
              cellId: '',
              name: '',
              role: '',
              joinedAt: DateTime.now(),
            ),
          );

          if (existingOccupant.id.isNotEmpty) {
            final String roleTitle = roleOptions[newRole] ?? newRole;
            final confirmReplacement = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Substituir $roleTitle?'),
                content: Text(
                  'A célula já possui ${existingOccupant.name} como $roleTitle. '
                      'Ao confirmar, ${existingOccupant.name} passará a ser Membro e ${member.name} assumirá o cargo.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Substituir'),
                  ),
                ],
              ),
            );

            if (confirmReplacement != true) return;
          }
        }
      }

      try {
        final dataSource = getIt<ICellRemoteDataSource>();
        await dataSource.changeMemberRole(
          cellId: _currentCell.id,
          memberId: member.id,
          userId: member.userId ?? '',
          newRole: newRole,
        );
        await _refreshCell();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Função atualizada!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showTransferDialog(CellMemberEntity member) async {
    final dataSource = getIt<ICellRemoteDataSource>();
    List<CellModel> cells = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      cells = await dataSource.getCells();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pop(context);

    cells.removeWhere((c) => c.id == _currentCell.id);

    if (cells.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma outra célula disponível para transferência.'),
        ),
      );
      return;
    }

    final selectedCell = await showDialog<CellModel>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Transferir ${member.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: cells.length,
              itemBuilder: (context, index) {
                final c = cells[index];
                return ListTile(
                  title: Text(c.name ?? 'Sem Nome'),
                  subtitle: Text(c.neighborhood ?? ''),
                  onTap: () => Navigator.pop(ctx, c),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (selectedCell != null) {
      try {
        await dataSource.transferMember(
          currentCellId: _currentCell.id,
          newCellId: selectedCell.id,
          memberId: member.id,
          userId: member.userId ?? '',
          memberName: member.name,
        );
        await _refreshCell();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${member.name} transferido(a) para ${selectedCell.name}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao transferir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeMemberCompletely(CellMemberEntity member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Membro'),
        content: Text(
          'Tem certeza de que deseja remover ${member.name} desta célula?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remover',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _membersController.removeMember(member.id, _currentCell.id);
      await _refreshCell();
    }
  }

  Future<void> _showEditMeetingConfigDialog() async {
    String status = _currentMeeting?.status ?? 'normal';
    String eventName = _currentMeeting?.eventName ?? '';
    String statusNote = _currentMeeting?.statusNote ?? '';

    DateTime meetingDate = (_currentMeeting != null && !_isMeetingExpired(_currentMeeting))
        ? _currentMeeting!.meetingDate
        : _calculateNextMeetingDate(_currentCell.meetingDay);

    String defaultTime = _currentMeeting?.meetingTime ?? _currentCell.meetingTime ?? '19:30';
    TimeOfDay selectedTime = TimeOfDay(
      hour: int.tryParse(defaultTime.split(':').first) ?? 19,
      minute: int.tryParse(defaultTime.split(':').last) ?? 30,
    );

    String defaultLocation = _currentMeeting?.meetingLocation ?? _currentCell.address ?? '';
    final locationController = TextEditingController(text: defaultLocation);
    final eventNameController = TextEditingController(text: eventName);
    final noteController = TextEditingController(text: statusNote);

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Configurar Reunião'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(
                        labelText: 'Tipo / Status da Reunião',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text('Reunião Normal'),
                        ),
                        DropdownMenuItem(
                          value: 'bridge_event',
                          child: Text('Evento Ponte'),
                        ),
                        DropdownMenuItem(
                          value: 'rescheduled',
                          child: Text('Reunião Remarcada'),
                        ),
                        DropdownMenuItem(
                          value: 'canceled',
                          child: Text('Reunião Cancelada'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => status = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    if (status == 'bridge_event') ...[
                      TextField(
                        controller: eventNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome / Título do Evento Ponte',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (status == 'canceled') ...[
                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Justificativa do Cancelamento',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ] else if (status != 'normal') ...[
                      ListTile(
                        title: Text(
                          'Data: ${meetingDate.day.toString().padLeft(2, '0')}/${meetingDate.month.toString().padLeft(2, '0')}/${meetingDate.year}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: meetingDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 7)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => meetingDate = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        title: Text('Horário: ${selectedTime.format(context)}'),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null && picked != selectedTime) {
                            setDialogState(() => selectedTime = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: 'Local da Reunião / Evento',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final formattedTime = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

      final meetingId = (_currentMeeting == null || _isMeetingExpired(_currentMeeting)) ? '' : _currentMeeting!.id;

      // CORREÇÃO: Para reuniões do tipo 'normal' ou 'canceled', a data deve ser sempre a próxima data calculada da célula
      final DateTime finalMeetingDate = (status == 'normal' || status == 'canceled')
          ? _calculateNextMeetingDate(_currentCell.meetingDay)
          : meetingDate;

      final updatedMeeting = CellMeetingModel(
        id: meetingId,
        cellId: _currentCell.id,
        meetingDate: finalMeetingDate,
        status: status,
        eventName: status == 'bridge_event' ? eventNameController.text.trim() : null,
        statusNote: status == 'canceled' ? noteController.text.trim() : (status == 'bridge_event' || status == 'rescheduled' ? locationController.text.trim() : null),
        meetingTime: status != 'normal' && status != 'canceled' ? formattedTime : null,
        meetingLocation: status != 'normal' && status != 'canceled' ? locationController.text.trim() : null,
        initialPrayerName: _currentMeeting?.initialPrayerName,
        icebreakerName: _currentMeeting?.icebreakerName,
        worshipName: _currentMeeting?.worshipName,
        wordName: _currentMeeting?.wordName,
        finalPrayerName: _currentMeeting?.finalPrayerName,
        snackName: _currentMeeting?.snackName,
        officialPhotoName: _currentMeeting?.officialPhotoName,
        reportFillerName: _currentMeeting?.reportFillerName,
        isReportFilled: _currentMeeting?.isReportFilled ?? false,
      );

      final dataSource = getIt<ICellRemoteDataSource>();
      await dataSource.saveOrUpdateMeeting(updatedMeeting);
      await _loadMeetingAndPrayerRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuração da reunião atualizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showEditMeetingRolesDialog() async {
    List<CellMemberEntity> members = [];
    try {
      final dataSource = getIt<ICellRemoteDataSource>();
      final fetchedModels = await dataSource.getCellMembers(_currentCell.id);
      members = fetchedModels.cast<CellMemberEntity>();
    } catch (_) {
      if (_membersController.value is CellMemberLoadedState) {
        members = (_membersController.value as CellMemberLoadedState).members;
      }
    }

    final memberNames = members.map((m) => m.name).toList();
    if (!memberNames.contains('Não definido')) {
      memberNames.insert(0, 'Não definido');
    }

    String initialPrayer = _currentMeeting?.initialPrayerName ?? 'Não definido';
    String icebreaker = _currentMeeting?.icebreakerName ?? 'Não definido';
    String worship = _currentMeeting?.worshipName ?? 'Não definido';
    String word = _currentMeeting?.wordName ?? 'Não definido';
    String finalPrayer = _currentMeeting?.finalPrayerName ?? 'Não definido';
    String snack = _currentMeeting?.snackName ?? 'Não definido';
    String officialPhoto = _currentMeeting?.officialPhotoName ?? 'Não definido';

    String reportFiller = _currentMeeting?.reportFillerName ?? '';
    if (reportFiller.isEmpty || reportFiller == 'Não definido') {
      final coLeader = members.cast<CellMemberEntity>().firstWhere(
            (m) => _normalizeRole(m.role) == 'colider',
        orElse: () => CellMemberEntity(id: '', cellId: '', name: '', role: '', joinedAt: DateTime.now()),
      );
      if (coLeader.name.isNotEmpty) {
        reportFiller = coLeader.name;
      } else {
        final leader = members.cast<CellMemberEntity>().firstWhere(
              (m) => _normalizeRole(m.role) == 'lider',
          orElse: () => CellMemberEntity(id: '', cellId: '', name: '', role: '', joinedAt: DateTime.now()),
        );
        reportFiller = leader.name.isNotEmpty ? leader.name : 'Não definido';
      }
    }

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Definir Funções da Reunião'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRoleDropdown(
                      'Oração Inicial',
                      initialPrayer,
                      memberNames,
                          (v) => initialPrayer = v,
                    ),
                    _buildRoleDropdown(
                      'Quebra-gelo',
                      icebreaker,
                      memberNames,
                          (v) => icebreaker = v,
                    ),
                    _buildRoleDropdown(
                      'Louvor',
                      worship,
                      memberNames,
                          (v) => worship = v,
                    ),
                    _buildRoleDropdown(
                      'Palavra',
                      word,
                      memberNames,
                          (v) => word = v,
                    ),
                    _buildRoleDropdown(
                      'Oração Final',
                      finalPrayer,
                      memberNames,
                          (v) => finalPrayer = v,
                    ),
                    _buildRoleDropdown(
                      'Lanche',
                      snack,
                      memberNames,
                          (v) => snack = v,
                    ),
                    _buildRoleDropdown(
                      'Foto Oficial',
                      officialPhoto,
                      memberNames,
                          (v) => officialPhoto = v,
                    ),
                    _buildRoleDropdown(
                      'Preenchimento do Relatório',
                      reportFiller,
                      memberNames,
                          (v) => reportFiller = v,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final meetingId = (_currentMeeting == null || _isMeetingExpired(_currentMeeting)) ? '' : _currentMeeting!.id;

      // CORREÇÃO: Respeita a regra do status da reunião atual (se cancelada ou normal, usa a próxima data calculada)
      final currentStatus = _currentMeeting?.status ?? 'normal';
      final DateTime meetingDate = (currentStatus == 'normal' || currentStatus == 'canceled')
          ? _calculateNextMeetingDate(_currentCell.meetingDay)
          : ((_currentMeeting != null && !_isMeetingExpired(_currentMeeting))
          ? _currentMeeting!.meetingDate
          : _calculateNextMeetingDate(_currentCell.meetingDay));

      final updatedMeeting = CellMeetingModel(
        id: meetingId,
        cellId: _currentCell.id,
        meetingDate: meetingDate,
        status: currentStatus,
        statusNote: _currentMeeting?.statusNote,
        eventName: _currentMeeting?.eventName,
        meetingTime: _currentMeeting?.meetingTime,
        meetingLocation: _currentMeeting?.meetingLocation,
        initialPrayerName: initialPrayer == 'Não definido' ? null : initialPrayer,
        icebreakerName: icebreaker == 'Não definido' ? null : icebreaker,
        worshipName: worship == 'Não definido' ? null : worship,
        wordName: word == 'Não definido' ? null : word,
        finalPrayerName: finalPrayer == 'Não definido' ? null : finalPrayer,
        snackName: snack == 'Não definido' ? null : snack,
        officialPhotoName: officialPhoto == 'Não definido' ? null : officialPhoto,
        reportFillerName: reportFiller == 'Não definido' ? null : reportFiller,
        isReportFilled: _currentMeeting?.isReportFilled ?? false,
      );

      final dataSource = getIt<ICellRemoteDataSource>();
      await dataSource.saveOrUpdateMeeting(updatedMeeting);
      await _loadMeetingAndPrayerRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Funções da reunião salvas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Widget _buildRoleDropdown(
      String label,
      String currentValue,
      List<String> options,
      Function(String) onChanged,
      ) {
    final String val = options.contains(currentValue) ? currentValue : options.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: DropdownButtonFormField<String>(
        value: val,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Future<void> _showAddPrayerRequestDialog() async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo Pedido de Oração'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Escreva seu pedido de oração...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (result == true && ctrl.text.trim().isNotEmpty) {
      final user = widget.currentUser;
      final newReq = PrayerRequestModel(
        id: '',
        cellId: _currentCell.id,
        authorId: user?.id,
        authorName: user?.name ?? user?.email ?? 'Membro/Visitante',
        request: ctrl.text.trim(),
        createdAt: DateTime.now(),
      );

      final dataSource = getIt<ICellRemoteDataSource>();
      await dataSource.addPrayerRequest(newReq);
      await _loadMeetingAndPrayerRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido de oração cadastrado!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  bool _canEditPrayer(PrayerRequestModel prayer) {
    final user = widget.currentUser;
    if (user == null) return false;
    if (user.isPastorOrCoordinator) return true;
    final isAuthor =
        prayer.authorId == user.id ||
            (user.name != null &&
                prayer.authorName.trim().toLowerCase() ==
                    user.name!.trim().toLowerCase());
    return isAuthor;
  }

  bool _canDeletePrayer(PrayerRequestModel prayer) {
    final user = widget.currentUser;
    if (user == null) return false;
    if (user.isPastorOrCoordinator) return true;
    final isAuthor =
        prayer.authorId == user.id ||
            (user.name != null &&
                prayer.authorName.trim().toLowerCase() ==
                    user.name!.trim().toLowerCase());
    if (isAuthor) return true;

    final bool isUserLeader =
        user.isLeader ||
            _currentCell.leaderId == user.id ||
            (_currentCell.leaderId != null &&
                user.name != null &&
                _currentCell.leaderId!.trim().toLowerCase() ==
                    user.name!.trim().toLowerCase());

    if (isUserLeader) {
      List<CellMemberEntity> members = [];
      if (_membersController.value is CellMemberLoadedState) {
        members = (_membersController.value as CellMemberLoadedState).members;
      }
      final isMemberOfCell = members.any(
            (m) =>
        m.userId == prayer.authorId ||
            m.name.trim().toLowerCase() == prayer.authorName.trim().toLowerCase(),
      );
      if (isMemberOfCell) return true;
    }

    return false;
  }

  Future<void> _showEditPrayerDialog(PrayerRequestModel prayer) async {
    final ctrl = TextEditingController(text: prayer.request);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Pedido de Oração'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result == true && ctrl.text.trim().isNotEmpty) {
      final updated = PrayerRequestModel(
        id: prayer.id,
        cellId: prayer.cellId,
        authorId: prayer.authorId,
        authorName: prayer.authorName,
        request: ctrl.text.trim(),
        createdAt: prayer.createdAt,
        isAnswered: prayer.isAnswered,
      );
      final dataSource = getIt<ICellRemoteDataSource>();
      await dataSource.updatePrayerRequest(updated);
      await _loadMeetingAndPrayerRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido atualizado!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deletePrayerRequest(PrayerRequestModel prayer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Pedido'),
        content: const Text(
          'Tem certeza de que deseja excluir este pedido de oração?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final dataSource = getIt<ICellRemoteDataSource>();
      await dataSource.deletePrayerRequest(prayer.cellId, prayer.id);
      await _loadMeetingAndPrayerRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido excluído!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cell = _currentCell;
    final cellName = cell.name ?? 'Detalhes da Célula';

    final user = widget.currentUser;
    final isPastorOrCoord = user?.isPastorOrCoordinator ?? false;
    final bool isUserLeaderOfThisCell =
        user != null &&
            (cell.leaderId == user.id ||
                (user.name != null &&
                    cell.leaderId?.trim().toLowerCase() ==
                        user.name!.trim().toLowerCase()));

    final bool canEditCell = isPastorOrCoord || isUserLeaderOfThisCell;
    final bool canManageCellStatus = isPastorOrCoord;
    final bool canEditMeeting = canEditCell;

    return Scaffold(
      appBar: AppBar(
        title: Text(cellName),
        actions: [
          if (canEditCell)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') _showEditCellDialog();
                if (val == 'toggle') _toggleCellStatus();
                if (val == 'delete') _deleteCellCompletely();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Editar Célula'),
                ),
                if (canManageCellStatus)
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      _currentCell.isActive
                          ? 'Inativar Célula'
                          : 'Reativar Célula',
                    ),
                  ),
                if (canManageCellStatus)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Desfazer / Excluir Célula',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Membros'),
            Tab(icon: Icon(Icons.event_note), text: 'Reunião'),
            Tab(icon: Icon(Icons.volunteer_activism), text: 'Oração'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!_currentCell.isActive)
            Container(
              color: Colors.red.shade100,
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              child: Row(
                children: const [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'CÉLULA INATIVA: Visível apenas para o Líder e Pastor.',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMembersTab(
                  isPastorOrCoord,
                  isUserLeaderOfThisCell,
                ),
                _buildMeetingTab(canEditMeeting),
                _buildPrayerTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab(
      bool isPastorOrCoord,
      bool isUserLeaderOfThisCell,
      ) {
    final cell = _currentCell;
    final isLeaderEmpty =
        cell.leaderId == null || cell.leaderId!.trim().isEmpty;
    final dataSource = getIt<ICellRemoteDataSource>();
    final user = widget.currentUser;
    final bool canViewRequests =
        user != null && (isPastorOrCoord || isUserLeaderOfThisCell);
    final bool canAddMember =
        user != null && (isPastorOrCoord || isUserLeaderOfThisCell);

    final rawMeeting = _currentMeeting;
    final meeting = _isMeetingExpired(rawMeeting) ? null : rawMeeting;
    final status = meeting?.status ?? 'normal';

    String displayLabel;
    String displayValue;
    String displayAddress;

    if (meeting != null && (status == 'bridge_event' || status == 'rescheduled')) {
      final formattedDate = '${meeting.meetingDate.day.toString().padLeft(2, '0')}/${meeting.meetingDate.month.toString().padLeft(2, '0')}/${meeting.meetingDate.year}';
      final time = meeting.meetingTime ?? cell.meetingTime ?? '';
      displayLabel = status == 'bridge_event' ? 'Data do Evento' : 'Data Remarcada';
      displayValue = '$formattedDate às $time';
      displayAddress = meeting.meetingLocation?.isNotEmpty == true ? meeting.meetingLocation! : (cell.address ?? '');
    } else {
      displayLabel = 'Reuniões';
      displayValue = '${cell.meetingDay ?? ''} às ${cell.meetingTime ?? ''}';
      displayAddress = cell.address ?? '';
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isLeaderEmpty || !isUserLeaderOfThisCell) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 20,
                          color: isLeaderEmpty ? Colors.red : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        isLeaderEmpty
                            ? const Text(
                          'Líder: Sem líder definido',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        )
                            : FutureBuilder<String?>(
                          key: ValueKey(
                            'leader_detail_${cell.id}_${cell.leaderId}',
                          ),
                          future: dataSource.getUserNameById(
                            cell.leaderId!,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Text(
                                'Líder: Carregando...',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              );
                            }
                            final leaderName =
                                snapshot.data ?? cell.leaderId!;
                            return Text(
                              'Líder: $leaderName',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 20,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('$displayLabel: $displayValue')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 20,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Endereço: $displayAddress')),
                    ],
                  ),
                  if (status != 'normal') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: status == 'bridge_event'
                            ? Colors.blue.shade50
                            : status == 'canceled'
                            ? Colors.red.shade50
                            : Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            status == 'bridge_event'
                                ? Icons.star
                                : status == 'canceled'
                                ? Icons.cancel
                                : Icons.edit_calendar,
                            size: 18,
                            color: status == 'bridge_event'
                                ? Colors.blue
                                : status == 'canceled'
                                ? Colors.red
                                : Colors.purple,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status == 'bridge_event'
                                  ? 'Evento Ponte: ${meeting?.eventName ?? meeting?.statusNote ?? ''}'
                                  : status == 'canceled'
                                  ? 'Reunião Cancelada: ${meeting?.statusNote ?? ''}'
                                  : 'Reunião Remarcada: ${meeting?.meetingTime ?? ""} (${meeting?.meetingLocation ?? ""})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: status == 'bridge_event'
                                    ? Colors.blue.shade800
                                    : status == 'canceled'
                                    ? Colors.red.shade800
                                    : Colors.purple.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (canViewRequests && _pendingRequests.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Solicitações Pendentes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingRequests.length,
                itemBuilder: (context, index) {
                  final req = _pendingRequests[index];
                  return Container(
                    width: 260,
                    margin: const EdgeInsets.only(right: 12),
                    child: Card(
                      color: Colors.orange.shade50,
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              req.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Deseja entrar na célula',
                              style: TextStyle(fontSize: 12),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _onTapApproveRequest(req),
                                  icon: const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                  label: const Text(
                                    'Aprovar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
          Expanded(
            child: ValueListenableBuilder<CellMemberState>(
              valueListenable: _membersController,
              builder: (context, state, _) {
                bool isCurrentUserInCell = false;
                if (state is CellMemberLoadedState && user != null) {
                  isCurrentUserInCell = state.members.any(
                        (m) =>
                    m.userId == user.id ||
                        (user.name != null &&
                            m.name.trim().toLowerCase() ==
                                user.name!.trim().toLowerCase()),
                  );
                }

                final bool canBindSelf =
                    user != null && isPastorOrCoord && !isCurrentUserInCell;

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Membros da Célula',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            if (canBindSelf)
                              ElevatedButton.icon(
                                onPressed: _bindSelfToCell,
                                icon: const Icon(Icons.link, size: 18),
                                label: const Text('Vincular-me'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            if (canBindSelf && canAddMember)
                              const SizedBox(width: 8),
                            if (canAddMember)
                              ElevatedButton.icon(
                                onPressed: _onTapAddButton,
                                icon: const Icon(Icons.person_add, size: 18),
                                label: const Text('Adicionar'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (state is CellMemberLoadingState ||
                              state is CellMemberInitialState) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (state is CellMemberErrorState) {
                            return Center(
                              child: Text(
                                'Erro: ${state.message}',
                                style: const TextStyle(color: Colors.red),
                              ),
                            );
                          }

                          if (state is CellMemberLoadedState) {
                            final members = List<CellMemberEntity>.from(
                              state.members,
                            );

                            if (members.isEmpty) {
                              return const Center(
                                child: Text(
                                  'Nenhum membro cadastrado nesta célula.',
                                ),
                              );
                            }

                            members.sort((a, b) {
                              final bool isUserA =
                                  user != null &&
                                      (a.userId == user.id ||
                                          (user.name != null &&
                                              a.name.trim().toLowerCase() ==
                                                  user.name!
                                                      .trim()
                                                      .toLowerCase()));
                              final bool isUserB =
                                  user != null &&
                                      (b.userId == user.id ||
                                          (user.name != null &&
                                              b.name.trim().toLowerCase() ==
                                                  user.name!
                                                      .trim()
                                                      .toLowerCase()));

                              if (isUserA && !isUserB) return -1;
                              if (!isUserA && isUserB) return 1;

                              final int weightA = _getRoleWeight(a.role);
                              final int weightB = _getRoleWeight(b.role);

                              if (weightA != weightB) {
                                return weightA.compareTo(weightB);
                              }

                              return a.name.toLowerCase().compareTo(
                                b.name.toLowerCase(),
                              );
                            });

                            return ListView.builder(
                              itemCount: members.length,
                              itemBuilder: (context, index) {
                                final member = members[index];
                                final formattedRole = _formatMemberRole(
                                  member.role,
                                );

                                final bool isCurrentLogUserCard =
                                    user != null &&
                                        (member.userId == user.id ||
                                            (user.name != null &&
                                                member.name.trim().toLowerCase() ==
                                                    user.name!
                                                        .trim()
                                                        .toLowerCase()));

                                final bool canEditMember =
                                    isPastorOrCoord ||
                                        (isUserLeaderOfThisCell &&
                                            !isCurrentLogUserCard);

                                final bool canSeeLeaveButton =
                                    isCurrentLogUserCard;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      child: Text(
                                        member.name.isNotEmpty
                                            ? member.name[0].toUpperCase()
                                            : 'M',
                                      ),
                                    ),
                                    title: Text(member.name),
                                    subtitle: Text(
                                      formattedRole,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: formattedRole == 'Líder'
                                            ? Colors.blue.shade700
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                    trailing: canEditMember
                                        ? PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'role') {
                                          _showRoleChangeDialog(member);
                                        } else if (value ==
                                            'transfer') {
                                          _showTransferDialog(member);
                                        } else if (value == 'remove') {
                                          if (isCurrentLogUserCard) {
                                            _leaveCell(member);
                                          } else {
                                            _removeMemberCompletely(
                                              member,
                                            );
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'role',
                                          child: Text(
                                            'Alterar Função',
                                          ),
                                        ),
                                        if (isPastorOrCoord &&
                                            !isCurrentLogUserCard)
                                          const PopupMenuItem(
                                            value: 'transfer',
                                            child: Text(
                                              'Transferir de Célula',
                                            ),
                                          ),
                                        PopupMenuItem(
                                          value: 'remove',
                                          child: Text(
                                            isCurrentLogUserCard
                                                ? 'Sair da Célula'
                                                : 'Remover da Célula',
                                            style: const TextStyle(
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                        : canSeeLeaveButton
                                        ? TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      onPressed: () => _leaveCell(member),
                                      icon: const Icon(
                                        Icons.logout,
                                        size: 16,
                                      ),
                                      label: const Text('Sair'),
                                    )
                                        : null,
                                  ),
                                );
                              },
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingTab(bool canEdit) {
    if (_isLoadingMeetingData) {
      return const Center(child: CircularProgressIndicator());
    }

    final rawMeeting = _currentMeeting;
    final meeting = _isMeetingExpired(rawMeeting) ? null : rawMeeting;
    final status = meeting?.status ?? 'normal';
    final bool showLeaderWarning = canEdit && _hasUnassignedRolesOrPendingReport();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLeaderWarning) ...[
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aviso ao Líder: Lembre-se de definir as funções da próxima reunião e preencher o relatório da reunião passada.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Configuração da Reunião',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (canEdit)
                ElevatedButton.icon(
                  onPressed: _showEditMeetingConfigDialog,
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Configurar'),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (status == 'bridge_event')
            Card(
              color: Colors.blue.shade50,
              child: ListTile(
                leading: const Icon(Icons.star, color: Colors.blue, size: 32),
                title: Text(
                  'EVENTO PONTE: ${meeting?.eventName ?? "Especial"}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                subtitle: Text(
                  'Data: ${meeting?.meetingDate.day.toString().padLeft(2, '0')}/${meeting?.meetingDate.month.toString().padLeft(2, '0')}/${meeting?.meetingDate.year} às ${meeting?.meetingTime ?? _currentCell.meetingTime}\nLocal: ${meeting?.meetingLocation ?? _currentCell.address}',
                ),
              ),
            )
          else if (status == 'canceled')
            Card(
              color: Colors.red.shade50,
              child: ListTile(
                leading: const Icon(
                  Icons.cancel,
                  color: Colors.red,
                  size: 32,
                ),
                title: const Text(
                  'REUNIÃO CANCELADA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                subtitle: Text(
                  'Motivo: ${meeting?.statusNote ?? "Sem motivo informado."}',
                ),
              ),
            )
          else if (status == 'rescheduled')
              Card(
                color: Colors.purple.shade50,
                child: ListTile(
                  leading: const Icon(
                    Icons.edit_calendar,
                    color: Colors.purple,
                    size: 32,
                  ),
                  title: const Text(
                    'REUNIÃO REMARCADA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  subtitle: Text(
                    'Nova Data: ${meeting?.meetingDate.day.toString().padLeft(2, '0')}/${meeting?.meetingDate.month.toString().padLeft(2, '0')}/${meeting?.meetingDate.year} às ${meeting?.meetingTime ?? _currentCell.meetingTime}\nLocal: ${meeting?.meetingLocation ?? _currentCell.address}',
                  ),
                ),
              )
            else
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event, color: Colors.green, size: 32),
                  title: const Text(
                    'Reunião Normal',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Padrão: ${_currentCell.meetingDay ?? "Sem dia"} às ${_currentCell.meetingTime ?? "Sem horário"} em ${_currentCell.address ?? "Sem endereço"}',
                  ),
                ),
              ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Funções da Próxima Reunião',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (canEdit)
                ElevatedButton.icon(
                  onPressed: _showEditMeetingRolesDialog,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Definir Funções'),
                ),
            ],
          ),
          const SizedBox(height: 12),

          _buildRoleCard(
            'Oração Inicial',
            meeting?.initialPrayerName,
            Icons.nature_people,
          ),
          _buildRoleCard('Quebra-gelo', meeting?.icebreakerName, Icons.games),
          _buildRoleCard('Louvor', meeting?.worshipName, Icons.music_note),
          _buildRoleCard('Palavra', meeting?.wordName, Icons.menu_book),
          _buildRoleCard(
            'Oração Final',
            meeting?.finalPrayerName,
            Icons.volunteer_activism,
            highlightPrayerAlert: true,
          ),
          _buildRoleCard('Lanche', meeting?.snackName, Icons.restaurant),
          _buildRoleCard('Foto Oficial', meeting?.officialPhotoName, Icons.camera_alt),
          _buildRoleCard('Preenchimento do Relatório', meeting?.reportFillerName, Icons.description),

          const SizedBox(height: 24),
          const Text(
            'Momentos Abertos a Todos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: const [
                  ListTile(
                    leading: Icon(Icons.forum_outlined, color: Colors.indigo),
                    title: Text(
                      'Conversa sobre a Palavra',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Espaço para todos compartilharem e conversarem sobre a lição.',
                    ),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(
                      Icons.record_voice_over,
                      color: Colors.green,
                    ),
                    title: Text(
                      'Testemunhos',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Momento livre para contar vitórias e bênçãos alcançadas.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(
      String title,
      String? assignedName,
      IconData icon, {
        bool highlightPrayerAlert = false,
      }) {
    final user = widget.currentUser;
    final bool isUserAssigned =
        user != null &&
            assignedName != null &&
            (user.name?.trim().toLowerCase() == assignedName.trim().toLowerCase());

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: Icon(
          icon,
          color: isUserAssigned ? Colors.orange.shade800 : Colors.blue.shade700,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          assignedName ?? 'Não definido',
          style: TextStyle(
            color: assignedName != null ? Colors.black87 : Colors.grey,
            fontWeight: assignedName != null ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: highlightPrayerAlert && assignedName != null
            ? Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Orar pelos Pedidos!',
            style: TextStyle(
              fontSize: 11,
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        )
            : null,
      ),
    );
  }

  Widget _buildPrayerTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pedidos de Oração',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _showAddPrayerRequestDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Pedir Oração'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _prayerRequests.isEmpty
                ? const Center(
              child: Text(
                'Nenhum pedido de oração registrado nesta célula.',
              ),
            )
                : ListView.builder(
              itemCount: _prayerRequests.length,
              itemBuilder: (context, index) {
                final prayer = _prayerRequests[index];
                final canEdit = _canEditPrayer(prayer);
                final canDelete = _canDeletePrayer(prayer);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.volunteer_activism, size: 20),
                    ),
                    title: Text(prayer.request),
                    subtitle: Text('Por: ${prayer.authorName}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canEdit)
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 20,
                              color: Colors.blue,
                            ),
                            onPressed: () => _showEditPrayerDialog(prayer),
                          ),
                        if (canDelete)
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 20,
                              color: Colors.red,
                            ),
                            onPressed: () => _deletePrayerRequest(prayer),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}