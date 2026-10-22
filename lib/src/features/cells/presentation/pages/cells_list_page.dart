// lib/src/features/cells/presentation/pages/cells_list_page.dart
import 'package:flutter/material.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/presentation/pages/cell_detail_page.dart';
import 'package:celulas_app/src/features/cells/presentation/pages/create_cell_page.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/core/injections/injection_container.dart';

class CellsListPage extends StatelessWidget {
  final List<CellEntity> cells;
  final VoidCallback onRefresh;
  final UserEntity? currentUser;

  const CellsListPage({
    super.key,
    required this.cells,
    required this.onRefresh,
    this.currentUser,
  });

  bool _isMeetingExpired(CellMeetingModel? meeting) {
    if (meeting == null) return true;
    final targetDate = meeting.meetingDate;
    final expiry = DateTime(targetDate.year, targetDate.month, targetDate.day + 1);
    return DateTime.now().isAfter(expiry);
  }

  @override
  Widget build(BuildContext context) {
    final dataSource = getIt<ICellRemoteDataSource>();
    final canCreateCell = currentUser?.isPastorOrCoordinator ?? false;
    final isMemberOnly = currentUser != null && currentUser!.isMember && !currentUser!.isPastorOrCoordinator && !currentUser!.isLeader;

    final sortedCells = List<CellEntity>.from(cells);

    sortedCells.sort((a, b) {
      final bool isCellAUser = currentUser != null &&
          (a.id == currentUser!.primaryCellId || a.leaderId == currentUser!.id);

      final bool isCellBUser = currentUser != null &&
          (b.id == currentUser!.primaryCellId || b.leaderId == currentUser!.id);

      if (isCellAUser && !isCellBUser) return -1;
      if (!isCellAUser && isCellBUser) return 1;

      final nameA = a.name ?? '';
      final nameB = b.name ?? '';
      return nameA.toLowerCase().compareTo(nameB.toLowerCase());
    });

    return Scaffold(
      floatingActionButton: canCreateCell
          ? FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateCellPage(),
            ),
          );
          onRefresh();
        },
        label: const Text('Nova Célula'),
        icon: const Icon(Icons.add),
      )
          : null,
      body: sortedCells.isEmpty
          ? const Center(
        child: Text('Nenhuma célula encontrada.'),
      )
          : RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedCells.length,
          itemBuilder: (context, index) {
            final cell = sortedCells[index];
            final isLeaderEmpty =
                cell.leaderId == null || cell.leaderId!.trim().isEmpty;

            final bool canViewRequests = currentUser != null &&
                (currentUser!.isPastorOrCoordinator ||
                    (currentUser!.isLeader && cell.leaderId == currentUser!.id));

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CellDetailPage(
                        cell: cell,
                        currentUser: currentUser,
                      ),
                    ),
                  );
                  onRefresh();
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            cell.name ?? 'Sem Nome',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (cell.category != null)
                            Chip(
                              label: Text(cell.category!),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (!isLeaderEmpty || !isMemberOnly) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 16,
                              color: isLeaderEmpty ? Colors.red : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            isLeaderEmpty
                                ? const Text(
                              'Líder: Sem líder definido',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                                : FutureBuilder<String?>(
                              key: ValueKey('leader_list_${cell.id}_${cell.leaderId}'),
                              future: dataSource.getUserNameById(cell.leaderId!),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Text(
                                    'Líder: Carregando...',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                }
                                final leaderName =
                                    snapshot.data ?? cell.leaderId!;
                                return Text(
                                  'Líder: $leaderName',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Exibição Dinâmica e Verificação de Status/Funções/Relatórios
                      FutureBuilder<List<CellMeetingModel>>(
                        future: dataSource.getAllMeetingsForCell(cell.id),
                        builder: (context, meetingSnapshot) {
                          if (!meetingSnapshot.hasData) {
                            return const SizedBox.shrink();
                          }
                          final meetings = meetingSnapshot.data!;

                          CellMeetingModel? latestMeeting = meetings.isNotEmpty ? meetings.first : null;
                          final bool isLatestExpired = _isMeetingExpired(latestMeeting);
                          final activeMeeting = isLatestExpired ? null : latestMeeting;
                          final status = activeMeeting?.status ?? 'normal';

                          // Verifica se há relatórios pendentes (reuniões expiradas sem relatório preenchido)
                          final bool hasPendingReport = meetings.any((m) => m.isExpired && !m.isReportFilled);

                          bool areRolesPending = false;
                          bool areRolesDefined = false;

                          if (activeMeeting != null && activeMeeting.status != 'canceled') {
                            areRolesDefined = (activeMeeting.initialPrayerName != null && activeMeeting.initialPrayerName!.trim().isNotEmpty && activeMeeting.initialPrayerName != 'Não definido') ||
                                (activeMeeting.icebreakerName != null && activeMeeting.icebreakerName!.trim().isNotEmpty && activeMeeting.icebreakerName != 'Não definido') ||
                                (activeMeeting.worshipName != null && activeMeeting.worshipName!.trim().isNotEmpty && activeMeeting.worshipName != 'Não definido') ||
                                (activeMeeting.wordName != null && activeMeeting.wordName!.trim().isNotEmpty && activeMeeting.wordName != 'Não definido');

                            areRolesPending = !areRolesDefined;
                          } else if (activeMeeting == null) {
                            areRolesPending = true;
                          }

                          String displayLabel;
                          String displayValue;
                          String displayAddress;

                          if (activeMeeting != null && (status == 'bridge_event' || status == 'rescheduled')) {
                            final formattedDate = '${activeMeeting.meetingDate.day.toString().padLeft(2, '0')}/${activeMeeting.meetingDate.month.toString().padLeft(2, '0')}/${activeMeeting.meetingDate.year}';
                            final time = activeMeeting.meetingTime ?? cell.meetingTime ?? '';
                            displayLabel = status == 'bridge_event' ? 'Data do Evento' : 'Data Remarcada';
                            displayValue = '$formattedDate às $time';
                            displayAddress = activeMeeting.meetingLocation?.isNotEmpty == true ? activeMeeting.meetingLocation! : (cell.address ?? '');
                          } else {
                            displayLabel = 'Reuniões';
                            displayValue = '${cell.meetingDay ?? ''} às ${cell.meetingTime ?? ''}';
                            displayAddress = cell.address ?? '';
                          }

                          final bool isPastorOrCoord = currentUser?.isPastorOrCoordinator ?? false;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('$displayLabel: $displayValue')),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(displayAddress)),
                                ],
                              ),

                              // Avisos específicos para Pastor / Coordenador
                              if (isPastorOrCoord) ...[
                                if (hasPendingReport) ...[
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: const [
                                        Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Aviso: Relatório pendente nesta célula',
                                            style: TextStyle(
                                              color: Colors.orangeAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (areRolesPending) ...[
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: const [
                                        Icon(Icons.assignment_late_outlined, size: 16, color: Colors.deepOrange),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Aviso: Funções da próxima reunião pendentes',
                                            style: TextStyle(
                                              color: Colors.deepOrange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],

                              // Status especial ou reunião normal com funções definidas
                              if (status != 'normal') ...[
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
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
                                        size: 16,
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
                                              ? 'Evento Ponte: ${activeMeeting!.eventName ?? activeMeeting.statusNote ?? ""}'
                                              : status == 'canceled'
                                              ? 'Reunião Cancelada: ${activeMeeting!.statusNote ?? ""}'
                                              : 'Reunião Remarcada: ${activeMeeting!.meetingTime ?? ""} (${activeMeeting.meetingLocation ?? ""})',
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
                              ] else if (areRolesDefined) ...[
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.edit_calendar, size: 16, color: Colors.green),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Reunião padrão',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),

                      if (canViewRequests) ...[
                        const SizedBox(height: 8),
                        FutureBuilder<List>(
                          future: dataSource.getPendingRequestsForCell(cell.id),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                              return Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.notification_important, size: 16, color: Colors.orange),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Há ${snapshot.data!.length} solicitação(ões) pendente(s)',
                                      style: const TextStyle(
                                        color: Colors.orangeAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}