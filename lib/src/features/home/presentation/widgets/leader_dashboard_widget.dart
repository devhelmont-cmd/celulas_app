import 'package:flutter/material.dart';
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/presentation/pages/cell_detail_page.dart';

class LeaderDashboardWidget extends StatelessWidget {
  final UserEntity user;

  const LeaderDashboardWidget({super.key, required this.user});

  bool _hasUnassignedRoles(CellMeetingModel? meeting) {
    if (meeting == null) return true;
    return (meeting.initialPrayerName == null || meeting.initialPrayerName!.isEmpty) ||
        (meeting.icebreakerName == null || meeting.icebreakerName!.isEmpty) ||
        (meeting.worshipName == null || meeting.worshipName!.isEmpty) ||
        (meeting.wordName == null || meeting.wordName!.isEmpty) ||
        (meeting.finalPrayerName == null || meeting.finalPrayerName!.isEmpty) ||
        (meeting.snackName == null || meeting.snackName!.isEmpty) ||
        (meeting.officialPhotoName == null || meeting.officialPhotoName!.isEmpty) ||
        (meeting.reportFillerName == null || meeting.reportFillerName!.isEmpty);
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

        return StreamBuilder<CellMeetingModel?>(
          stream: dataSource.watchLatestMeeting(cell.id),
          builder: (context, meetingSnapshot) {
            final meeting = meetingSnapshot.data;

            final bool isReportPending = meeting == null || !meeting.isReportFilled;
            final bool areRolesPending = _hasUnassignedRoles(meeting);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isReportPending) ...[
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
                                  'Relatório da Semana Pendente',
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
                            child: const Text('Preencher'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

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