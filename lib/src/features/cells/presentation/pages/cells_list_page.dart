import 'package:flutter/material.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/presentation/pages/cell_detail_page.dart';
import 'package:celulas_app/src/features/cells/presentation/pages/create_cell_page.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
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

                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text('${cell.meetingDay ?? ''} às ${cell.meetingTime ?? ''}'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text('${cell.address ?? ''}'),
                        ],
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