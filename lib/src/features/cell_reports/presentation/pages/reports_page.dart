// lib/src/features/cell_reports/presentation/pages/reports_page.dart
import 'dart:async';
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cell_reports/data/models/cell_report_model.dart';
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
  Map<String, Map<String, String>> _cellReportTopicsMap = {}; // cellId -> {dateKey -> studyTopic}
  CellModel? _leaderCell;

  List<StreamSubscription> _reportSubscriptions = [];

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
    for (var sub in _reportSubscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  void _setupRealtimeListeners(List<CellModel> cells) {
    for (var sub in _reportSubscriptions) {
      sub.cancel();
    }
    _reportSubscriptions.clear();

    for (var cell in cells) {
      final sub = FirebaseFirestore.instance
          .collection('reports')
          .where('cellId', isEqualTo: cell.id)
          .snapshots()
          .listen((snapshot) {
        // Quando houver qualquer alteração na coleção 'reports' (ex: exclusão por admin),
        // reprocessamos a sincronização e atualizamos a tela em tempo real.
        if (mounted) {
          _syncCellReportsAndMeetings(cell);
        }
      });
      _reportSubscriptions.add(sub);
    }
  }

  Future<void> _syncCellReportsAndMeetings(CellModel cell) async {
    try {
      final meetings = await _dataSource.getAllMeetingsForCell(cell.id);
      List<dynamic> reports = [];
      try {
        reports = await _reportsRepository.getReportsByCell(cell.id);
      } catch (_) {}

      Map<String, String> topicsMap = {};
      for (var r in reports) {
        final dateKey = '${r.scheduledDate.year}-${r.scheduledDate.month}-${r.scheduledDate.day}';
        final topic = _extractStudyTopic(r.testimoniesAndNotes);
        if (topic != null && topic.isNotEmpty) {
          topicsMap[dateKey] = topic;
        }
      }

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
            // Relatório foi excluído no Firestore! Volta a ser pendente automaticamente.
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

      if (mounted) {
        setState(() {
          _cellMeetingsMap[cell.id] = syncedMeetings;
          _cellReportTopicsMap[cell.id] = topicsMap;
        });
      }
    } catch (e) {
      debugPrint('Erro ao sincronizar relatórios em tempo real: $e');
    }
  }

  String? _extractStudyTopic(String? notes) {
    if (notes == null || notes.trim().isEmpty) return null;
    for (var line in notes.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Estudo/Tema:')) {
        return trimmed.replaceFirst('Estudo/Tema:', '').trim();
      }
    }
    return null;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = widget.currentUser;
      List<CellModel> cells = [];
      CellModel? foundLeaderCell;

      if (user.isPastorOrCoordinator) {
        cells = await _dataSource.getCells(currentUser: user);
      } else {
        final allCells = await _dataSource.getCells(currentUser: user);

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

        if (cells.isEmpty && allCells.isNotEmpty && user.isLeader) {
          foundLeaderCell = allCells.first;
          cells = [allCells.first];
        }
      }

      for (var cell in cells) {
        await _syncCellReportsAndMeetings(cell);
      }

      _setupRealtimeListeners(cells);

      if (mounted) {
        setState(() {
          _cells = cells;
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

    final topicsMap = _cellReportTopicsMap[cell.id] ?? {};

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

        // Identificação do tipo e tema/nome da reunião
        String meetingTypeDesc = "Reunião Normal";
        Color typeBadgeColor = Colors.blue.shade50;
        Color typeTextColor = Colors.blue.shade800;
        IconData typeIcon = Icons.event;

        final meetingDateKey = '${meeting.meetingDate.year}-${meeting.meetingDate.month}-${meeting.meetingDate.day}';
        final studyTopic = topicsMap[meetingDateKey];

        if (meeting.status == 'bridge_event') {
          meetingTypeDesc = "Evento Ponte: ${meeting.eventName ?? 'Especial'}";
          typeBadgeColor = Colors.indigo.shade50;
          typeTextColor = Colors.indigo.shade800;
          typeIcon = Icons.star;
        } else if (meeting.status == 'canceled') {
          meetingTypeDesc = "Reunião Cancelada";
          typeBadgeColor = Colors.red.shade50;
          typeTextColor = Colors.red.shade800;
          typeIcon = Icons.cancel;
        } else if (meeting.status == 'rescheduled') {
          meetingTypeDesc = "Reunião Remarcada";
          typeBadgeColor = Colors.purple.shade50;
          typeTextColor = Colors.purple.shade800;
          typeIcon = Icons.edit_calendar;
        } else if (studyTopic != null && studyTopic.isNotEmpty) {
          meetingTypeDesc = "Tema: $studyTopic";
          typeBadgeColor = Colors.teal.shade50;
          typeTextColor = Colors.teal.shade800;
          typeIcon = Icons.menu_book;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reunião em $formattedDate',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeBadgeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 14, color: typeTextColor),
                          const SizedBox(width: 4),
                          Text(
                            meeting.status == 'bridge_event'
                                ? 'Evento Ponte'
                                : (meeting.status == 'canceled'
                                ? 'Cancelada'
                                : (studyTopic != null && studyTopic.isNotEmpty ? 'Normal / Tema' : 'Normal')),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: typeTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  meetingTypeDesc,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: typeTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status: $statusLabel',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    PopupMenuButton<String>(
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
                  ],
                ),
                if (meeting.statusNote != null &&
                    meeting.statusNote!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Nota: ${meeting.statusNote}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
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