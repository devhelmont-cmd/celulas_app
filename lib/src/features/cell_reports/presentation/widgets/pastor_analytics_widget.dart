// lib/src/features/cell_reports/presentation/widgets/pastor_analytics_widget.dart
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/core/utils/pastoral_cycle_helper.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/widgets/cell_attendance_chart_widget.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/widgets/cells_performance_chart_widget.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/widgets/meeting_status_chart_widget.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/widgets/leader_analytics_widget.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/widgets/member_analytics_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum PastorViewMode { general, cell, member }

class PastorAnalyticsWidget extends StatefulWidget {
  const PastorAnalyticsWidget({super.key});

  @override
  State<PastorAnalyticsWidget> createState() => _PastorAnalyticsWidgetState();
}

class _PastorAnalyticsWidgetState extends State<PastorAnalyticsWidget> {
  late final ICellReportsRepository _reportsRepository;
  late final ICellRemoteDataSource _cellDataSource;

  bool _isLoading = true;
  List<CellReportEntity> _allReports = [];
  List<CellModel> _cells = [];
  List<CellMeetingModel> _allMeetings = [];
  List<CellMemberEntity> _allMembers = [];

  PastorViewMode _viewMode = PastorViewMode.general;
  String? _selectedCellId;
  String? _selectedMemberUserId;

  String _selectedMonthKey = 'all';

  List<Map<String, dynamic>> _chartConfigs = [
  {'id': 'attendance', 'title': 'Evolução Geral Temporal', 'visible': true},
  {'id': 'status', 'title': 'Status das Reuniões', 'visible': true},
  {'id': 'performance', 'title': 'Comparativo por Célula', 'visible': true},
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
        if (userDoc.exists && userDoc.data()!.containsKey('pastorChartConfigs')) {
          final savedList = List<Map<String, dynamic>>.from(
            userDoc.data()!['pastorChartConfigs'].map((e) => Map<String, dynamic>.from(e)),
          );
          if (savedList.isNotEmpty) {
            _chartConfigs = savedList;
          }
        }
      }

      final reports = await _reportsRepository.getAllReports();
      final cells = await _cellDataSource.getCells();

      // Ordenação alfabética das células
      cells.sort((a, b) => a.name.compareTo(b.name));

      List<CellMeetingModel> meetings = [];
      List<CellMemberEntity> members = [];

      for (var cell in cells) {
        try {
          final cellMeetings = await _cellDataSource.getAllMeetingsForCell(cell.id);
          meetings.addAll(cellMeetings);
        } catch (_) {}

        try {
          final cellMembers = await _cellDataSource.getCellMembers(cell.id);
          members.addAll(cellMembers);
        } catch (_) {}
      }

      // Ordenação alfabética dos membros
      members.sort((a, b) => a.name.compareTo(b.name));

      if (mounted) {
        setState(() {
          _allReports = reports;
          _cells = cells;
          _allMeetings = meetings;
          _allMembers = members;
          if (_cells.isNotEmpty && _selectedCellId == null) {
            _selectedCellId = _cells.first.id;
          }
          if (_allMembers.isNotEmpty && _selectedMemberUserId == null) {
            _selectedMemberUserId = _allMembers.first.userId ?? _allMembers.first.id;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Erro ao carregar dados analíticos do pastor: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final userUid = FirebaseAuth.instance.currentUser?.uid;
      if (userUid != null) {
        await FirebaseFirestore.instance.collection('users').doc(userUid).update({
          'pastorChartConfigs': _chartConfigs,
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
    for (var r in _allReports) {
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

    return RefreshIndicator(
      onRefresh: _loadDataAndPreferences,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Seletor de Modo de Visão (Geral, Célula, Membro)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<PastorViewMode>(
              segments: const [
                ButtonSegment(
                  value: PastorViewMode.general,
                  label: Text('Visão Geral'),
                  icon: Icon(Icons.dashboard_outlined, size: 16),
                ),
                ButtonSegment(
                  value: PastorViewMode.cell,
                  label: Text('Por Célula'),
                  icon: Icon(Icons.group_outlined, size: 16),
                ),
                ButtonSegment(
                  value: PastorViewMode.member,
                  label: Text('Por Membro'),
                  icon: Icon(Icons.person_outline, size: 16),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (Set<PastorViewMode> newSelection) {
                setState(() {
                  _viewMode = newSelection.first;
                });
              },
            ),
          ),
          const SizedBox(height: 20),

          // Renderização condicional conforme o modo selecionado
          if (_viewMode == PastorViewMode.general)
            _buildGeneralDashboard()
          else if (_viewMode == PastorViewMode.cell)
            _buildCellSelectionDashboard()
          else
            _buildMemberSelectionDashboard(),
        ],
      ),
    );
  }

  Widget _buildGeneralDashboard() {
    List<CellReportEntity> filteredReports = _allReports;
    if (_selectedMonthKey != 'all') {
      filteredReports = _allReports.where((r) {
        final cycleKey = (r.cycleKey != null && r.cycleKey!.isNotEmpty)
            ? r.cycleKey!
            : PastoralCycleHelper.getCycleKeyString(r.scheduledDate);
        return cycleKey.startsWith(_selectedMonthKey);
      }).toList();
    }

    List<CellMeetingModel> filteredMeetings = _allMeetings;
    if (_selectedMonthKey != 'all') {
      filteredMeetings = _allMeetings.where((m) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Análise Geral de Crescimento',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Acompanhe o desempenho consolidado da igreja.',
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
            _buildChartById(config['id'], filteredReports, filteredMeetings),
            const SizedBox(height: 24),
          ],
      ],
    );
  }

  Widget _buildCellSelectionDashboard() {
    if (_cells.isEmpty) {
      return const Center(child: Text('Nenhuma célula cadastrada.'));
    }

    final selectedCell = _cells.firstWhere(
          (c) => c.id == _selectedCellId,
      orElse: () => _cells.first,
    );

    final pseudoLeaderUser = UserEntity(
      id: selectedCell.leaderId ?? '',
      name: selectedCell.name,
      email: '',
      primaryCellId: selectedCell.id,
      roles: [UserRole.leader],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Selecionar Célula: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                    value: _cells.any((c) => c.id == _selectedCellId) ? _selectedCellId : _cells.first.id,
                    isExpanded: true,
                    items: _cells.map((cell) {
                      return DropdownMenuItem<String>(
                        value: cell.id,
                        child: Text(cell.name, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCellId = val);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // A Key baseada no ID selecionado força o Flutter a recriar o widget imediatamente
        LeaderAnalyticsWidget(
          key: ValueKey(_selectedCellId),
          currentUser: pseudoLeaderUser,
          isEmbedded: true,
        ),
      ],
    );
  }

  Widget _buildMemberSelectionDashboard() {
    if (_allMembers.isEmpty) {
      return const Center(child: Text('Nenhum membro cadastrado nas células.'));
    }

    if (_selectedMemberUserId == null || !_allMembers.any((m) => (m.userId ?? m.id) == _selectedMemberUserId)) {
      _selectedMemberUserId = _allMembers.first.userId ?? _allMembers.first.id;
    }

    final selectedMember = _allMembers.firstWhere(
          (m) => (m.userId ?? m.id) == _selectedMemberUserId,
      orElse: () => _allMembers.first,
    );

    final pseudoMemberUser = UserEntity(
      id: selectedMember.userId ?? selectedMember.id,
      name: selectedMember.name,
      email: '',
      primaryCellId: selectedMember.cellId,
      roles: [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Selecionar Membro: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                    items: _allMembers.map((member) {
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
        // A Key baseada no ID do membro selecionado força o Flutter a recriar o widget imediatamente
        MemberAnalyticsWidget(
          key: ValueKey(_selectedMemberUserId),
          currentUser: pseudoMemberUser,
          viewerUser: UserEntity(
            id: FirebaseAuth.instance.currentUser?.uid ?? 'pastor',
            name: 'Pastor',
            email: '',
            roles: [UserRole.pastor],
          ), // Passa o contexto de quem está olhando (Pastor)
          isEmbedded: true,
        ),
      ],
    );
  }

  Widget _buildChartById(String id, List<CellReportEntity> filteredReports, List<CellMeetingModel> filteredMeetings) {
    if (id == 'attendance') {
      return CellAttendanceChartWidget(
        reports: _allReports,
        selectedMonthKey: _selectedMonthKey,
      );
    } else if (id == 'status') {
      return MeetingStatusChartWidget(
        meetings: _selectedMonthKey == 'all'
            ? _allReports.map((r) {
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
    } else if (id == 'performance') {
      return CellsPerformanceChartWidget(reports: filteredReports, cells: _cells);
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