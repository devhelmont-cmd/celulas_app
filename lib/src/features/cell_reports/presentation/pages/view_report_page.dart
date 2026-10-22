// lib/src/features/cell_reports/presentation/pages/view_report_page.dart
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cell_reports/data/models/cell_report_model.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/pages/fill_report_page.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:flutter/material.dart';

class ViewReportPage extends StatefulWidget {
  final CellEntity cell;
  final CellMeetingModel meeting;
  final UserEntity currentUser;

  const ViewReportPage({
    super.key,
    required this.cell,
    required this.meeting,
    required this.currentUser,
  });

  @override
  State<ViewReportPage> createState() => _ViewReportPageState();
}

class _ViewReportPageState extends State<ViewReportPage> {
  late final ICellReportsRepository _reportsRepository;
  late final ICellRemoteDataSource _cellDataSource;

  bool _isLoading = true;
  CellReportModel? _report;
  List<CellMemberEntity> _members = [];
  Map<String, String> _memberNamesMap = {};

  String? _studyTopic;
  String? _offeringValue;
  String? _testimoniesAndNotes;

  @override
  void initState() {
    super.initState();
    _reportsRepository = getIt<ICellReportsRepository>();
    _cellDataSource = getIt<ICellRemoteDataSource>();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final members = await _cellDataSource.getCellMembers(widget.cell.id);
      final memberMap = {for (var m in members) m.id: m.name};

      final reports =
      await _reportsRepository.getReportsByCell(widget.cell.id);

      final foundReport = reports.cast<CellReportModel?>().firstWhere(
            (r) =>
        r != null &&
            r.scheduledDate.year == widget.meeting.meetingDate.year &&
            r.scheduledDate.month == widget.meeting.meetingDate.month &&
            r.scheduledDate.day == widget.meeting.meetingDate.day,
        orElse: () => null,
      );

      if (foundReport != null && foundReport.testimoniesAndNotes != null) {
        final notes = foundReport.testimoniesAndNotes!;
        List<String> testimonyLines = [];

        for (var line in notes.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('Estudo/Tema:')) {
            _studyTopic = trimmed.replaceFirst('Estudo/Tema:', '').trim();
          } else if (trimmed.startsWith('Oferta:')) {
            _offeringValue = trimmed.replaceFirst('Oferta:', '').trim();
          } else if (trimmed.startsWith('Testemunhos e Obs:')) {
            testimonyLines
                .add(trimmed.replaceFirst('Testemunhos e Obs:', '').trim());
          } else if (trimmed.isNotEmpty) {
            testimonyLines.add(trimmed);
          }
        }
        _testimoniesAndNotes =
        testimonyLines.isNotEmpty ? testimonyLines.join('\n') : null;
      }

      if (mounted) {
        setState(() {
          _members = members;
          _memberNamesMap = memberMap;
          _report = foundReport;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Erro ao carregar dados do relatório para visualização: $e');
    }
  }

  String _formatDateWithWeekday(DateTime date) {
    const weekdays = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo'
    ];
    final weekdayName = weekdays[date.weekday - 1];
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$weekdayName, $day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = _formatDateWithWeekday(widget.meeting.meetingDate);

    final canEdit = widget.currentUser.isPastorOrCoordinator ||
        widget.currentUser.isLeader;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Relatório'),
        actions: [
          if (canEdit && _report != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar Relatório',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FillReportPage(
                      cell: widget.cell,
                      meeting: widget.meeting,
                      currentUser: widget.currentUser,
                    ),
                  ),
                ).then((updated) {
                  if (updated == true) _loadReportData();
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
          ? const Center(
        child: Text('Nenhum relatório encontrado para esta reunião.'),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CABEÇALHO DA REUNIÃO
            _buildHeaderCard(formattedDate),

            const SizedBox(height: 16),

            if (_report!.status == ReportStatus.cacelled) ...[
              _buildCancellationCard(),
            ] else ...[
              // RESUMO NUMÉRICO
              _buildSummaryMetrics(),

              const SizedBox(height: 16),

              // DETALHES DO ESTUDO E OFERTA
              if ((_studyTopic != null && _studyTopic!.isNotEmpty) ||
                  (_offeringValue != null &&
                      _offeringValue!.isNotEmpty) ||
                  (_testimoniesAndNotes != null &&
                      _testimoniesAndNotes!.isNotEmpty))
                _buildMeetingDetailsCard(),

              const SizedBox(height: 16),

              // FREQUÊNCIA DOS MEMBROS
              _buildAttendanceCard(),

              const SizedBox(height: 16),

              // VISITANTES
              if (_report!.visitors.isNotEmpty) ...[
                _buildVisitorsCard(),
                const SizedBox(height: 16),
              ],

              // CONVERSÕES / DECISÕES
              if (_report!.conversions.isNotEmpty) ...[
                _buildConversionsCard(),
                const SizedBox(height: 16),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String formattedDate) {
    String statusTitle = "Reunião Realizada";
    Color headerBg = Colors.teal.shade50;
    Color headerText = Colors.teal.shade900;
    IconData icon = Icons.check_circle_outline;

    if (_report!.status == ReportStatus.cacelled) {
      statusTitle = "Reunião Cancelada";
      headerBg = Colors.red.shade50;
      headerText = Colors.red.shade900;
      icon = Icons.cancel_outlined;
    } else if (_report!.status == ReportStatus.bridgeEvent) {
      statusTitle = "Evento Ponte / Especial";
      headerBg = Colors.blue.shade50;
      headerText = Colors.blue.shade900;
      icon = Icons.star_border;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: headerText.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: headerText, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: headerText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Célula: ${widget.cell.name}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Data: $formattedDate',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationCard() {
    return Card(
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Motivo do Cancelamento:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _report!.cancellationReason ?? 'Nenhum motivo informado.',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetrics() {
    final presentCount =
        _report!.attendances.where((a) => a.isPresent).length;
    final totalMembers = _report!.attendances.length;
    final visitorsCount = _report!.visitors.length;
    final conversionsCount = _report!.conversions.length;

    return Row(
      children: [
        _buildMetricBox(
          'Membros',
          '$presentCount/$totalMembers',
          Icons.people,
          Colors.blue,
        ),
        const SizedBox(width: 8),
        _buildMetricBox(
          'Visitantes',
          '$visitorsCount',
          Icons.person_add_alt_1,
          Colors.orange,
        ),
        const SizedBox(width: 8),
        _buildMetricBox(
          'Decisões',
          '$conversionsCount',
          Icons.favorite,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildMetricBox(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingDetailsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informações do Estudo & Oferta',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 16),
            if (_studyTopic != null && _studyTopic!.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.menu_book, size: 18, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 13),
                        children: [
                          const TextSpan(
                            text: 'Tema / Estudo: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: _studyTopic),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (_offeringValue != null && _offeringValue!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.payments_outlined,
                      size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  RichText(
                    text: TextSpan(
                      style:
                      const TextStyle(color: Colors.black87, fontSize: 13),
                      children: [
                        const TextSpan(
                          text: 'Oferta: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: _offeringValue),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (_testimoniesAndNotes != null &&
                _testimoniesAndNotes!.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Testemunhos & Observações:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _testimoniesAndNotes!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Frequência & Funções Realizadas',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _report!.attendances.length,
              separatorBuilder: (_, __) => const Divider(height: 8),
              itemBuilder: (context, index) {
                final att = _report!.attendances[index];
                final memberName =
                    _memberNamesMap[att.cellMemberId] ?? 'Membro Removido';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      att.isPresent
                          ? Icons.check_circle
                          : Icons.cancel_outlined,
                      color: att.isPresent ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memberName,
                            style: TextStyle(
                              fontWeight: att.isPresent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: att.isPresent
                                  ? Colors.black87
                                  : Colors.grey.shade700,
                            ),
                          ),
                          if (att.rolesPerformed.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: att.rolesPerformed
                                  .map(
                                    (role) => Chip(
                                  label: Text(
                                    role,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor: Colors.blue.shade50,
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitorsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add_alt_1, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Visitantes (${_report!.visitors.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ..._report!.visitors.map((v) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading:
                const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
                title: Text(v.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle:
                v.phone != null ? Text('Telefone: ${v.phone}') : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildConversionsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Decisões / Conversões (${_report!.conversions.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ..._report!.conversions.map((c) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.green,
                  child: Icon(Icons.favorite, size: 14, color: Colors.white),
                ),
                title: Text(c.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle:
                c.phone != null ? Text('Telefone: ${c.phone}') : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}