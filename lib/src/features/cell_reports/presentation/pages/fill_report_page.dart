// lib/src/features/cell_reports/presentation/pages/fill_report_page.dart
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cell_reports/data/models/cell_report_model.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:flutter/material.dart';

class FillReportPage extends StatefulWidget {
  final CellEntity cell;
  final CellMeetingModel meeting;
  final UserEntity currentUser;

  const FillReportPage({
    super.key,
    required this.cell,
    required this.meeting,
    required this.currentUser,
  });

  @override
  State<FillReportPage> createState() => _FillReportPageState();
}

class _FillReportPageState extends State<FillReportPage> {
  late final ICellReportsRepository _reportsRepository;
  late final ICellRemoteDataSource _cellDataSource;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _existingReportId; // Variável para armazenar o ID do relatório caso já exista

  ReportStatus _reportStatus = ReportStatus.occurred;
  String _eventType = 'normal';
  late final TextEditingController _cancellationReasonCtrl;
  late final TextEditingController _studyTopicCtrl;
  late final TextEditingController _testimoniesNotesCtrl;
  late final TextEditingController _offeringValueCtrl;

  List<CellMemberEntity> _members = [];
  Map<String, bool> _attendanceMap = {};
  Map<String, List<String>> _memberRolesPerformed = {};

  List<VisitorModel> _visitors = [];
  List<VisitorModel> _conversions = [];

  final _visitorNameCtrl = TextEditingController();
  final _visitorPhoneCtrl = TextEditingController();

  final _conversionNameCtrl = TextEditingController();
  final _conversionPhoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reportsRepository = getIt<ICellReportsRepository>();
    _cellDataSource = getIt<ICellRemoteDataSource>();

    // Pré-preenche os campos com base na configuração da reunião atual
    if (widget.meeting.status == 'canceled') {
      _reportStatus = ReportStatus.cacelled;
      _eventType = 'normal';
    } else if (widget.meeting.status == 'bridge_event') {
      _reportStatus = ReportStatus.bridgeEvent;
      _eventType = 'bridge_event';
    } else {
      _reportStatus = ReportStatus.occurred;
      _eventType = 'normal';
    }

    _cancellationReasonCtrl = TextEditingController(
      text: widget.meeting.statusNote ?? '',
    );
    _studyTopicCtrl = TextEditingController();
    _testimoniesNotesCtrl = TextEditingController();
    _offeringValueCtrl = TextEditingController();

    _loadData();
  }

  @override
  void dispose() {
    _cancellationReasonCtrl.dispose();
    _studyTopicCtrl.dispose();
    _testimoniesNotesCtrl.dispose();
    _offeringValueCtrl.dispose();
    _visitorNameCtrl.dispose();
    _visitorPhoneCtrl.dispose();
    _conversionNameCtrl.dispose();
    _conversionPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final members = await _cellDataSource.getCellMembers(widget.cell.id);

      for (var member in members) {
        _attendanceMap[member.id] = true;
        _memberRolesPerformed[member.id] = [];
      }

      final existingReports =
      await _reportsRepository.getReportsByCell(widget.cell.id);

      // Procura relatório existente para esta exata reunião/data
      final existingReport = existingReports.cast<CellReportModel?>().firstWhere(
            (r) =>
        r != null &&
            r.scheduledDate.year == widget.meeting.meetingDate.year &&
            r.scheduledDate.month == widget.meeting.meetingDate.month &&
            r.scheduledDate.day == widget.meeting.meetingDate.day,
        orElse: () => null,
      );

      if (existingReport != null) {
        _existingReportId = existingReport.id; // Armazena o ID do relatório existente para edição
        _reportStatus = existingReport.status;
        _eventType = existingReport.eventType ?? 'normal';
        if (existingReport.cancellationReason != null) {
          _cancellationReasonCtrl.text = existingReport.cancellationReason!;
        }

        if (existingReport.testimoniesAndNotes != null) {
          final notes = existingReport.testimoniesAndNotes!;
          _testimoniesNotesCtrl.text = notes;

          // Tenta extrair valores salvos anteriormente para os campos individuais, se houver
          for (var line in notes.split('\n')) {
            if (line.startsWith('Estudo/Tema:')) {
              _studyTopicCtrl.text = line.replaceFirst('Estudo/Tema:', '').trim();
            } else if (line.startsWith('Oferta: R\$')) {
              _offeringValueCtrl.text = line.replaceFirst('Oferta: R\$', '').trim();
            }
          }
        }

        for (var att in existingReport.attendances) {
          _attendanceMap[att.cellMemberId] = att.isPresent;
          _memberRolesPerformed[att.cellMemberId] =
          List<String>.from(att.rolesPerformed);
        }

        _visitors = existingReport.visitors
            .map((v) => VisitorModel(name: v.name, phone: v.phone))
            .toList();

        _conversions = existingReport.conversions
            .map((v) => VisitorModel(name: v.name, phone: v.phone))
            .toList();
      }

      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Erro ao carregar dados do relatório: $e');
    }
  }

  void _addVisitor() {
    final name = _visitorNameCtrl.text.trim();
    final phone = _visitorPhoneCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do visitante.')),
      );
      return;
    }

    setState(() {
      _visitors.add(VisitorModel(name: name, phone: phone.isEmpty ? null : phone));
      _visitorNameCtrl.clear();
      _visitorPhoneCtrl.clear();
    });
  }

  void _addConversion() {
    final name = _conversionNameCtrl.text.trim();
    final phone = _conversionPhoneCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome da pessoa que se decidiu.')),
      );
      return;
    }

    setState(() {
      _conversions.add(VisitorModel(name: name, phone: phone.isEmpty ? null : phone));
      _conversionNameCtrl.clear();
      _conversionPhoneCtrl.clear();
    });
  }

  Future<void> _submitReport() async {
    if (_reportStatus == ReportStatus.cacelled &&
        _cancellationReasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o motivo do cancelamento da reunião.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final List<AttendanceModel> attendances = _members.map((m) {
        final isPresent = _attendanceMap[m.id] ?? false;
        final roles = _memberRolesPerformed[m.id] ?? [];
        return AttendanceModel(
          cellMemberId: m.id,
          isPresent: isPresent,
          rolesPerformed: roles,
        );
      }).toList();

      StringBuffer notesBuffer = StringBuffer();
      if (_studyTopicCtrl.text.trim().isNotEmpty) {
        notesBuffer.writeln('Estudo/Tema: ${_studyTopicCtrl.text.trim()}');
      }
      if (_offeringValueCtrl.text.trim().isNotEmpty) {
        notesBuffer.writeln('Oferta: R\$ ${_offeringValueCtrl.text.trim()}');
      }
      if (_testimoniesNotesCtrl.text.trim().isNotEmpty) {
        notesBuffer.writeln('Testemunhos e Obs: ${_testimoniesNotesCtrl.text.trim()}');
      }

      final report = CellReportModel(
        id: _existingReportId ?? '', // Passa o ID existente se houver, garantindo atualização em vez de duplicação
        cellId: widget.cell.id,
        scheduledDate: widget.meeting.meetingDate,
        actualDate: DateTime.now(),
        status: _reportStatus,
        eventType: _eventType,
        cancellationReason: _reportStatus == ReportStatus.cacelled
            ? _cancellationReasonCtrl.text.trim()
            : null,
        attendances: attendances,
        visitors: _visitors,
        conversions: _conversions,
        testimoniesAndNotes: notesBuffer.toString().trim(),
        filledByUserId: widget.currentUser.id,
        createdAt: DateTime.now(),
      );

      await _reportsRepository.saveReport(report);

      final updatedMeeting = CellMeetingModel(
        id: widget.meeting.id,
        cellId: widget.cell.id,
        meetingDate: widget.meeting.meetingDate,
        status: _reportStatus == ReportStatus.cacelled
            ? 'canceled'
            : (_eventType == 'bridge_event' ? 'bridge_event' : 'normal'),
        statusNote: _cancellationReasonCtrl.text.trim(),
        eventName: widget.meeting.eventName,
        meetingTime: widget.meeting.meetingTime,
        meetingLocation: widget.meeting.meetingLocation,
        initialPrayerName: widget.meeting.initialPrayerName,
        icebreakerName: widget.meeting.icebreakerName,
        worshipName: widget.meeting.worshipName,
        wordName: widget.meeting.wordName,
        finalPrayerName: widget.meeting.finalPrayerName,
        snackName: widget.meeting.snackName,
        officialPhotoName: widget.meeting.officialPhotoName,
        reportFillerName: widget.meeting.reportFillerName,
        isReportFilled: true,
      );

      await _cellDataSource.saveOrUpdateMeeting(updatedMeeting);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Relatório salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar relatório: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        '${widget.meeting.meetingDate.day.toString().padLeft(2, '0')}/${widget.meeting.meetingDate.month.toString().padLeft(2, '0')}/${widget.meeting.meetingDate.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Relatório - $formattedDate'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CARD STATUS REUNIÃO
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
                    const Text(
                      'Status da Reunião',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<ReportStatus>(
                      title: const Text('Houve a Célula / Reunião Normal'),
                      value: ReportStatus.occurred,
                      groupValue: _reportStatus,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _reportStatus = val;
                            _eventType = 'normal';
                          });
                        }
                      },
                    ),
                    RadioListTile<ReportStatus>(
                      title: const Text('Evento Ponte / Atividade Especial'),
                      value: ReportStatus.bridgeEvent,
                      groupValue: _reportStatus,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _reportStatus = val;
                            _eventType = 'bridge_event';
                          });
                        }
                      },
                    ),
                    RadioListTile<ReportStatus>(
                      title: const Text('Não Houve Célula / Cancelada'),
                      value: ReportStatus.cacelled,
                      groupValue: _reportStatus,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _reportStatus = val;
                          });
                        }
                      },
                    ),
                    if (_reportStatus == ReportStatus.cacelled) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _cancellationReasonCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Motivo do Cancelamento',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (_reportStatus != ReportStatus.cacelled) ...[
              const SizedBox(height: 20),

              // LISTA DE FREQUÊNCIA DOS MEMBROS
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Frequência dos Membros',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Presentes: ${_attendanceMap.values.where((v) => v).length}/${_members.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      _members.isEmpty
                          ? const Text('Nenhum membro vinculado a esta célula.')
                          : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _members.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          final isPresent = _attendanceMap[member.id] ?? false;

                          return CheckboxListTile(
                            title: Text(
                              member.name,
                              style: TextStyle(
                                fontWeight: isPresent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text('Função: ${member.role}'),
                            value: isPresent,
                            onChanged: (val) {
                              setState(() {
                                _attendanceMap[member.id] = val ?? false;
                              });
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // VISITANTES
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
                      const Text(
                        'Visitantes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _visitorNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nome do Visitante',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _visitorPhoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Telefone (Opcional)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _addVisitor,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      if (_visitors.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _visitors.length,
                          itemBuilder: (context, index) {
                            final v = _visitors[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.person, color: Colors.blue),
                              title: Text(v.name),
                              subtitle: Text(v.phone ?? 'Sem telefone'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _visitors.removeAt(index);
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // DECISÕES / CONVERSÕES
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
                      const Text(
                        'Decisões / Conversões',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _conversionNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nome da Pessoa',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _conversionPhoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Telefone',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: _addConversion,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      if (_conversions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _conversions.length,
                          itemBuilder: (context, index) {
                            final c = _conversions[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.favorite, color: Colors.green),
                              title: Text(c.name),
                              subtitle: Text(c.phone ?? 'Sem telefone'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _conversions.removeAt(index);
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ESTUDO, OFERTA E TESTEMUNHOS
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
                      const Text(
                        'Detalhes da Reunião',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _studyTopicCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tema ou Estudo Ministrado',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _offeringValueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Valor da Oferta (R\$)',
                          border: OutlineInputBorder(),
                          prefixText: 'R\$ ',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _testimoniesNotesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Testemunhos e Observações Gerais',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving ? null : _submitReport,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Salvar Relatório',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}