// lib/src/features/home/presentation/widgets/leader_dashboard_widget.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/presentation/pages/cell_detail_page.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/pages/reports_page.dart';

class LeaderDashboardWidget extends StatelessWidget {
  final UserEntity user;
  final VoidCallback? onNavigateToReports;
  final VoidCallback? onNavigateToCells; // Callback para navegar para a aba de células (Aba 1)

  const LeaderDashboardWidget({
    super.key,
    required this.user,
    this.onNavigateToReports,
    this.onNavigateToCells,
  });

  bool _hasUnassignedRoles(CellMeetingModel? meeting) {
    if (meeting == null) return true;
    if (meeting.status == 'canceled') return false;

    return (meeting.initialPrayerName == null || meeting.initialPrayerName!.isEmpty) ||
        (meeting.icebreakerName == null || meeting.icebreakerName!.isEmpty) ||
        (meeting.worshipName == null || meeting.worshipName!.isEmpty) ||
        (meeting.wordName == null || meeting.wordName!.isEmpty) ||
        (meeting.finalPrayerName == null || meeting.finalPrayerName!.isEmpty) ||
        (meeting.snackName == null || meeting.snackName!.isEmpty) ||
        (meeting.officialPhotoName == null || meeting.officialPhotoName!.isEmpty) ||
        (meeting.reportFillerName == null || meeting.reportFillerName!.isEmpty);
  }

  Future<int> _fetchPendingJoinRequestsCount(String cellId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('cell_requests')
          .where('cellId', isEqualTo: cellId)
          .where('status', isEqualTo: 'pending')
          .get();
      return snapshot.docs.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _fetchPendingJustificationsCount(String cellId) async {
    try {
      final repo = getIt<ICellReportsRepository>();
      final reports = await repo.getReportsByCell(cellId);
      int count = 0;
      for (var r in reports) {
        for (var att in r.attendances) {
          if (att.isPendingApproval) count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryCellId = user.primaryCellId;

    if (primaryCellId == null || primaryCellId.trim().isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Você ainda não está vinculado a uma célula principal.'),
        ),
      );
    }

    final dataSource = getIt<ICellRemoteDataSource>();

    return FutureBuilder<CellEntity>(
      future: dataSource.getCellById(primaryCellId),
      builder: (context, cellSnapshot) {
        if (cellSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!cellSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        final cell = cellSnapshot.data!;

        return FutureBuilder<List<dynamic>>(
          future: Future.wait([
            dataSource.getAllMeetingsForCell(cell.id),
            if (!user.isPastorOrCoordinator)
              _fetchPendingJoinRequestsCount(cell.id)
            else
              Future.value(0),
            _fetchPendingJustificationsCount(cell.id),
          ]),
          builder: (context, snapshot) {
            final data = snapshot.data;
            final meetings = (data != null && data.isNotEmpty) ? (data[0] as List<CellMeetingModel>) : <CellMeetingModel>[];
            final pendingRequestsCount = (data != null && data.length > 1) ? (data[1] as int) : 0;
            final pendingJustificationsCount = (data != null && data.length > 2) ? (data[2] as int) : 0;

            final latestMeeting = meetings.isNotEmpty ? meetings.first : null;

            final bool hasAnyPendingReport = meetings.any((m) => m.isExpired && !m.isReportFilled);
            final bool areRolesPending = _hasUnassignedRoles(latestMeeting);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Aviso de Solicitação de Entrada
                if (!user.isPastorOrCoordinator && pendingRequestsCount > 0) ...[
                  Card(
                    color: Colors.blue.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.blue.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_add,
                            color: Colors.blue,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$pendingRequestsCount Solicitação(ões) de Entrada',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Usuários aguardando aprovação para entrar na célula.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (onNavigateToCells != null) {
                                onNavigateToCells!();
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CellDetailPage(
                                      cell: cell,
                                      currentUser: user,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: const Text('Ver'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 1.5. Aviso de Justificativa / Presença Pendente de Aprovação
                if (pendingJustificationsCount > 0) ...[
                  Card(
                    color: Colors.amber.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.amber.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_user,
                            color: Colors.amber,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Justificativas Pendentes ($pendingJustificationsCount)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.brown,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Membros enviaram justificativa ou sinalizaram presença aguardando sua validação.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.brown.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CellDetailPage(
                                    cell: cell,
                                    currentUser: user,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Analisar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 2. Relatório(s) Pendente(s)
                if (hasAnyPendingReport) ...[
                  Card(
                    color: Colors.amber.shade100,
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Relatório(s) Pendente(s)',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  cell.name ?? 'Minha Célula',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (onNavigateToReports != null) {
                                onNavigateToReports!();
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReportsPage(currentUser: user),
                                  ),
                                );
                              }
                            },
                            child: const Text('Ver Relatórios'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 3. Atribuição de Funções Pendente
                if (areRolesPending) ...[
                  Card(
                    color: Colors.orange.shade100,
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.assignment_ind_outlined,
                            color: Colors.deepOrange,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Atribuição de Funções Pendente',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Defina os responsáveis pela próxima reunião',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CellDetailPage(
                                    cell: cell,
                                    currentUser: user,
                                    initialTabIndex: 1,
                                    autoOpenEditMeeting: true,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Atribuir'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        );
      },
    );
  }
}