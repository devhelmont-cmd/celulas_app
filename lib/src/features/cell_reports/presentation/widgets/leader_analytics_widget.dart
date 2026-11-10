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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  String _selectedMonthKey = 'all';

  List<Map<String, dynamic>> _chartConfigs = [
  {'id': 'attendance', 'title': 'Evolução Temporal da Célula', 'visible': true},
  {'id': 'status', 'title': 'Status das Reuniões da Célula', 'visible': true},
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

      if (foundCell != null) {
        try {
          reports = await _reportsRepository.getReportsByCell(foundCell.id);
        } catch (_) {}
        try {
          meetings = await _cellDataSource.getAllMeetingsForCell(foundCell.id);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _leaderCell = foundCell;
          _cellReports = reports;
          _cellMeetings = meetings;
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

/// Widget contendo o botão de alternância (SegmentedButton) para o Líder
/// entre ver o Desempenho da Célula e ver a Análise dos Membros da Célula.
class LeaderDashboardWithMembersView extends StatefulWidget {
  final UserEntity currentUser;

  const LeaderDashboardWithMembersView({super.key, required this.currentUser});

  @override
  State<LeaderDashboardWithMembersView> createState() => _LeaderDashboardWithMembersViewState();
}

class _LeaderDashboardWithMembersViewState extends State<LeaderDashboardWithMembersView> {
  bool _isViewingMembers = false;
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
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.analytics_outlined, size: 16),
                label: Text('Desempenho da Célula'),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.people_outline, size: 16),
                label: Text('Membros da Célula'),
              ),
            ],
            selected: {_isViewingMembers},
            onSelectionChanged: (Set<bool> newSelection) {
              setState(() {
                _isViewingMembers = newSelection.first;
              });
            },
          ),
        ),
        const SizedBox(height: 20),

        if (!_isViewingMembers)
          LeaderAnalyticsWidget(currentUser: widget.currentUser, isEmbedded: true)
        else
          _buildCellMembersAnalyticsSection(),
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

    // Busca segura para evitar erros de tipo no firstWhere/orElse
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
          viewerUser: widget.currentUser, // Passa o líder logado como viewer
          isEmbedded: true,
          enableTapToAnalyze: true, // Habilita o clique para abrir a MemberAnalysisPage
        ),
      ],
    );
  }
}