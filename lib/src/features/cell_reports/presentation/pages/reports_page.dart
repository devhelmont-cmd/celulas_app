// lib/src/features/cell_reports/presentation/pages/reports_page.dart
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/pages/fill_report_page.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/presentation/pages/cell_detail_page.dart';
import 'package:celulas_app/src/features/home/presentation/widgets/leader_dashboard_widget.dart';
import 'package:celulas_app/src/features/home/presentation/widgets/member_dashboard_widget.dart';
import 'package:celulas_app/src/features/home/presentation/widgets/pastor_dashboard_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReportsPage extends StatefulWidget {
  final UserEntity currentUser;

  const ReportsPage({super.key, required this.currentUser});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with TickerProviderStateMixin {
  late final ICellRemoteDataSource _dataSource;
  late final ICellReportsRepository _reportsRepository;
  TabController? _tabController;

  bool _isLoading = true;
  List<CellModel> _cells = [];
  Map<String, List<CellMeetingModel>> _cellMeetingsMap = {};
  CellModel? _leaderCell;

  @override
  void initState() {
    super.initState();
    _dataSource = getIt<ICellRemoteDataSource>();
    _reportsRepository = getIt<ICellReportsRepository>();

    final bool isPureMember =
        widget.currentUser.isMember &&
        !widget.currentUser.isLeader &&
        !widget.currentUser.isPastorOrCoordinator;
    if (!isPureMember) {
      _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    }
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = widget.currentUser;
      List<CellModel> cells = [];
      CellModel? foundLeaderCell;

      // 1. Se for Pastor/Coordenador, busca todas as células
      if (user.isPastorOrCoordinator) {
        cells = await _dataSource.getCells(currentUser: user);
      } else {
        // Busca geral para cruzamento seguro
        final allCells = await _dataSource.getCells(currentUser: user);

        // 2. Tenta buscar diretamente pelo primaryCellId
        if (user.primaryCellId != null &&
            user.primaryCellId!.trim().isNotEmpty) {
          try {
            final cell = allCells.firstWhere((c) => c.id == user.primaryCellId);
            cells = [cell];
            foundLeaderCell = cell;
          } catch (_) {
            try {
              final cell = await _dataSource.getCellById(user.primaryCellId!);
              cells = [cell];
              foundLeaderCell = cell;
            } catch (e) {
              debugPrint('Erro ao buscar célula por primaryCellId: $e');
            }
          }
        }

        // 3. Se não achou por primaryCellId, busca por leaderId na lista de células
        if (cells.isEmpty) {
          for (var c in allCells) {
            if (c.leaderId == user.id ||
                (user.name != null &&
                    c.leaderId?.trim().toLowerCase() ==
                        user.name!.trim().toLowerCase())) {
              foundLeaderCell = c;
              cells = [c];
              break;
            }
          }
        }

        // 4. Se ainda não achou, verifica na coleção 'members' se o usuário é membro/líder vinculado a alguma célula
        if (cells.isEmpty) {
          try {
            final firestore = FirebaseFirestore.instance;
            final memberSnap =
                await firestore
                    .collection('members')
                    .where('userId', isEqualTo: user.id)
                    .get();

            for (var doc in memberSnap.docs) {
              final data = doc.data();
              final cellId = data['cellId'] as String?;
              if (cellId != null && cellId.trim().isNotEmpty) {
                try {
                  final cell = allCells.firstWhere((c) => c.id == cellId);
                  foundLeaderCell = cell;
                  cells = [cell];
                  break;
                } catch (_) {
                  try {
                    final cell = await _dataSource.getCellById(cellId);
                    foundLeaderCell = cell;
                    cells = [cell];
                    break;
                  } catch (__) {}
                }
              }
            }
          } catch (e) {
            debugPrint('Erro ao buscar membros por userId para relatório: $e');
          }
        }

        // 5. Fallback final para líder caso nenhuma condição anterior tenha pego
        if (cells.isEmpty && allCells.isNotEmpty && user.isLeader) {
          foundLeaderCell = allCells.first;
          cells = [allCells.first];
        }
      }

      Map<String, List<CellMeetingModel>> meetingsMap = {};

      for (var cell in cells) {
        final meetings = await _dataSource.getAllMeetingsForCell(cell.id);

        // Proteção contra falha de índice ou coleção vazia
        List<dynamic> reports = [];
        try {
          reports = await _reportsRepository.getReportsByCell(cell.id);
        } catch (e) {
          debugPrint(
            'Aviso: Não foi possível carregar relatórios (índice pendente ou coleção vazia): $e',
          );
        }

        // Sincroniza estado de reuniões com relatórios no banco
        List<CellMeetingModel> syncedMeetings = [];
        for (var meeting in meetings) {
          if (meeting.isReportFilled) {
            final exists = reports.any(
                  (r) =>
              r.scheduledDate.year == meeting.meetingDate.year &&
                  r.scheduledDate.month == meeting.meetingDate.month &&
                  r.scheduledDate.day == meeting.meetingDate.day,
            );
            if (!exists) {
              final correctedMeeting = CellMeetingModel(
                id: meeting.id,
                cellId: meeting.cellId,
                meetingDate: meeting.meetingDate,
                status: meeting.status,
                statusNote: meeting.statusNote,
                eventName: meeting.eventName,
                meetingTime: meeting.meetingTime,
                meetingLocation: meeting.meetingLocation,
                initialPrayerName: meeting.initialPrayerName,
                icebreakerName: meeting.icebreakerName,
                worshipName: meeting.worshipName,
                wordName: meeting.wordName,
                finalPrayerName: meeting.finalPrayerName,
                snackName: meeting.snackName,
                officialPhotoName: meeting.officialPhotoName,
                reportFillerName: meeting.reportFillerName,
                isReportFilled: false,
              );
              await _dataSource.saveOrUpdateMeeting(correctedMeeting);
              syncedMeetings.add(correctedMeeting);
              continue;
            }
          }
          syncedMeetings.add(meeting);
        }

        meetingsMap[cell.id] = syncedMeetings;
      }

      if (mounted) {
        setState(() {
          _cells = cells;
          _cellMeetingsMap = meetingsMap;
          _leaderCell =
              foundLeaderCell ?? (cells.isNotEmpty ? cells.first : null);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Erro ao carregar dados de relatórios: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isPureMember =
        user.isMember && !user.isLeader && !user.isPastorOrCoordinator;
    if (isPureMember) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard da Célula')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [MemberDashboardWidget(user: user)],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão & Relatórios'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboards'),
            Tab(icon: Icon(Icons.description), text: 'Relatórios'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildDashboardsTab(user), _buildReportsTab(user)],
      ),
    );
  }

  Widget _buildDashboardsTab(UserEntity user) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (user.isPastorOrCoordinator) ...[
          const PastorDashboardWidget(),
        ] else if (user.isLeader) ...[
          LeaderDashboardWidget(
            user: user,
            onNavigateToReports: () => _tabController?.animateTo(1),
          ),
        ],
      ],
    );
  }

  Widget _buildReportsTab(UserEntity user) {
    if (user.isLeader) {
      if (_leaderCell == null) {
        return const Center(
          child: Text('Você não está vinculado a uma célula principal.'),
        );
      }

      final meetings = _cellMeetingsMap[_leaderCell!.id] ?? [];

      return RefreshIndicator(
        onRefresh: _loadData,
        child: _buildCellMeetingsList(
          _leaderCell!,
          meetings,
          isLeaderView: true,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _cells.length,
        itemBuilder: (context, index) {
          final cell = _cells[index];
          final meetings = _cellMeetingsMap[cell.id] ?? [];
          final bool hasPending = meetings.any(
            (m) => m.isExpired && !m.isReportFilled,
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    hasPending ? Colors.amber.shade100 : Colors.green.shade100,
                child: Icon(
                  hasPending ? Icons.warning_amber_rounded : Icons.check_circle,
                  color:
                      hasPending
                          ? Colors.amber.shade800
                          : Colors.green.shade800,
                ),
              ),
              title: Text(
                cell.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                hasPending
                    ? 'Possui relatórios pendentes'
                    : 'Todos os relatórios em dia',
                style: TextStyle(
                  color:
                      hasPending
                          ? Colors.orange.shade800
                          : Colors.green.shade800,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => CellDetailPage(
                          cell: cell,
                          currentUser: user,
                          initialTabIndex: 1,
                        ),
                  ),
                ).then((_) => _loadData());
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCellMeetingsList(
    CellEntity cell,
    List<CellMeetingModel> meetings, {
    bool isLeaderView = false,
  }) {
    if (meetings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event_note, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Nenhuma reunião registrada para esta célula ainda.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => CellDetailPage(
                            cell: cell,
                            currentUser: widget.currentUser,
                            initialTabIndex: 1,
                            autoOpenEditMeeting: false,
                          ),
                    ),
                  ).then((_) => _loadData());
                },
                child: const Text('Configurar Reunião / Relatório'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        final formattedDate =
            '${meeting.meetingDate.day.toString().padLeft(2, '0')}/${meeting.meetingDate.month.toString().padLeft(2, '0')}/${meeting.meetingDate.year}';
        final isFilled = meeting.isReportFilled;
        final isPastMeeting = meeting.isExpired;

        String statusLabel = "Aguardando Reunião";
        Color statusColor = Colors.blue.shade700;

        if (isFilled) {
          statusLabel = "Preenchido (OK)";
          statusColor = Colors.green;
        } else if (isPastMeeting) {
          statusLabel = "Pendente de Preenchimento";
          statusColor = Colors.orange.shade800;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              'Reunião em $formattedDate',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Status: $statusLabel',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (meeting.statusNote != null &&
                    meeting.statusNote!.isNotEmpty) ...[
                  Text(
                    'Nota: ${meeting.statusNote}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'fill' || action == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => FillReportPage(
                            cell: cell,
                            meeting: meeting,
                            currentUser: widget.currentUser,
                          ),
                    ),
                  ).then((_) => _loadData());
                } else if (action == 'config') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => CellDetailPage(
                            cell: cell,
                            currentUser: widget.currentUser,
                            initialTabIndex: 1,
                            autoOpenEditMeeting: false,
                          ),
                    ),
                  ).then((_) => _loadData());
                } else if (action == 'delete_request') {
                  _showDeletionRequestDialog(cell.id, meeting.id);
                } else if (action == 'admin_delete' &&
                    widget.currentUser.isPastorOrCoordinator) {
                  _showAdminDeleteDialog(cell.id, meeting.id);
                }
              },
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value:
                          isFilled
                              ? 'edit'
                              : (isPastMeeting ? 'fill' : 'config'),
                      child: Text(
                        isFilled
                            ? 'Editar Relatório'
                            : (isPastMeeting
                                ? 'Preencher Relatório'
                                : 'Configurar Reunião'),
                      ),
                    ),
                    if (isLeaderView && isFilled)
                      const PopupMenuItem(
                        value: 'delete_request',
                        child: Text(
                          'Solicitar Exclusão',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    if (widget.currentUser.isPastorOrCoordinator)
                      const PopupMenuItem(
                        value: 'admin_delete',
                        child: Text(
                          'Excluir Relatório (Pastor)',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
            ),
          ),
        );
      },
    );
  }

  void _showDeletionRequestDialog(String cellId, String meetingId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Solicitar Exclusão de Relatório'),
            content: TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo da solicitação para o pastor',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (reasonController.text.trim().isEmpty) return;
                  await _dataSource.requestReportDeletion(
                    cellId,
                    meetingId,
                    reasonController.text.trim(),
                  );
                  Navigator.pop(ctx);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Solicitação enviada ao pastor com sucesso!',
                      ),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
                child: const Text('Enviar'),
              ),
            ],
          ),
    );
  }

  void _showAdminDeleteDialog(String cellId, String meetingId) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Excluir Relatório'),
            content: const Text(
              'Tem certeza de que deseja excluir este relatório permanentemente?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  await _dataSource.deleteMeetingReport(cellId, meetingId);
                  Navigator.pop(ctx);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Relatório excluído com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text(
                  'Excluir',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}
