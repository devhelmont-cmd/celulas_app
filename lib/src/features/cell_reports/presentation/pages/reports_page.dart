// lib/src/features/cell_reports/presentation/pages/reports_page.dart
import 'dart:async';
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/core/utils/pastoral_cycle_helper.dart'; // <--- Importe o helper de ciclos
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/pages/fill_report_page.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/pages/view_report_page.dart';
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

import '../widgets/pastor_analytics_widget.dart';

enum ReportViewMode { leader, pastoral }

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
  bool _isInitialLoad = true;
  List<CellModel> _cells = [];
  Map<String, List<CellMeetingModel>> _cellMeetingsMap = {};
  Map<String, Map<String, String>> _cellReportTopicsMap = {};
  CellModel? _leaderCell;

  ReportViewMode _currentViewMode = ReportViewMode.leader;
  CellModel? _selectedPastoralCell;

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
      _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
      _tabController?.addListener(() {
        if (mounted) setState(() {});
      });
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
        final dateKey =
            '${r.scheduledDate.year}-${r.scheduledDate.month}-${r.scheduledDate.day}';
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
            final correctedMeeting = CellMeetingModel(
              id: meeting.id,
              cellId: meeting.cellId,
              meetingDate: meeting.meetingDate,
              status: meeting.status,
              statusNote: meeting.statusNote,
              eventName: meeting.eventName,
              meetingTime: meeting.meetingTime,
              meetingLocation: meeting.meetingLocation,
              cycleKey: meeting.cycleKey,
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

      final allCells = await _dataSource.getCells(currentUser: user);

      if (user.primaryCellId != null && user.primaryCellId!.trim().isNotEmpty) {
        try {
          foundLeaderCell = allCells.firstWhere(
                (c) => c.id == user.primaryCellId,
          );
        } catch (_) {}
      }

      if (foundLeaderCell == null) {
        for (var c in allCells) {
          if (c.leaderId == user.id ||
              (user.name != null &&
                  c.leaderId?.trim().toLowerCase() ==
                      user.name!.trim().toLowerCase())) {
            foundLeaderCell = c;
            break;
          }
        }
      }

      if (user.isPastorOrCoordinator) {
        allCells.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

        cells = allCells;
        if (_isInitialLoad) {
          _currentViewMode =
          (foundLeaderCell != null)
              ? ReportViewMode.leader
              : ReportViewMode.pastoral;
        }
      } else {
        if (foundLeaderCell != null) {
          cells = [foundLeaderCell];
        } else {
          cells = allCells;
        }
        _currentViewMode = ReportViewMode.leader;
      }

      for (var cell in cells) {
        await _syncCellReportsAndMeetings(cell);
      }

      _setupRealtimeListeners(cells);

      if (mounted) {
        setState(() {
          _cells = cells;
          _leaderCell = foundLeaderCell;
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Erro ao carregar dados de relatórios: $e');
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
      'Domingo',
    ];
    final weekdayName = weekdays[date.weekday - 1];
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$weekdayName, $day/$month/$year';
  }

  CellEntity? _getActiveTargetCell() {
    if (_currentViewMode == ReportViewMode.leader) {
      return _leaderCell;
    } else if (_currentViewMode == ReportViewMode.pastoral) {
      return _selectedPastoralCell;
    }
    return null;
  }

  DateTime _calculateDefaultManualDate(String? meetingDayStr) {
    final now = DateTime.now();
    int targetWeekday = 2;

    if (meetingDayStr != null && meetingDayStr.trim().isNotEmpty) {
      final lower = meetingDayStr.toLowerCase().trim();
      if (lower.contains('segunda')) {
        targetWeekday = DateTime.monday;
      } else if (lower.contains('terça') || lower.contains('terca')) {
        targetWeekday = DateTime.tuesday;
      } else if (lower.contains('quarta')) {
        targetWeekday = DateTime.wednesday;
      } else if (lower.contains('quinta')) {
        targetWeekday = DateTime.thursday;
      } else if (lower.contains('sexta')) {
        targetWeekday = DateTime.friday;
      } else if (lower.contains('sábado') || lower.contains('sabado')) {
        targetWeekday = DateTime.saturday;
      } else if (lower.contains('domingo')) {
        targetWeekday = DateTime.sunday;
      }
    }

    DateTime candidate = DateTime(now.year, now.month, now.day);
    while (candidate.weekday != targetWeekday) {
      candidate = candidate.subtract(const Duration(days: 1));
    }

    if (candidate.year == now.year && candidate.month == now.month && candidate.day == now.day) {
      candidate = candidate.subtract(const Duration(days: 7));
    }

    return candidate;
  }

  void _showAddManualReportDialog(CellEntity cell) {
    DateTime selectedDate = _calculateDefaultManualDate(cell.meetingDay);

    final dateController = TextEditingController(
      text: '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
    );

    String defaultTimeStr = (cell.meetingTime != null && cell.meetingTime!.trim().isNotEmpty)
        ? cell.meetingTime!
        : '19:30';

    TimeOfDay selectedTime = TimeOfDay(
      hour: int.tryParse(defaultTimeStr.split(':').first) ?? 19,
      minute: int.tryParse(defaultTimeStr.split(':').last) ?? 30,
    );

    final timeController = TextEditingController(
      text: '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
    );

    final defaultLocation = [cell.address, cell.neighborhood]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');
    final locationController = TextEditingController(text: defaultLocation);

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
        builder:
            (context, setDialogState) => AlertDialog(
          title: const Text('Adicionar Relatório Manual / Passado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Célula: ${cell.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Data da Reunião *',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = picked;
                        dateController.text =
                        '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Horário da Reunião',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedTime = picked;
                        timeController.text =
                        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Local da Reunião',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final formattedTime =
                    '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                await _createManualMeetingAndOpenFill(
                  cell,
                  selectedDate,
                  formattedTime,
                  locationController.text.trim(),
                );
              },
              child: const Text('Continuar para Preenchimento'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createManualMeetingAndOpenFill(
      CellEntity cell,
      DateTime meetingDate,
      String time,
      String location,
      ) async {
    try {
      final dateId =
          '${meetingDate.year}-${meetingDate.month.toString().padLeft(2, '0')}-${meetingDate.day.toString().padLeft(2, '0')}';

      String? defaultReportFiller;
      try {
        final members = await _dataSource.getCellMembers(cell.id);
        final leader = members.cast<dynamic?>().firstWhere(
              (m) =>
          m != null &&
              (m.role.toLowerCase() == 'lider' ||
                  m.role.toLowerCase() == 'leader' ||
                  m.role.toLowerCase() == 'líder'),
          orElse: () => null,
        );
        if (leader != null && leader.name.isNotEmpty) {
          defaultReportFiller = leader.name;
        } else {
          final coLeader = members.cast<dynamic?>().firstWhere(
                (m) =>
            m != null &&
                (m.role.toLowerCase() == 'colider' ||
                    m.role.toLowerCase() == 'co-leader' ||
                    m.role.toLowerCase() == 'co-líder'),
            orElse: () => null,
          );
          defaultReportFiller =
          coLeader?.name.isNotEmpty == true
              ? coLeader!.name
              : widget.currentUser.name;
        }
      } catch (_) {
        defaultReportFiller = widget.currentUser.name;
      }

      final meetings = _cellMeetingsMap[cell.id] ?? [];
      CellMeetingModel? existingMeeting = meetings
          .cast<CellMeetingModel?>()
          .firstWhere(
            (m) =>
        m != null &&
            m.meetingDate.year == meetingDate.year &&
            m.meetingDate.month == meetingDate.month &&
            m.meetingDate.day == meetingDate.day,
        orElse: () => null,
      );

      CellMeetingModel meetingToUse;
      if (existingMeeting != null) {
        meetingToUse = existingMeeting;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Já existe um registro para esta data. Abrindo reunião existente...',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Calcula a chave de ciclo pastoral baseada na data da reunião manual
        final cycleKeyStr = PastoralCycleHelper.getCycleKeyString(meetingDate);

        meetingToUse = CellMeetingModel(
          id: dateId,
          cellId: cell.id,
          meetingDate: meetingDate,
          status: 'normal',
          meetingTime: time.isEmpty ? null : time,
          meetingLocation: location.isEmpty ? null : location,
          cycleKey: cycleKeyStr,
          reportFillerName: defaultReportFiller,
          isReportFilled: false,
        );
        await _dataSource.saveOrUpdateMeeting(meetingToUse);
      }

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => FillReportPage(
            cell: CellModel.fromEntity(cell),
            meeting: meetingToUse,
            currentUser: widget.currentUser,
          ),
        ),
      );

      if (result == true) {
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao processar reunião manual: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelDeletionRequest(
      String cellId,
      CellMeetingModel meeting,
      ) async {
    try {
      await _dataSource.saveOrUpdateMeeting(
        CellMeetingModel(
          id: meeting.id,
          cellId: cellId,
          meetingDate: meeting.meetingDate,
          status: meeting.status,
          statusNote: meeting.statusNote,
          eventName: meeting.eventName,
          meetingTime: meeting.meetingTime,
          meetingLocation: meeting.meetingLocation,
          isReportFilled: meeting.isReportFilled,
          cycleKey: meeting.cycleKey,
          initialPrayerName: meeting.initialPrayerName,
          icebreakerName: meeting.icebreakerName,
          worshipName: meeting.worshipName,
          wordName: meeting.wordName,
          finalPrayerName: meeting.finalPrayerName,
          snackName: meeting.snackName,
          officialPhotoName: meeting.officialPhotoName,
          reportFillerName: meeting.reportFillerName,
          deletionRequested: false,
          deletionReason: null,
          deletionType: null,
        ),
      );

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitação de exclusão cancelada com sucesso.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar solicitação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

    final activeTargetCell = _getActiveTargetCell();

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
      floatingActionButton:
      (_tabController?.index == 1 && activeTargetCell != null)
          ? FloatingActionButton.extended(
        onPressed: () => _showAddManualReportDialog(activeTargetCell),
        icon: const Icon(Icons.add_chart),
        label: const Text('Novo Relatório Manual'),
      )
          : null,
    );
  }

  Widget _buildDashboardsTab(UserEntity user) {
    if (user.isPastorOrCoordinator) {
      return const PastorAnalyticsWidget();
    } else if (user.isLeader) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LeaderDashboardWidget(
            user: user,
            onNavigateToReports: () => _tabController?.animateTo(1),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildReportsTab(UserEntity user) {
    final bool canToggleMode = user.isPastorOrCoordinator;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          if (canToggleMode && _selectedPastoralCell == null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<ReportViewMode>(
                segments: const [
                  ButtonSegment<ReportViewMode>(
                    value: ReportViewMode.leader,
                    icon: Icon(Icons.home_work_outlined),
                    label: Text('Sua Célula'),
                  ),
                  ButtonSegment<ReportViewMode>(
                    value: ReportViewMode.pastoral,
                    icon: Icon(Icons.account_tree_outlined),
                    label: Text('Todas as Células'),
                  ),
                ],
                selected: {_currentViewMode},
                onSelectionChanged: (Set<ReportViewMode> newSelection) {
                  setState(() {
                    _currentViewMode = newSelection.first;
                    _selectedPastoralCell = null;
                  });
                },
              ),
            ),
          ],

          Expanded(
            child:
            (_currentViewMode == ReportViewMode.leader ||
                !user.isPastorOrCoordinator)
                ? _buildLeaderView()
                : _buildPastoralView(user),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderView() {
    if (_leaderCell == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Você não está vinculado como líder de nenhuma célula no momento.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ),
      );
    }

    final meetings = _cellMeetingsMap[_leaderCell!.id] ?? [];
    return _buildCellMeetingsList(_leaderCell!, meetings, isLeaderView: true);
  }

  Widget _buildPastoralView(UserEntity user) {
    if (_cells.isEmpty) {
      return const Center(child: Text('Nenhuma célula cadastrada no sistema.'));
    }

    if (_selectedPastoralCell != null) {
      final cell = _selectedPastoralCell!;
      final meetings = _cellMeetingsMap[cell.id] ?? [];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Voltar para a lista de células',
                  onPressed: () {
                    setState(() {
                      _selectedPastoralCell = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPastoralCell = null;
                      });
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cell.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const Text(
                          'Toque aqui ou na seta para voltar às outras células',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
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
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Ver Célula'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildCellMeetingsList(cell, meetings, isLeaderView: false),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cells.length,
      itemBuilder: (context, index) {
        final cell = _cells[index];
        final meetings = _cellMeetingsMap[cell.id] ?? [];

        final bool hasPending = meetings.any(
              (m) => m.isExpired && !m.isReportFilled,
        );
        final bool hasDeletionRequest = meetings.any(
              (m) => m.deletionRequested == true,
        );

        Color avatarColor = Colors.green.shade100;
        IconData avatarIcon = Icons.check_circle;
        Color iconColor = Colors.green.shade800;
        String subtitleText = 'Todos os relatórios em dia';
        Color subtitleColor = Colors.green.shade800;

        if (hasDeletionRequest && hasPending) {
          avatarColor = Colors.red.shade100;
          avatarIcon = Icons.priority_high;
          iconColor = Colors.red.shade800;
          subtitleText = 'Relatórios pendentes & Solicitação de exclusão';
          subtitleColor = Colors.red.shade800;
        } else if (hasDeletionRequest) {
          avatarColor = Colors.red.shade100;
          avatarIcon = Icons.delete_sweep;
          iconColor = Colors.red.shade800;
          subtitleText = 'Possui solicitação de exclusão';
          subtitleColor = Colors.red.shade800;
        } else if (hasPending) {
          avatarColor = Colors.amber.shade100;
          avatarIcon = Icons.warning_amber_rounded;
          iconColor = Colors.amber.shade800;
          subtitleText = 'Possui relatórios pendentes';
          subtitleColor = Colors.orange.shade800;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            leading: CircleAvatar(
              backgroundColor: avatarColor,
              child: Icon(avatarIcon, color: iconColor),
            ),
            title: Text(
              cell.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitleText,
                    style: TextStyle(
                      color: subtitleColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${meetings.length} Reuniões Registradas',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              setState(() {
                _selectedPastoralCell = cell;
              });
            },
          ),
        );
      },
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
              const Icon(Icons.event_note, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('Nenhuma reunião registrada para esta célula ainda.'),
              if (isLeaderView) ...[
                const SizedBox(height: 12),
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
            ],
          ),
        ),
      );
    }

    final topicsMap = _cellReportTopicsMap[cell.id] ?? {};

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        final dateFormatted = _formatDateWithWeekday(meeting.meetingDate);
        final isFilled = meeting.isReportFilled;
        final isPastMeeting = meeting.isExpired;

        String statusLabel = "Aguardando Reunião";
        Color statusColor = Colors.blue.shade800;

        if (isFilled) {
          statusLabel = "Preenchido (OK)";
          statusColor = Colors.green.shade800;
        } else if (isPastMeeting) {
          statusLabel = "Pendente de Preenchimento";
          statusColor = Colors.deepOrange.shade800;
        }

        String meetingTypeDesc = "Reunião Normal";
        String statusBadgeText = "Normal";
        Color cardBgColor = Colors.blue.shade50.withOpacity(0.4);
        Color cardBorderColor = Colors.blue.shade200;
        Color typeTextColor = Colors.blue.shade900;
        IconData typeIcon = Icons.event;

        final meetingDateKey =
            '${meeting.meetingDate.year}-${meeting.meetingDate.month}-${meeting.meetingDate.day}';
        final studyTopic = topicsMap[meetingDateKey];

        if (meeting.status == 'bridge_event') {
          final eventTitle =
          (studyTopic != null && studyTopic.isNotEmpty)
              ? studyTopic
              : (meeting.eventName ?? 'Especial');
          meetingTypeDesc = "Evento Ponte: $eventTitle";
          statusBadgeText = "Evento Ponte";
          cardBgColor = Colors.blue.shade50;
          cardBorderColor = Colors.blue.shade200;
          typeTextColor = Colors.blue.shade900;
          typeIcon = Icons.star;
        } else if (meeting.status == 'canceled') {
          meetingTypeDesc = "Reunião Cancelada";
          statusBadgeText = "Cancelada";
          cardBgColor = Colors.red.shade50;
          cardBorderColor = Colors.red.shade200;
          typeTextColor = Colors.red.shade900;
          typeIcon = Icons.cancel;
        } else if (meeting.status == 'rescheduled') {
          meetingTypeDesc = "Reunião Remarcada";
          statusBadgeText = "Remarcada";
          cardBgColor = Colors.purple.shade50;
          cardBorderColor = Colors.purple.shade200;
          typeTextColor = Colors.purple.shade900;
          typeIcon = Icons.edit_calendar;
        } else if (studyTopic != null && studyTopic.isNotEmpty) {
          meetingTypeDesc = "Tema: $studyTopic";
          statusBadgeText = "Normal / Tema";
          cardBgColor = Colors.teal.shade50;
          cardBorderColor = Colors.teal.shade200;
          typeTextColor = Colors.teal.shade900;
          typeIcon = Icons.menu_book;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardBorderColor, width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (isFilled) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ViewReportPage(
                        cell: cell,
                        meeting: meeting,
                        currentUser: widget.currentUser,
                      ),
                    ),
                  ).then((_) => _loadData());
                } else if (isPastMeeting) {
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
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Reunião em $dateFormatted',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(typeIcon, size: 14, color: typeTextColor),
                              const SizedBox(width: 4),
                              Text(
                                statusBadgeText,
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
                    const SizedBox(height: 4),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Status: $statusLabel',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'view') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => ViewReportPage(
                                    cell: cell,
                                    meeting: meeting,
                                    currentUser: widget.currentUser,
                                  ),
                                ),
                              ).then((_) => _loadData());
                            } else if (action == 'fill' || action == 'edit') {
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
                            } else if (action == 'cancel_delete_request') {
                              await _cancelDeletionRequest(cell.id, meeting);
                            } else if (action == 'admin_delete' &&
                                widget.currentUser.isPastorOrCoordinator) {
                              _showAdminDeleteDialog(cell.id, meeting);
                            }
                          },
                          itemBuilder:
                              (context) => [
                            if (isFilled)
                              const PopupMenuItem(
                                value: 'view',
                                child: Text('Visualizar Relatório'),
                              ),
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
                              if (meeting.deletionRequested)
                                const PopupMenuItem(
                                  value: 'cancel_delete_request',
                                  child: Text(
                                    'Cancelar Solicitação de Exclusão',
                                    style: TextStyle(color: Colors.orange),
                                  ),
                                )
                              else
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
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                    if (meeting.deletionRequested) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: Colors.deepOrange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  meeting.deletionType == 'entire_meeting'
                                      ? 'Solicitação: Excluir Reunião Completa'
                                      : 'Solicitação: Excluir Apenas Relatório',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Motivo: "${meeting.deletionReason}"',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (isLeaderView) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed:
                                      () => _cancelDeletionRequest(
                                    cell.id,
                                    meeting,
                                  ),
                                  icon: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.deepOrange,
                                  ),
                                  label: const Text(
                                    'Cancelar Solicitação',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.deepOrange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (widget.currentUser.isPastorOrCoordinator) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () async {
                                      await _cancelDeletionRequest(
                                        cell.id,
                                        meeting,
                                      );
                                    },
                                    child: const Text(
                                      'Recusar',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                    ),
                                    onPressed: () async {
                                      if (meeting.deletionType ==
                                          'entire_meeting') {
                                        await _dataSource
                                            .deleteMeetingAndReport(
                                          cell.id,
                                          meeting.id,
                                          meeting.meetingDate,
                                        );
                                      } else {
                                        await _dataSource.deleteOnlyReport(
                                          cell.id,
                                          meeting.id,
                                          meeting.meetingDate,
                                        );
                                      }
                                      _loadData();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Exclusão aprovada e realizada com sucesso!',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Aprovar e Excluir',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeletionRequestDialog(String cellId, String meetingId) {
    final reasonController = TextEditingController();
    String selectedDeletionType = 'only_report';

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
        builder:
            (context, setDialogState) => AlertDialog(
          title: const Text('Solicitar Exclusão ao Pastor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecione o tipo de exclusão desejada:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                RadioListTile<String>(
                  title: const Text('Apenas o Relatório'),
                  subtitle: const Text(
                    'A reunião continuará pendente para preenchimento.',
                  ),
                  value: 'only_report',
                  groupValue: selectedDeletionType,
                  onChanged: (val) {
                    if (val != null)
                      setDialogState(() => selectedDeletionType = val);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Reunião Completa'),
                  subtitle: const Text(
                    'Remove a reunião e o relatório correspondente.',
                  ),
                  value: 'entire_meeting',
                  groupValue: selectedDeletionType,
                  onChanged: (val) {
                    if (val != null)
                      setDialogState(() => selectedDeletionType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo da solicitação',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) return;

                await _dataSource.requestReportDeletion(
                  cellId,
                  meetingId,
                  reasonController.text.trim(),
                  selectedDeletionType,
                );

                Navigator.pop(ctx);
                _loadData();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Solicitação de exclusão enviada ao pastor com sucesso!',
                    ),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              child: const Text(
                'Enviar Solicitação',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminDeleteDialog(String cellId, CellMeetingModel meeting) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isDeleting = false;

          return AlertDialog(
            title: const Text('Excluir Relatório'),
            content:
            isDeleting
                ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processando exclusão no banco de dados...'),
              ],
            )
                : const Text(
              'Selecione como deseja proceder com a exclusão:\n\n'
                  '• Excluir Apenas Relatório: O relatório na coleção raiz é removido e a reunião permanece na lista marcada como "Pendente", permitindo que o líder preencha novamente.\n\n'
                  '• Excluir Reunião Completa: Remove a reunião da subcoleção e o relatório correspondente permanentemente.',
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actionsOverflowDirection: VerticalDirection.down,
            actions:
            isDeleting
                ? []
                : [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                onPressed: () async {
                  setDialogState(() => isDeleting = true);
                  try {
                    await _dataSource.deleteOnlyReport(
                      cellId,
                      meeting.id,
                      meeting.meetingDate,
                    );

                    if (mounted) {
                      Navigator.pop(ctx);
                      await _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Relatório excluído da coleção raiz! Reunião mantida como pendente.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => isDeleting = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Erro ao excluir relatório: $e',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Excluir Apenas Relatório',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () async {
                  setDialogState(() => isDeleting = true);
                  try {
                    await _dataSource.deleteMeetingAndReport(
                      cellId,
                      meeting.id,
                      meeting.meetingDate,
                    );

                    if (mounted) {
                      Navigator.pop(ctx);
                      await _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Reunião e relatório excluídos com sucesso!',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => isDeleting = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Erro ao excluir reunião e relatório: $e',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Excluir Reunião Completa',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}