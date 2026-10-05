import 'package:flutter/material.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/presentation/controllers/cell_member_controller.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';

import '../../data/models/cell_join_request_model.dart';

class CellDetailPage extends StatefulWidget {
  final CellEntity cell;
  final UserEntity? currentUser;

  const CellDetailPage({
    super.key,
    required this.cell,
    this.currentUser,
  });

  @override
  State<CellDetailPage> createState() => _CellDetailPageState();
}

class _CellDetailPageState extends State<CellDetailPage> {
  late final CellMembersController _membersController;
  late CellEntity _currentCell;
  List<CellJoinRequestEntity> _pendingRequests = [];
  bool _isLoadingRequests = false;

  @override
  void initState() {
    super.initState();
    _currentCell = widget.cell;
    _membersController = getIt<CellMembersController>();
    _membersController.fetchMembers(_currentCell.id);
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    final bool canViewRequests = widget.currentUser != null &&
        (widget.currentUser!.isPastorOrCoordinator ||
            (widget.currentUser!.isLeader &&
                _currentCell.leaderId == widget.currentUser!.id));

    if (!canViewRequests) return;

    setState(() => _isLoadingRequests = true);
    try {
      final dataSource = getIt<ICellRemoteDataSource>();
      final requests =
      await dataSource.getPendingRequestsForCell(_currentCell.id);
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
      _membersController.fetchMembers(_currentCell.id);
    } catch (_) {}
  }

  String _formatMemberRole(String role) {
    final lower = role.toLowerCase().trim();
    switch (lower) {
      case 'lider':
      case 'leader':
        return 'Líder';
      case 'colider':
      case 'co-leader':
        return 'Co-líder';
      case 'anfitriao':
      case 'host':
        return 'Anfitrião';
      default:
        return 'Membro';
    }
  }

  String _normalizeRole(String role) {
    final lower = role.toLowerCase().trim();
    if (lower == 'leader') return 'lider';
    if (lower == 'co-leader') return 'colider';
    if (lower == 'host') return 'anfitriao';
    return lower;
  }

  int _getRoleWeight(String role) {
    final lower = role.toLowerCase().trim();
    switch (lower) {
      case 'lider':
      case 'leader':
        return 1;
      case 'colider':
      case 'co-leader':
        return 2;
      case 'anfitriao':
      case 'host':
        return 3;
      default:
        return 4;
    }
  }

  Future<void> _onTapApproveRequest(CellJoinRequestEntity request) async {
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

    await _handleApproveRequest(request: request, setAsLeader: setAsLeader);
  }

  Future<void> _handleApproveRequest({
    required CellJoinRequestEntity request,
    required bool setAsLeader,
  }) async {
    try {
      final dataSource = getIt<ICellRemoteDataSource>();
      await dataSource.approveJoinRequest(
        requestId: request.id,
        cellId: _currentCell.id,
        userId: request.userId ?? '',
        memberName: request.userName ?? 'Novo Membro',
        setAsLeader: setAsLeader,
      );

      if (!mounted) return;
      await _refreshCell();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            setAsLeader
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
            content: Text('Erro ao aprovar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _leaveCell(CellMemberEntity member) async {
    final bool isUserLeaderOfThisCell = widget.currentUser != null &&
        (_currentCell.leaderId == widget.currentUser!.id ||
            _currentCell.leaderId?.trim().toLowerCase() ==
                widget.currentUser!.name!.trim().toLowerCase());

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
              child: const Text('Cancelar')),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao sair: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showRoleChangeDialog(CellMemberEntity member) async {
    final isPastorOrCoord = widget.currentUser?.isPastorOrCoordinator ?? false;

    final Map<String, String> roleOptions = isPastorOrCoord
        ? {
      'lider': 'Líder',
      'colider': 'Co-líder',
      'anfitriao': 'Anfitrião',
      'membro': 'Membro'
    }
        : {'colider': 'Co-líder', 'anfitriao': 'Anfitrião', 'membro': 'Membro'};

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
                    child: const Text('Cancelar')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, tempSelection),
                    child: const Text('Salvar')),
              ],
            );
          },
        );
      },
    );

    if (newRole != null && newRole != currentSelection) {
      // Confirmação de substituição caso o cargo selecionado já pertença a outro membro
      if (_membersController.value is CellMemberLoadedState) {
        final currentMembers =
            (_membersController.value as CellMemberLoadedState).members;
        final existingOccupant = currentMembers.firstWhere(
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
                '${member.name} transferido(a) para ${selectedCell.name}'),
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
            'Tem certeza de que deseja remover ${member.name} desta célula?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _membersController.removeMember(member.id, _currentCell.id);
      await _refreshCell();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cell = _currentCell;
    final cellName = cell.name ?? 'Detalhes da Célula';
    final meetingDay = cell.meetingDay ?? '';
    final meetingTime = cell.meetingTime ?? '';
    final address = cell.address ?? '';

    final isLeaderEmpty =
        cell.leaderId == null || cell.leaderId!.trim().isEmpty;
    final dataSource = getIt<ICellRemoteDataSource>();

    final user = widget.currentUser;
    final isPastorOrCoord = user?.isPastorOrCoordinator ?? false;

    final bool isUserLeaderOfThisCell = user != null &&
        (cell.leaderId == user.id ||
            cell.leaderId?.trim().toLowerCase() ==
                user.name!.trim().toLowerCase());

    final bool canViewRequests =
        user != null && (isPastorOrCoord || isUserLeaderOfThisCell);

    return Scaffold(
      appBar: AppBar(
        title: Text(cellName),
      ),
      body: Padding(
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
                            future: dataSource
                                .getUserNameById(cell.leaderId!),
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
                        const Icon(Icons.access_time,
                            size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Reuniões: $meetingDay às $meetingTime'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Endereço: $address'),
                      ],
                    ),
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
                    color: Colors.orange),
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
                                req.userName ?? 'Usuário',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              const Text('Deseja entrar na célula',
                                  style: TextStyle(fontSize: 12)),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _onTapApproveRequest(req),
                                    icon: const Icon(Icons.check,
                                        size: 16, color: Colors.green),
                                    label: const Text('Aprovar',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.green)),
                                  ),
                                ],
                              )
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
            const Text(
              'Membros da Célula',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ValueListenableBuilder<CellMemberState>(
                valueListenable: _membersController,
                builder: (context, state, _) {
                  if (state is CellMemberLoadingState ||
                      state is CellMemberInitialState) {
                    return const Center(child: CircularProgressIndicator());
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
                    final members = List<CellMemberEntity>.from(state.members);

                    if (members.isEmpty) {
                      return const Center(
                        child: Text('Nenhum membro cadastrado nesta célula.'),
                      );
                    }

                    members.sort((a, b) {
                      final bool isUserA = user != null &&
                          (a.userId == user.id ||
                              a.name.trim().toLowerCase() ==
                                  user.name!.trim().toLowerCase());
                      final bool isUserB = user != null &&
                          (b.userId == user.id ||
                              b.name.trim().toLowerCase() ==
                                  user.name!.trim().toLowerCase());

                      if (isUserA && !isUserB) return -1;
                      if (!isUserA && isUserB) return 1;

                      final int weightA = _getRoleWeight(a.role);
                      final int weightB = _getRoleWeight(b.role);

                      if (weightA != weightB) {
                        return weightA.compareTo(weightB);
                      }

                      return a.name
                          .toLowerCase()
                          .compareTo(b.name.toLowerCase());
                    });

                    return ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final formattedRole = _formatMemberRole(member.role);

                        final bool isCurrentLogUserCard = user != null &&
                            (member.userId == user.id ||
                                member.name.trim().toLowerCase() ==
                                    user.name!.trim().toLowerCase());

                        final bool canEditMember =
                            (isPastorOrCoord || isUserLeaderOfThisCell) &&
                                !isCurrentLogUserCard;
                        final bool canSeeLeaveButton =
                            isCurrentLogUserCard && !isPastorOrCoord;

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
                                } else if (value == 'transfer') {
                                  _showTransferDialog(member);
                                } else if (value == 'remove') {
                                  _removeMemberCompletely(member);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'role',
                                  child: Text('Alterar Função'),
                                ),
                                if (isPastorOrCoord)
                                  const PopupMenuItem(
                                    value: 'transfer',
                                    child: Text('Transferir de Célula'),
                                  ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text(
                                    'Remover da Célula',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            )
                                : canSeeLeaveButton
                                ? TextButton.icon(
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                              onPressed: () => _leaveCell(member),
                              icon:
                              const Icon(Icons.logout, size: 16),
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
        ),
      ),
    );
  }
}