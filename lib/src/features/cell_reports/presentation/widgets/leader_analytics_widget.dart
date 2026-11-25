// lib/src/features/cell_reports/presentation/widgets/leader_analytics_widget.dart
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/core/utils/pastoral_cycle_helper.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/widgets/cell_attendance_chart_widget.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/widgets/meeting_status_chart_widget.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/widgets/active_members_attendance_chart_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:celulas_app/src/features/cells/data/models/multiplication_settings_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_multiplication_progress_model.dart';
import '../../../cells/domain/entities/cell_member_entity.dart';
import 'member_analytics_widget.dart';

class LeaderAnalyticsWidget extends StatefulWidget {
  final UserEntity currentUser;
  final bool isEmbedded;

  const LeaderAnalyticsWidget({
    super.key,
    required this.currentUser,
    this.isEmbedded = false,
  });

  @override
  State<LeaderAnalyticsWidget> createState() => _LeaderAnalyticsWidgetState();
}

class _LeaderAnalyticsWidgetState extends State<LeaderAnalyticsWidget> {
  late final ICellReportsRepository _reportsRepository;
  late final ICellRemoteDataSource _cellDataSource;

  bool _isLoading = true;
  CellModel? _leaderCell;
  List<CellReportEntity> _cellReports = [];
  List<CellMeetingModel> _cellMeetings = [];
  List<CellMemberEntity> _cellMembers = [];

  String _selectedMonthKey = 'all';

  List<Map<String, dynamic>> _chartConfigs = [
    {'id': 'attendance', 'title': 'Evolução Temporal da Célula', 'visible': true},
    {'id': 'status', 'title': 'Status das Reuniões da Célula', 'visible': true},
    {'id': 'member_attendance', 'title': 'Assiduidade dos Membros da Célula', 'visible': true},
  ];

  @override
  void initState() {
    super.initState();
    _reportsRepository = getIt<ICellReportsRepository>();
    _cellDataSource = getIt<ICellRemoteDataSource>();
    _loadDataAndPreferences();
  }

  Future<void> _loadDataAndPreferences() async {
    setState(() => _isLoading = true);
    try {
      final userUid = FirebaseAuth.instance.currentUser?.uid;
      if (userUid != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userUid).get();
        if (userDoc.exists && userDoc.data()!.containsKey('leaderChartConfigs')) {
          final savedList = List<Map<String, dynamic>>.from(
            userDoc.data()!['leaderChartConfigs'].map((e) => Map<String, dynamic>.from(e)),
          );
          if (savedList.isNotEmpty) {
            final savedIds = savedList.map((e) => e['id']).toSet();
            for (var defaultConfig in [
              {'id': 'attendance', 'title': 'Evolução Temporal da Célula', 'visible': true},
              {'id': 'status', 'title': 'Status das Reuniões da Célula', 'visible': true},
              {'id': 'member_attendance', 'title': 'Assiduidade dos Membros da Célula', 'visible': true},
            ]) {
              if (!savedIds.contains(defaultConfig['id'])) {
                savedList.add(defaultConfig);
              }
            }
            _chartConfigs = savedList;
          }
        }
      }

      final user = widget.currentUser;
      CellModel? foundCell;
      final allCells = await _cellDataSource.getCells(currentUser: user);

      if (user.primaryCellId != null && user.primaryCellId!.trim().isNotEmpty) {
        try {
          foundCell = allCells.firstWhere((c) => c.id == user.primaryCellId);
        } catch (_) {}
      }

      if (foundCell == null) {
        for (var c in allCells) {
          if (c.leaderId == user.id ||
              (user.name != null && c.leaderId?.trim().toLowerCase() == user.name!.trim().toLowerCase())) {
            foundCell = c;
            break;
          }
        }
      }

      List<CellReportEntity> reports = [];
      List<CellMeetingModel> meetings = [];
      List<CellMemberEntity> members = [];

      if (foundCell != null) {
        try {
          reports = await _reportsRepository.getReportsByCell(foundCell.id);
        } catch (_) {}
        try {
          meetings = await _cellDataSource.getAllMeetingsForCell(foundCell.id);
        } catch (_) {}
        try {
          members = await _cellDataSource.getCellMembers(foundCell.id);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _leaderCell = foundCell;
          _cellReports = reports;
          _cellMeetings = meetings;
          _cellMembers = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Erro ao carregar dados analíticos do líder: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final userUid = FirebaseAuth.instance.currentUser?.uid;
      if (userUid != null) {
        await FirebaseFirestore.instance.collection('users').doc(userUid).update({
          'leaderChartConfigs': _chartConfigs,
        });
      }
    } catch (e) {
      debugPrint('Erro ao salvar preferências de gráficos: $e');
    }
  }

  void _showCustomizeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Personalizar Gráficos'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Marque os gráficos que deseja exibir e arraste pelo ícone lateral para mudar a ordem.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ReorderableListView(
                        shrinkWrap: true,
                        onReorder: (oldIndex, newIndex) {
                          setDialogState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _chartConfigs.removeAt(oldIndex);
                            _chartConfigs.insert(newIndex, item);
                          });
                          setState(() {});
                          _savePreferences();
                        },
                        children: [
                          for (int i = 0; i < _chartConfigs.length; i++)
                            CheckboxListTile(
                              key: ValueKey(_chartConfigs[i]['id']),
                              title: Text(_chartConfigs[i]['title'], style: const TextStyle(fontSize: 14)),
                              value: _chartConfigs[i]['visible'],
                              onChanged: (bool? val) {
                                setDialogState(() {
                                  _chartConfigs[i]['visible'] = val ?? true;
                                });
                                setState(() {});
                                _savePreferences();
                              },
                              secondary: const Icon(Icons.drag_handle, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Concluído'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Map<String, String>> _getAvailableMonths() {
    final Set<String> monthKeys = {};
    for (var r in _cellReports) {
      final cycleKey = (r.cycleKey != null && r.cycleKey!.isNotEmpty)
          ? r.cycleKey!
          : PastoralCycleHelper.getCycleKeyString(r.scheduledDate);
      if (cycleKey.length >= 7) {
        monthKeys.add(cycleKey.substring(0, 7));
      }
    }

    final sortedKeys = monthKeys.toList()..sort((a, b) => b.compareTo(a));
    final List<Map<String, String>> result = [
    {'key': 'all', 'label': 'Todos os Períodos'},
    ];

    for (var key in sortedKeys) {
    final parts = key.split('-');
    if (parts.length >= 2) {
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final date = DateTime(year, month, 1);
    String monthName = DateFormat('MMMM \'de\' yyyy', 'pt_BR').format(date);
    monthName = monthName[0].toUpperCase() + monthName.substring(1);
    result.add({'key': key, 'label': monthName});
    }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_leaderCell == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Você não está vinculado a nenhuma célula no momento.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ),
      );
    }

    List<CellReportEntity> filteredReports = _cellReports;
    if (_selectedMonthKey != 'all') {
      filteredReports = _cellReports.where((r) {
        final cycleKey = (r.cycleKey != null && r.cycleKey!.isNotEmpty)
            ? r.cycleKey!
            : PastoralCycleHelper.getCycleKeyString(r.scheduledDate);
        return cycleKey.startsWith(_selectedMonthKey);
      }).toList();
    }

    List<CellMeetingModel> filteredMeetings = _cellMeetings;
    if (_selectedMonthKey != 'all') {
      filteredMeetings = _cellMeetings.where((m) {
        final cycleKey = (m.cycleKey != null && m.cycleKey!.isNotEmpty)
            ? m.cycleKey!
            : PastoralCycleHelper.getCycleKeyString(m.meetingDate);
        return cycleKey.startsWith(_selectedMonthKey);
      }).toList();
    }

    int totalReports = filteredReports.length;
    int totalVisitors = filteredReports.fold(0, (sum, r) => sum + r.visitors.length);
    int totalConversions = filteredReports.fold(0, (sum, r) => sum + r.conversions.length);
    final availableMonths = _getAvailableMonths();

    final listViewContent = ListView(
      shrinkWrap: widget.isEmbedded,
      physics: widget.isEmbedded ? const NeverScrollableScrollPhysics() : null,
      padding: widget.isEmbedded ? EdgeInsets.zero : const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Desempenho: ${_leaderCell!.name}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Acompanhe o crescimento e histórico da célula.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.tune, color: Colors.blueAccent),
                  tooltip: 'Personalizar Gráficos',
                  onPressed: _showCustomizeDialog,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: availableMonths.any((m) => m['key'] == _selectedMonthKey)
                          ? _selectedMonthKey
                          : 'all',
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                      items: availableMonths.map((item) {
                        return DropdownMenuItem<String>(
                          value: item['key'],
                          child: Text(item['label']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedMonthKey = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildSummaryCard('Relatórios', '$totalReports', Icons.description, Colors.purple),
            const SizedBox(width: 12),
            _buildSummaryCard('Visitantes', '$totalVisitors', Icons.person_add, Colors.orange),
            const SizedBox(width: 12),
            _buildSummaryCard('Conversões', '$totalConversions', Icons.volunteer_activism, Colors.green),
          ],
        ),
        const SizedBox(height: 24),
        for (var config in _chartConfigs)
          if (config['visible'] == true) ...[
            _buildChartById(config['id'], filteredMeetings),
            const SizedBox(height: 24),
          ],
      ],
    );

    if (widget.isEmbedded) {
      return listViewContent;
    }

    return RefreshIndicator(
      onRefresh: _loadDataAndPreferences,
      child: listViewContent,
    );
  }

  Widget _buildChartById(String id, List<CellMeetingModel> filteredMeetings) {
    if (id == 'attendance') {
      return CellAttendanceChartWidget(
        reports: _cellReports,
        selectedMonthKey: _selectedMonthKey,
      );
    } else if (id == 'status') {
      return MeetingStatusChartWidget(
        meetings: _selectedMonthKey == 'all'
            ? _cellReports.map((r) {
          String mappedStatus = 'normal';
          if (r.status == ReportStatus.cacelled) {
            mappedStatus = 'canceled';
          } else if (r.status == ReportStatus.bridgeEvent) {
            mappedStatus = 'bridge_event';
          }
          return CellMeetingModel(
            id: r.id,
            cellId: r.cellId,
            meetingDate: r.scheduledDate,
            status: mappedStatus,
            isReportFilled: true,
          );
        }).toList()
            : filteredMeetings,
      );
    } else if (id == 'member_attendance') {
      return ActiveMembersAttendanceChartWidget(
        reports: _cellReports,
        members: _cellMembers,
        cells: _leaderCell != null ? [_leaderCell!] : [],
        selectedMonthKey: _selectedMonthKey,
        cellIdFilter: _leaderCell?.id,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

enum LeaderTab { performance, members, multiplication }

class LeaderDashboardWithMembersView extends StatefulWidget {
  final UserEntity currentUser;

  const LeaderDashboardWithMembersView({super.key, required this.currentUser});

  @override
  State<LeaderDashboardWithMembersView> createState() => _LeaderDashboardWithMembersViewState();
}

class _LeaderDashboardWithMembersViewState extends State<LeaderDashboardWithMembersView> {
  LeaderTab _currentTab = LeaderTab.performance;
  List<CellMemberEntity> _cellMembers = [];
  bool _isLoadingMembers = true;
  String? _selectedMemberUserId;
  CellModel? _leaderCell;

  @override
  void initState() {
    super.initState();
    _loadLeaderCellAndMembers();
  }

  Future<void> _loadLeaderCellAndMembers() async {
    try {
      final dataSource = getIt<ICellRemoteDataSource>();
      final allCells = await dataSource.getCells(currentUser: widget.currentUser);

      CellModel? foundCell;
      final user = widget.currentUser;

      if (user.primaryCellId != null && user.primaryCellId!.trim().isNotEmpty) {
        try {
          foundCell = allCells.firstWhere((c) => c.id == user.primaryCellId);
        } catch (_) {}
      }

      if (foundCell == null) {
        for (var c in allCells) {
          if (c.leaderId == user.id ||
              (user.name != null && c.leaderId?.trim().toLowerCase() == user.name!.trim().toLowerCase())) {
            foundCell = c;
            break;
          }
        }
      }

      if (foundCell != null) {
        final members = await dataSource.getCellMembers(foundCell.id);
        members.sort((a, b) => a.name.compareTo(b.name));

        if (mounted) {
          setState(() {
            _leaderCell = foundCell;
            _cellMembers = members;
            if (members.isNotEmpty) {
              _selectedMemberUserId = members.first.userId ?? members.first.id;
            }
            _isLoadingMembers = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingMembers = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMembers = false);
      debugPrint('Erro ao carregar membros para o líder: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMembers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_leaderCell == null) {
      return const Center(child: Text('Célula do líder não encontrada.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<LeaderTab>(
              segments: const [
                ButtonSegment<LeaderTab>(
                  value: LeaderTab.performance,
                  icon: Icon(Icons.analytics_outlined, size: 16),
                  label: Text('Desempenho da Célula'),
                ),
                ButtonSegment<LeaderTab>(
                  value: LeaderTab.members,
                  icon: Icon(Icons.people_outline, size: 16),
                  label: Text('Membros da Célula'),
                ),
                ButtonSegment<LeaderTab>(
                  value: LeaderTab.multiplication,
                  icon: Icon(Icons.diversity_3_outlined, size: 16),
                  label: Text('Multiplicação'),
                ),
              ],
              selected: {_currentTab},
              onSelectionChanged: (Set<LeaderTab> newSelection) {
                setState(() {
                  _currentTab = newSelection.first;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (_currentTab == LeaderTab.performance)
          LeaderAnalyticsWidget(currentUser: widget.currentUser, isEmbedded: true)
        else if (_currentTab == LeaderTab.members)
          _buildCellMembersAnalyticsSection()
        else
          LeaderMultiplicationWidget(cell: _leaderCell!),
      ],
    );
  }

  Widget _buildCellMembersAnalyticsSection() {
    if (_cellMembers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('Nenhum membro cadastrado nesta célula.'),
        ),
      );
    }

    if (_selectedMemberUserId == null || !_cellMembers.any((m) => (m.userId ?? m.id) == _selectedMemberUserId)) {
      _selectedMemberUserId = _cellMembers.first.userId ?? _cellMembers.first.id;
    }

    CellMemberEntity? selectedMember;
    try {
      selectedMember = _cellMembers.firstWhere(
            (m) => (m.userId ?? m.id) == _selectedMemberUserId,
      );
    } catch (_) {
      selectedMember = _cellMembers.first;
    }

    final pseudoMemberUser = UserEntity(
      id: selectedMember.userId ?? selectedMember.id,
      name: selectedMember.name,
      email: '',
      primaryCellId: _leaderCell?.id,
      roles: [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Membro: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMemberUserId,
                    isExpanded: true,
                    items: _cellMembers.map((member) {
                      final mId = member.userId ?? member.id;
                      return DropdownMenuItem<String>(
                        value: mId,
                        child: Text(member.name, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedMemberUserId = val);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        MemberAnalyticsWidget(
          key: ValueKey(_selectedMemberUserId),
          currentUser: pseudoMemberUser,
          viewerUser: widget.currentUser,
          isEmbedded: true,
          enableTapToAnalyze: true,
        ),
      ],
    );
  }
}

class LeaderMultiplicationWidget extends StatefulWidget {
  final CellModel cell;

  const LeaderMultiplicationWidget({super.key, required this.cell});

  @override
  State<LeaderMultiplicationWidget> createState() => _LeaderMultiplicationWidgetState();
}

class _LeaderMultiplicationWidgetState extends State<LeaderMultiplicationWidget> {
  bool _isLoading = true;
  MultiplicationSettingsModel _settings = const MultiplicationSettingsModel();
  List<CellMemberEntity> _members = [];
  List<CellReportEntity> _reports = [];
  List<CellMeetingModel> _meetings = [];
  late CellModel _currentCell;

  @override
  void initState() {
    super.initState();
    _currentCell = widget.cell;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dataSource = getIt<ICellRemoteDataSource>();
      final reportsRepo = getIt<ICellReportsRepository>();

      final settings = await dataSource.getMultiplicationSettings();
      final members = await dataSource.getCellMembers(_currentCell.id);
      List<CellReportEntity> reports = [];
      try {
        reports = await reportsRepo.getReportsByCell(_currentCell.id);
      } catch (_) {}

      List<CellMeetingModel> meetings = [];
      try {
        meetings = await dataSource.getAllMeetingsForCell(_currentCell.id);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _settings = settings;
          _members = members;
          _reports = reports;
          _meetings = meetings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFutureHost(bool value) async {
    try {
      final updatedCell = CellModel(
        id: _currentCell.id,
        name: _currentCell.name,
        leaderId: _currentCell.leaderId,
        coLeaderId: _currentCell.coLeaderId,
        hostId: _currentCell.hostId,
        address: _currentCell.address,
        neighborhood: _currentCell.neighborhood,
        meetingDay: _currentCell.meetingDay,
        meetingTime: _currentCell.meetingTime,
        category: _currentCell.category,
        isActive: _currentCell.isActive,
        createdAt: _currentCell.createdAt,
        futureHostDefined: value,
        customTargetMembers: _currentCell.customTargetMembers,
        customTargetMonths: _currentCell.customTargetMonths,
        customMinAttendancePercentage: _currentCell.customMinAttendancePercentage,
        customMinVisitorAverage: _currentCell.customMinVisitorAverage,
      );

      final dataSource = getIt<ICellRemoteDataSource>();
      await dataSource.updateCell(updatedCell);
      setState(() {
        _currentCell = updatedCell;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status do futuro anfitrião atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final progress = CellMultiplicationProgressModel.calculate(
      cell: _currentCell,
      members: _members,
      reports: _reports,
      meetings: _meetings,
      settings: _settings,
    );

    final color = progress.isReadyForMultiplication
        ? Colors.green
        : progress.overallPercentage >= 70
            ? Colors.orange
            : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Progresso de Multiplicação da Célula',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (progress.isReadyForMultiplication)
                      Chip(
                        label: const Text('Apta para Multiplicar!'),
                        backgroundColor: Colors.green.shade100,
                        labelStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Prontidão Geral: ${progress.overallPercentage.toStringAsFixed(1)}%'),
                    Text('${progress.metCriteriaCount} / ${progress.totalCriteria} metas'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (progress.overallPercentage / 100.0).clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  color: color,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Futuro Anfitrião / Local Definido'),
                  subtitle: const Text('Marque se já está definido onde ou com quem será a nova célula'),
                  value: _currentCell.futureHostDefined,
                  onChanged: _toggleFutureHost,
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                const SizedBox(height: 8),
                _buildCriterionRow('Membros (${progress.currentMembersCount}/${progress.effectiveTargetMembers})', progress.isMembersTargetMet, Icons.group),
                _buildCriterionRow('Liderança Preparada', progress.isLeadershipTargetMet, Icons.person_outline),
                if (progress.settings.requireHost)
                  _buildCriterionRow('Futuro Anfitrião / Local Definido', progress.isHostTargetMet, Icons.home_outlined),
                _buildCriterionRow('Média de Visitantes (${progress.visitorAverage.toStringAsFixed(1)} / ${progress.settings.minVisitorAverage})', progress.isVisitorTargetMet, Icons.person_add_outlined),
                _buildCriterionRow('Assiduidade (${progress.attendancePercentage.toStringAsFixed(1)}% / ${progress.settings.minAttendancePercentage}%)', progress.isAttendanceTargetMet, Icons.trending_up),
                _buildCriterionRow('Relatórios Entregues (${progress.reportRegularityPercentage.toStringAsFixed(1)}%)', progress.isReportTargetMet, Icons.assignment_turned_in_outlined),
                _buildCriterionRow('Tempo de Célula (${progress.elapsedMonths} / ${progress.settings.targetMonths} meses)', progress.isTimeTargetMet, Icons.timer_outlined),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCriterionRow(String title, bool isMet, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Icon(
            isMet ? Icons.check_circle : Icons.cancel_outlined,
            size: 18,
            color: isMet ? Colors.green : Colors.grey[400],
          ),
        ],
      ),
    );
  }
}