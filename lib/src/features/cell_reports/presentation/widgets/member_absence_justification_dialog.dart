import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/injections/injection_container.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../cells/data/datasources/cell_remote_datasource.dart';
import '../../domain/entities/cell_report_entity.dart';
import '../../domain/repositories/i_cell_reports_repository.dart';

class MemberAbsenceJustificationDialog extends StatefulWidget {
  final UserEntity currentUser;
  final String? cellId;

  const MemberAbsenceJustificationDialog({
    super.key,
    required this.currentUser,
    this.cellId,
  });

  static Future<void> show(BuildContext context, {required UserEntity currentUser, String? cellId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MemberAbsenceJustificationDialog(
        currentUser: currentUser,
        cellId: cellId,
      ),
    );
  }

  @override
  State<MemberAbsenceJustificationDialog> createState() =>
      _MemberAbsenceJustificationDialogState();
}

class _MemberAbsenceJustificationDialogState
    extends State<MemberAbsenceJustificationDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final ICellReportsRepository _reportsRepo;
  late final ICellRemoteDataSource _cellDataSource;

  bool _isLoading = true;
  List<_AbsenceItem> _unjustifiedItems = [];
  List<_AbsenceItem> _processedItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _reportsRepo = getIt<ICellReportsRepository>();
    _cellDataSource = getIt<ICellRemoteDataSource>();
    _loadAbsences();
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  bool _isDateWithinPeriods(
    DateTime meetingDate,
    String cellId,
    List<dynamic> periods,
  ) {
    final targetDate = _dateOnly(meetingDate);
    final cellPeriods = periods.where((p) => p.cellId == cellId);

    if (cellPeriods.isEmpty) return false;

    for (final period in cellPeriods) {
      final start = _dateOnly(period.startDate);
      final end = period.endDate != null ? _dateOnly(period.endDate!) : null;

      final afterOrEqualStart = !targetDate.isBefore(start);
      final beforeOrEqualEnd = end == null || !targetDate.isAfter(end);

      if (afterOrEqualStart && beforeOrEqualEnd) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadAbsences() async {
    setState(() => _isLoading = true);
    try {
      final user = widget.currentUser;

      // Busca TODOS os relatórios do sistema para abranger histórico de todas as células (atuais e passadas)
      List<CellReportEntity> reports = await _reportsRepo.getAllReports();

      final normalizedUserName = user.name?.trim().toLowerCase() ?? '';
      final userId = user.id;

      // Recupera ID do membro e seus períodos nas células
      String? cellMemberId;
      List<dynamic> loadedPeriods = [];
      try {
        final allMembers = await _cellDataSource.getAllMembers();
        for (var m in allMembers) {
          final mUserId = m['userId']?.toString() ?? '';
          final mId = m['id']?.toString() ?? '';
          final mName = m['name']?.toString() ?? '';

          if ((mUserId.isNotEmpty && mUserId == userId) ||
              mId == userId ||
              (normalizedUserName.isNotEmpty &&
                  mName.trim().toLowerCase() == normalizedUserName)) {
            cellMemberId = mId;
            break;
          }
        }

        if (cellMemberId != null && cellMemberId.isNotEmpty) {
          loadedPeriods = await _cellDataSource.getMemberPeriods(cellMemberId);
        }
      } catch (_) {}

      final Set<String> candidateIds = {
        userId,
        if (cellMemberId != null) cellMemberId,
      };

      List<_AbsenceItem> unjustified = [];
      List<_AbsenceItem> processed = [];

      for (var report in reports) {
        if (report.status == ReportStatus.cacelled) continue;

        // Procura registro de presença explícito no relatório
        AttendanceEntity? att = report.attendances
            .cast<AttendanceEntity?>()
            .firstWhere(
              (a) => a != null && (
              candidateIds.contains(a.cellMemberId) ||
                  (normalizedUserName.isNotEmpty &&
                      a.memberName?.trim().toLowerCase() == normalizedUserName)
          ),
          orElse: () => null,
        );

        // Verifica se a reunião ocorreu durante um período válido do membro nesta célula
        final bool isWithinHistory = loadedPeriods.isNotEmpty &&
            _isDateWithinPeriods(
              report.scheduledDate,
              report.cellId,
              loadedPeriods,
            );

        if (att == null && isWithinHistory) {
          att = AttendanceEntity(
            cellMemberId: cellMemberId ?? userId,
            memberName: user.name,
            isPresent: false,
          );
        }

        if (att == null) continue;
        if (att.isExcused) continue;

        // Se estava presente e sem reivindicação pendente, não é falta
        if (att.isPresent &&
            att.justificationStatus != 'presence_claim_pending' &&
            att.justificationStatus != 'presence_claimed_approved') {
          continue;
        }

        final item = _AbsenceItem(
          reportId: report.id,
          cellMemberId: att.cellMemberId,
          meetingDate: report.scheduledDate,
          attendance: att,
        );

        if (att.justificationStatus == 'none' ||
            att.justificationStatus == 'justification_rejected' ||
            att.justificationStatus == 'presence_claim_rejected') {
          unjustified.add(item);
        } else {
          processed.add(item);
        }
      }

      // Ordena mais recentes primeiro
      unjustified.sort((a, b) => b.meetingDate.compareTo(a.meetingDate));
      processed.sort((a, b) => b.meetingDate.compareTo(a.meetingDate));

      if (mounted) {
        setState(() {
          _unjustifiedItems = unjustified;
          _processedItems = processed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar faltas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitJustification(
      _AbsenceItem item, String justificationReason) async {
    try {
      await _reportsRepo.updateAttendanceJustification(
        reportId: item.reportId,
        cellMemberId: item.cellMemberId,
        justificationStatus: 'justification_pending',
        justificationReason: justificationReason,
        justifiedByUserId: widget.currentUser.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Justificativa enviada para aprovação do líder!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadAbsences();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar justificativa: $e')),
        );
      }
    }
  }

  Future<void> _submitPresenceClaim(_AbsenceItem item) async {
    try {
      await _reportsRepo.updateAttendanceJustification(
        reportId: item.reportId,
        cellMemberId: item.cellMemberId,
        justificationStatus: 'presence_claim_pending',
        justificationReason: 'Membro sinalizou presença na reunião',
        justifiedByUserId: widget.currentUser.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Sinalização de presença enviada para validação do líder!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      _loadAbsences();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao sinalizar presença: $e')),
        );
      }
    }
  }

  Future<void> _submitAcknowledge(_AbsenceItem item) async {
    try {
      await _reportsRepo.updateAttendanceJustification(
        reportId: item.reportId,
        cellMemberId: item.cellMemberId,
        justificationStatus: 'acknowledged',
        justifiedByUserId: widget.currentUser.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ciência registrada para esta falta.'),
          ),
        );
      }
      _loadAbsences();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao dar ciência: $e')),
        );
      }
    }
  }

  Future<void> _cancelRequest(_AbsenceItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Solicitação'),
        content: const Text(
          'Deseja cancelar este pedido? A falta voltará para a lista de pendentes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Não'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, Cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _reportsRepo.updateAttendanceJustification(
          reportId: item.reportId,
          cellMemberId: item.cellMemberId,
          justificationStatus: 'none',
          justificationReason: null,
          isPresent: false,
          justifiedByUserId: widget.currentUser.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solicitação cancelada. A falta voltou para pendentes.'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        _loadAbsences();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao cancelar solicitação: $e')),
          );
        }
      }
    }
  }

  void _showJustifyDialog(_AbsenceItem item) {
    final controller = TextEditingController(
      text: item.attendance.justificationReason ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Justificar Falta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reunião do dia ${DateFormat('dd/MM/yyyy').format(item.meetingDate)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Digite o motivo da falta (ex: viagem, saúde, trabalho)...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                _submitJustification(item, text);
              }
            },
            child: const Text('Enviar Justificativa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Faltas e Justificativas'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: _unjustifiedItems.isEmpty
                  ? 'Pendentes'
                  : 'Pendentes (${_unjustifiedItems.length})',
            ),
            const Tab(text: 'Histórico & Processadas'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUnjustifiedList(),
                _buildProcessedList(),
              ],
            ),
    );
  }

  Widget _buildUnjustifiedList() {
    if (_unjustifiedItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
              SizedBox(height: 16),
              Text(
                'Nenhuma falta pendente!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Todas as suas faltas já foram justificadas ou têm ciência informada.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _unjustifiedItems.length,
      itemBuilder: (context, index) {
        final item = _unjustifiedItems[index];
        final formattedDate =
            DateFormat('dd/MM/yyyy (EEEE)', 'pt_BR').format(item.meetingDate);
        final att = item.attendance;
        final isRejected = att.justificationStatus == 'justification_rejected' ||
            att.justificationStatus == 'presence_claim_rejected';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isRejected ? Colors.red.shade300 : Colors.orange.shade300,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_busy,
                      color: isRejected ? Colors.red : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Falta em: $formattedDate',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isRejected) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sua solicitação anterior foi recusada pelo líder/pastor. Você pode tentar novamente.',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Escolha uma das 3 opções abaixo:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => _showJustifyDialog(item),
                        icon: const Icon(Icons.edit_note, size: 16),
                        label: const Text('Justificar', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => _submitPresenceClaim(item),
                        icon: const Icon(Icons.how_to_reg, size: 16),
                        label: const Text('Presença', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          foregroundColor: Colors.grey.shade700,
                        ),
                        onPressed: () => _submitAcknowledge(item),
                        icon: const Icon(Icons.visibility_off_outlined, size: 16),
                        label: const Text('Ciência', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProcessedList() {
    if (_processedItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('Nenhuma justificativa ou ciência registrada no histórico.'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _processedItems.length,
      itemBuilder: (context, index) {
        final item = _processedItems[index];
        final formattedDate =
            DateFormat('dd/MM/yyyy').format(item.meetingDate);
        final att = item.attendance;

        String statusLabel = 'Processado';
        Color badgeColor = Colors.grey;
        IconData icon = Icons.info_outline;

        if (att.justificationStatus == 'presence_claimed_approved') {
          statusLabel = 'Presença Confirmada (Sinalização Aceita)';
          badgeColor = Colors.green.shade700;
          icon = Icons.check_circle;
        } else if (att.justificationStatus == 'presence_claim_pending') {
          statusLabel = 'Presença Reivindicada (Aguardando Aprovação)';
          badgeColor = Colors.blue.shade800;
          icon = Icons.how_to_reg;
        } else if (att.justificationStatus == 'justification_pending') {
          statusLabel = 'Justificativa Enviada (Aguardando Aprovação)';
          badgeColor = Colors.amber.shade800;
          icon = Icons.hourglass_top;
        } else if (att.justificationStatus == 'justified_approved' ||
            (att.isJustified &&
                att.justificationStatus != 'presence_claimed_approved')) {
          statusLabel = 'Falta Justificada (Aprovada pelo Líder)';
          badgeColor = Colors.green.shade700;
          icon = Icons.verified;
        } else if (att.justificationStatus == 'acknowledged') {
          statusLabel = 'Ciência Confirmada (Falta Não Justificada)';
          badgeColor = Colors.grey.shade700;
          icon = Icons.visibility_outlined;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: badgeColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reunião de $formattedDate',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (val) {
                        if (val == 'edit') {
                          _showJustifyDialog(item);
                        } else if (val == 'cancel') {
                          _cancelRequest(item);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Alterar / Justificar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Row(
                            children: [
                              Icon(Icons.undo, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Cancelar Pedido (Voltar a Pendente)'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
                if (att.justificationReason != null &&
                    att.justificationReason!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Motivo: "${att.justificationReason}"',
                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AbsenceItem {
  final String reportId;
  final String cellMemberId;
  final DateTime meetingDate;
  final AttendanceEntity attendance;

  _AbsenceItem({
    required this.reportId,
    required this.cellMemberId,
    required this.meetingDate,
    required this.attendance,
  });
}