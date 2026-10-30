// lib/src/features/cell_reports/presentation/pages/fill_report_page.dart
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/core/utils/pastoral_cycle_helper.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cell_reports/data/models/cell_report_model.dart';
import 'package:celulas_app/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/cell_report_entity.dart';

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
  String? _existingReportId;

  ReportStatus _reportStatus = ReportStatus.occurred;
  String _eventType = 'normal';
  late final TextEditingController _cancellationReasonCtrl;
  late final TextEditingController _studyTopicCtrl;
  late final TextEditingController _testimoniesNotesCtrl;
  late final TextEditingController _offeringValueCtrl;

  // Variável para armazenar a chave do ciclo selecionado (ex: "2026-09-06")
  late String _selectedCycleKey;

  // Variável para armazenar a data representada escolhida no calendário (ex: o dia 07/09)
  late DateTime _representedDate;

  List<CellMemberEntity> _members = [];
  Map<String, bool> _attendanceMap = {};

  final Map<String, String?> _meetingRoles = {
    'Oração Inicial': null,
    'Quebra-gelo': null,
    'Louvor': null,
    'Palavra': null,
    'Oração Final': null,
    'Lanche': null,
    'Foto Oficial': null,
    'Preenchimento do Relatório': null,
  };

  final List<String> _allRolesList = [
    'Oração Inicial',
    'Quebra-gelo',
    'Louvor',
    'Palavra',
    'Oração Final',
    'Lanche',
    'Foto Oficial',
    'Preenchimento do Relatório',
  ];

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

    if (widget.meeting.cycleKey != null && widget.meeting.cycleKey!.isNotEmpty) {
      _selectedCycleKey = widget.meeting.cycleKey!;
      // Tenta derivar a data representada inicial a partir da chave do ciclo ou usa a data da reunião
      final parts = _selectedCycleKey.split('-');
      if (parts.length == 3) {
        _representedDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      } else {
        _representedDate = widget.meeting.meetingDate;
      }
    } else {
      _selectedCycleKey = PastoralCycleHelper.getCycleKeyString(widget.meeting.meetingDate);
      _representedDate = widget.meeting.meetingDate;
    }

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

    if (_reportStatus == ReportStatus.bridgeEvent &&
        widget.meeting.eventName != null &&
        widget.meeting.eventName!.trim().isNotEmpty) {
      _studyTopicCtrl.text = widget.meeting.eventName!.trim();
    }

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
        _attendanceMap[member.id] = false;
      }

      final existingReports =
      await _reportsRepository.getReportsByCell(widget.cell.id);

      final existingReport = existingReports.cast<CellReportModel?>().firstWhere(
            (r) =>
        r != null &&
            r.scheduledDate.year == widget.meeting.meetingDate.year &&
            r.scheduledDate.month == widget.meeting.meetingDate.month &&
            r.scheduledDate.day == widget.meeting.meetingDate.day,
        orElse: () => null,
      );

      if (existingReport != null) {
        _existingReportId = existingReport.id;
        _reportStatus = existingReport.status;
        _eventType = existingReport.eventType ?? 'normal';
        if (existingReport.cycleKey != null && existingReport.cycleKey!.isNotEmpty) {
          _selectedCycleKey = existingReport.cycleKey!;
        }
        if (existingReport.cancellationReason != null) {
          _cancellationReasonCtrl.text = existingReport.cancellationReason!;
        }

        if (existingReport.testimoniesAndNotes != null) {
          final notes = existingReport.testimoniesAndNotes!;
          List<String> testimonyLines = [];

          for (var line in notes.split('\n')) {
            final trimmed = line.trim();
            if (trimmed.startsWith('Estudo/Tema:')) {
              _studyTopicCtrl.text =
                  trimmed.replaceFirst('Estudo/Tema:', '').trim();
            } else if (trimmed.startsWith('Oferta: R\$') ||
                trimmed.startsWith('Oferta:')) {
              _offeringValueCtrl.text = trimmed
                  .replaceAll(RegExp(r'Oferta:\s*R\$\s*|Oferta:\s*'), '')
                  .trim();
            } else if (trimmed.startsWith('Testemunhos e Obs:')) {
              testimonyLines
                  .add(trimmed.replaceFirst('Testemunhos e Obs:', '').trim());
            } else if (trimmed.isNotEmpty) {
              testimonyLines.add(trimmed);
            }
          }
          _testimoniesNotesCtrl.text = testimonyLines.join('\n').trim();
        }

        for (var att in existingReport.attendances) {
          _attendanceMap[att.cellMemberId] = att.isPresent;
          for (var role in att.rolesPerformed) {
            if (_meetingRoles.containsKey(role)) {
              _meetingRoles[role] = att.cellMemberId;
            }
          }
        }

        _visitors = existingReport.visitors
            .map((v) => VisitorModel(name: v.name, phone: v.phone))
            .toList();

        _conversions = existingReport.conversions
            .map((v) => VisitorModel(name: v.name, phone: v.phone))
            .toList();
      } else {
        for (var member in members) {
          final mName = member.name.trim().toLowerCase();

          if (widget.meeting.initialPrayerName != null &&
              widget.meeting.initialPrayerName!.trim().toLowerCase() == mName) {
            _meetingRoles['Oração Inicial'] = member.id;
          }
          if (widget.meeting.icebreakerName != null &&
              widget.meeting.icebreakerName!.trim().toLowerCase() == mName) {
            _meetingRoles['Quebra-gelo'] = member.id;
          }
          if (widget.meeting.worshipName != null &&
              widget.meeting.worshipName!.trim().toLowerCase() == mName) {
            _meetingRoles['Louvor'] = member.id;
          }
          if (widget.meeting.wordName != null &&
              widget.meeting.wordName!.trim().toLowerCase() == mName) {
            _meetingRoles['Palavra'] = member.id;
          }
          if (widget.meeting.finalPrayerName != null &&
              widget.meeting.finalPrayerName!.trim().toLowerCase() == mName) {
            _meetingRoles['Oração Final'] = member.id;
          }
          if (widget.meeting.snackName != null &&
              widget.meeting.snackName!.trim().toLowerCase() == mName) {
            _meetingRoles['Lanche'] = member.id;
          }
          if (widget.meeting.officialPhotoName != null &&
              widget.meeting.officialPhotoName!.trim().toLowerCase() == mName) {
            _meetingRoles['Foto Oficial'] = member.id;
          }
          if (widget.meeting.reportFillerName != null &&
              widget.meeting.reportFillerName!.trim().toLowerCase() == mName) {
            _meetingRoles['Preenchimento do Relatório'] = member.id;
          }
        }
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
      _visitors
          .add(VisitorModel(name: name, phone: phone.isEmpty ? null : phone));
      _visitorNameCtrl.clear();
      _visitorPhoneCtrl.clear();
    });
  }

  void _editVisitor(int index) {
    final visitor = _visitors[index];
    final nameCtrl = TextEditingController(text: visitor.name);
    final phoneCtrl = TextEditingController(text: visitor.phone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Visitante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do Visitante',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefone (Opcional)',
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
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Informe o nome do visitante.')),
                );
                return;
              }
              setState(() {
                _visitors[index] = VisitorModel(
                  name: newName,
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
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
      _conversions
          .add(VisitorModel(name: name, phone: phone.isEmpty ? null : phone));
      _conversionNameCtrl.clear();
      _conversionPhoneCtrl.clear();
    });
  }

  void _editConversion(int index) {
    final conversion = _conversions[index];
    final nameCtrl = TextEditingController(text: conversion.name);
    final phoneCtrl = TextEditingController(text: conversion.phone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Conversão / Decisão'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome da Pessoa',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefone (Opcional)',
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
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Informe o nome da pessoa.')),
                );
                return;
              }
              setState(() {
                _conversions[index] = VisitorModel(
                  name: newName,
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
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
      final Map<String, List<String>> memberRolesMap = {};

      if (_reportStatus != ReportStatus.cacelled) {
        _meetingRoles.forEach((role, memberId) {
          if (memberId != null) {
            memberRolesMap.putIfAbsent(memberId, () => []).add(role);
          }
        });
      }

      final List<AttendanceModel> attendances = _members.map((m) {
        if (_reportStatus == ReportStatus.cacelled) {
          return AttendanceModel(
            cellMemberId: m.id,
            isPresent: false,
            isExcused: true,
            rolesPerformed: [],
          );
        }
        final isPresent = _attendanceMap[m.id] ?? false;
        final roles = memberRolesMap[m.id] ?? [];
        return AttendanceModel(
          cellMemberId: m.id,
          isPresent: isPresent,
          rolesPerformed: roles,
          isExcused: false,
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
        notesBuffer
            .writeln('Testemunhos e Obs: ${_testimoniesNotesCtrl.text.trim()}');
      }

      final report = CellReportModel(
        id: _existingReportId ?? '',
        cellId: widget.cell.id,
        scheduledDate: widget.meeting.meetingDate,
        actualDate: DateTime.now(),
        status: _reportStatus,
        eventType: _eventType,
        cancellationReason: _reportStatus == ReportStatus.cacelled
            ? _cancellationReasonCtrl.text.trim()
            : null,
        attendances: attendances,
        visitors: _reportStatus == ReportStatus.cacelled ? [] : _visitors,
        conversions: _reportStatus == ReportStatus.cacelled ? [] : _conversions,
        testimoniesAndNotes: _reportStatus == ReportStatus.cacelled ? null : notesBuffer.toString().trim(),
        filledByUserId: widget.currentUser.id,
        createdAt: DateTime.now(),
        cycleKey: _selectedCycleKey,
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
        cycleKey: _selectedCycleKey,
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

    // Formata o ciclo atual selecionado utilizando a data representada escolhida para exibir no card
    final parts = _selectedCycleKey.split('-');
    String friendlyCycleLabel = _selectedCycleKey;
    if (parts.length == 3) {
      final sundayDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      int weekNumber = ((sundayDate.day - 1) ~/ 7) + 1;
      final monthName = DateFormat('MMMM', 'pt_BR').format(sundayDate);
      final capitalizedMonth = monthName.isNotEmpty
          ? '${monthName[0].toUpperCase()}${monthName.substring(1)}'
          : '';

      friendlyCycleLabel = 'Semana $weekNumber de $capitalizedMonth';
    }

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
            // CICLO SEMANAL DE REFERÊNCIA
            Card(
              elevation: 2,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calendar_view_week, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text(
                          'Ciclo Semanal de Referência',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Este relatório será contabilizado consolidadamente no ciclo semanal abaixo:',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _representedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          helpText: 'Selecione a qual dia/semana a reunião representa',
                        );
                        if (picked != null) {
                          final sunday = PastoralCycleHelper.getCycleSunday(picked);
                          setState(() {
                            _representedDate = picked;
                            _selectedCycleKey = PastoralCycleHelper.getCycleKeyString(sunday);
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                friendlyCycleLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const Icon(Icons.edit_calendar, color: Colors.blue),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // STATUS DA REUNIÃO
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
                      title:
                      const Text('Evento Ponte / Atividade Especial'),
                      value: ReportStatus.bridgeEvent,
                      groupValue: _reportStatus,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _reportStatus = val;
                            _eventType = 'bridge_event';
                            if (widget.meeting.eventName != null &&
                                widget.meeting.eventName!.trim().isNotEmpty &&
                                _studyTopicCtrl.text.trim().isEmpty) {
                              _studyTopicCtrl.text = widget.meeting.eventName!.trim();
                            }
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
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amberAccent),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Como a reunião foi cancelada, nenhum membro receberá falta nem presença (abonado automaticamente), e nenhuma função será contabilizada.',
                                style: TextStyle(fontSize: 12, color: Colors.amberAccent),
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
                      const Text(
                        'Marque quem compareceu à reunião:',
                        style:
                        TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const Divider(height: 20),
                      _members.isEmpty
                          ? const Text(
                          'Nenhum membro vinculado a esta célula.')
                          : ListView.separated(
                        shrinkWrap: true,
                        physics:
                        const NeverScrollableScrollPhysics(),
                        itemCount: _members.length,
                        separatorBuilder: (_, __) =>
                        const Divider(height: 8),
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          final isPresent =
                              _attendanceMap[member.id] ?? false;

                          final memberRoles = _meetingRoles.entries
                              .where((entry) =>
                          entry.value == member.id)
                              .map((entry) => entry.key)
                              .toList();

                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              member.name,
                              style: TextStyle(
                                fontWeight: isPresent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Função na Célula: ${member.role}'),
                                if (memberRoles.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Wrap(
                                    spacing: 4,
                                    children: memberRoles
                                        .map((r) => Chip(
                                      label: Text(r,
                                          style:
                                          const TextStyle(
                                              fontSize:
                                              10)),
                                      backgroundColor:
                                      Colors
                                          .blue.shade50,
                                      padding:
                                      EdgeInsets.zero,
                                      materialTapTargetSize:
                                      MaterialTapTargetSize
                                          .shrinkWrap,
                                    ))
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                            value: isPresent,
                            onChanged: (val) {
                              setState(() {
                                _attendanceMap[member.id] =
                                    val ?? false;
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

              // ATRIBUIÇÃO DE FUNÇÕES DA REUNIÃO
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
                        'Funções Realizadas na Reunião',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Defina quem liderou cada parte nesta reunião:',
                        style:
                        TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const Divider(height: 20),
                      ..._allRolesList.map((role) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: DropdownButtonFormField<String?>(
                            value: _meetingRoles[role],
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: role,
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'Nenhum / Não atribuído',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              ..._members.map((m) => DropdownMenuItem<String?>(
                                value: m.id,
                                child: Text(m.name),
                              )),
                            ],
                            onChanged: (selectedId) {
                              setState(() {
                                _meetingRoles[role] = selectedId;
                              });
                            },
                          ),
                        );
                      }),
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
                              leading: const Icon(Icons.person,
                                  color: Colors.blue),
                              title: Text(v.name),
                              subtitle:
                              Text(v.phone ?? 'Sem telefone'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue, size: 20),
                                    onPressed: () => _editVisitor(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _visitors.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
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
                            style: IconButton.styleFrom(
                                backgroundColor: Colors.green),
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
                              leading: const Icon(Icons.favorite,
                                  color: Colors.green),
                              title: Text(c.name),
                              subtitle:
                              Text(c.phone ?? 'Sem telefone'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue, size: 20),
                                    onPressed: () => _editConversion(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _conversions.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
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
                        keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
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