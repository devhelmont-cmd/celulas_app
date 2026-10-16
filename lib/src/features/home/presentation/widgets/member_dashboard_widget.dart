import 'package:flutter/material.dart';
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/cells/data/models/prayer_request_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/presentation/pages/cell_detail_page.dart';

class MemberDashboardWidget extends StatelessWidget {
  final UserEntity user;

  const MemberDashboardWidget({super.key, required this.user});

  bool _isMeetingExpired(CellMeetingModel? meeting) {
    if (meeting == null) return true;
    final targetDate = meeting.meetingDate;
    final expiry = DateTime(targetDate.year, targetDate.month, targetDate.day + 1);
    return DateTime.now().isAfter(expiry);
  }

  Future<void> _showAddPrayerDialog(BuildContext context, String cellId) async {
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
      final newReq = PrayerRequestModel(
        id: '',
        cellId: cellId,
        authorId: user.id,
        authorName: user.name ?? user.email.split('@').first,
        request: ctrl.text.trim(),
        createdAt: DateTime.now(),
      );
      final dataSource = getIt<ICellRemoteDataSource>();
      await dataSource.addPrayerRequest(newReq);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido de oração cadastrado!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showEditPrayerDialog(
      BuildContext context,
      PrayerRequestModel prayer,
      ) async {
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deletePrayer(
      BuildContext context,
      PrayerRequestModel prayer,
      ) async {
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
      if (context.mounted) {
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
    if (user.primaryCellId == null || user.primaryCellId!.trim().isEmpty) {
      return const Center(
        child: Text('Você não está vinculado a nenhuma célula ativa.'),
      );
    }

    final dataSource = getIt<ICellRemoteDataSource>();

    return FutureBuilder<CellEntity>(
      future: dataSource.getCellById(user.primaryCellId!),
      builder: (context, cellSnapshot) {
        if (cellSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!cellSnapshot.hasData) {
          return const Center(child: Text('Célula não encontrada.'));
        }

        final cell = cellSnapshot.data!;

        return StreamBuilder<CellMeetingModel?>(
          stream: dataSource.watchLatestMeeting(cell.id),
          builder: (context, meetingSnapshot) {
            final rawMeeting = meetingSnapshot.data;
            final meeting = _isMeetingExpired(rawMeeting) ? null : rawMeeting;
            final status = meeting?.status ?? 'normal';

            // Determina dinamicamente rótulo e valor sem dar a entender que é o padrão semanal
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
              displayValue = '${cell.meetingDay ?? 'Dia a definir'} às ${cell.meetingTime ?? 'Horário a definir'}';
              displayAddress = cell.address ?? 'Endereço não informado';
            }

            final userName = user.name?.trim().toLowerCase() ?? '';

            List<String> assignedRoles = [];
            if (meeting != null) {
              if (meeting.initialPrayerName?.trim().toLowerCase() == userName) {
                assignedRoles.add('Oração Inicial');
              }
              if (meeting.icebreakerName?.trim().toLowerCase() == userName) {
                assignedRoles.add('Quebra-gelo');
              }
              if (meeting.worshipName?.trim().toLowerCase() == userName) {
                assignedRoles.add('Louvor');
              }
              if (meeting.wordName?.trim().toLowerCase() == userName) {
                assignedRoles.add('Palavra');
              }
              if (meeting.finalPrayerName?.trim().toLowerCase() == userName) {
                assignedRoles.add('Oração Final');
              }
              if (meeting.snackName?.trim().toLowerCase() == userName) {
                assignedRoles.add('Lanche');
              }
              if (meeting.officialPhotoName?.trim().toLowerCase() == userName) {
                assignedRoles.add('Foto Oficial');
              }
              if (meeting.reportFillerName?.trim().toLowerCase() == userName) {
                assignedRoles.add('Preenchimento do Relatório');
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
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
                  borderRadius: BorderRadius.circular(12),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.church, color: Colors.deepPurple),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Minha Célula: ${cell.name ?? 'Sem Nome'}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text('$displayLabel: $displayValue')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(displayAddress),
                              ),
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
                                          ? 'Evento Ponte: ${meeting?.eventName ?? meeting?.statusNote ?? ""}'
                                          : status == 'canceled'
                                          ? 'Reunião Cancelada: ${meeting?.statusNote ?? ""}'
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
                          if (assignedRoles.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star_outline,
                                    size: 18,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Sua função na próxima reunião: ${assignedRoles.join(", ")}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.brown,
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
                ),
                const SizedBox(height: 16),
                Text(
                  'Interações',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddPrayerDialog(context, cell.id),
                        icon: const Icon(Icons.favorite_outline),
                        label: const Text('Pedir Oração'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'A justificativa de faltas estará disponível em breve.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.event_busy_outlined),
                        label: const Text('Justificar Falta'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Meus Pedidos de Oração',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddPrayerDialog(context, cell.id),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Novo'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<PrayerRequestModel>>(
                  stream: dataSource.watchPrayerRequests(cell.id),
                  builder: (context, prayerSnapshot) {
                    if (prayerSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allPrayers = prayerSnapshot.data ?? [];
                    final myPrayers = allPrayers.where((p) {
                      return p.authorId == user.id ||
                          (user.name != null &&
                              p.authorName.trim().toLowerCase() ==
                                  user.name!.trim().toLowerCase());
                    }).toList();

                    if (myPrayers.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'Você não possui pedidos de oração cadastrados.',
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: myPrayers.length,
                      itemBuilder: (context, index) {
                        final prayer = myPrayers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.volunteer_activism, size: 20),
                            ),
                            title: Text(prayer.request),
                            subtitle: Text(
                              'Status: ${prayer.isAnswered ? "Respondido" : "Em oração"}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _showEditPrayerDialog(
                                    context,
                                    prayer,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deletePrayer(context, prayer),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}