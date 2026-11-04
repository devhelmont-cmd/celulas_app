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
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LeaderAnalyticsWidget extends StatefulWidget {
  final UserEntity currentUser;

  const LeaderAnalyticsWidget({super.key, required this.currentUser});

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

  // Armazena o mês selecionado no formato "yyyy-MM" (ex: "2026-09") ou "all"
  String _selectedMonthKey = 'all';

  @override
  void initState() {
    super.initState();
    _reportsRepository = getIt<ICellReportsRepository>();
    _cellDataSource = getIt<ICellRemoteDataSource>();
    _loadLeaderAnalyticsData();
  }

  Future<void> _loadLeaderAnalyticsData() async {
    setState(() => _isLoading = true);
    try {
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
              (user.name != null &&
                  c.leaderId?.trim().toLowerCase() ==
                      user.name!.trim().toLowerCase())) {
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

          // Seleciona o mês atual por padrão se houver dados
          /*if (_selectedMonthKey == 'all' && reports.isNotEmpty) {
            final nowKey = DateFormat('yyyy-MM').format(DateTime.now());
            final hasCurrentMonth = reports.any((r) {
              final cycleKey = (r.cycleKey != null && r.cycleKey!.isNotEmpty)
                  ? r.cycleKey!
                  : PastoralCycleHelper.getCycleKeyString(r.scheduledDate);
              return cycleKey.startsWith(nowKey);
            });
            if (hasCurrentMonth) {
              _selectedMonthKey = nowKey;
            }
          }*/
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Erro ao carregar dados analíticos do líder: $e');
    }
  }

  // Extrai dinamicamente os meses/anos baseados no Ciclo Pastoral (cycleKey) da célula
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
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

    // Filtra os relatórios com base no ciclo pastoral (cycleKey)
    List<CellReportEntity> filteredReports = _cellReports;
    if (_selectedMonthKey != 'all') {
      filteredReports = _cellReports.where((r) {
        final cycleKey = (r.cycleKey != null && r.cycleKey!.isNotEmpty)
            ? r.cycleKey!
            : PastoralCycleHelper.getCycleKeyString(r.scheduledDate);
        return cycleKey.startsWith(_selectedMonthKey);
      }).toList();
    }

    // Filtra as reuniões com base no ciclo pastoral (cycleKey)
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
    int totalVisitors = filteredReports.fold(
      0,
          (sum, r) => sum + r.visitors.length,
    );
    int totalConversions = filteredReports.fold(
      0,
          (sum, r) => sum + r.conversions.length,
    );

    final availableMonths = _getAvailableMonths();

    return RefreshIndicator(
      onRefresh: _loadLeaderAnalyticsData,
      child: ListView(
        padding: const EdgeInsets.all(16),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Acompanhe o crescimento e histórico da sua célula.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Dropdown Seletor de Período / Mês
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: availableMonths.any(
                          (m) => m['key'] == _selectedMonthKey,
                    )
                        ? _selectedMonthKey
                        : 'all',
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.blueAccent,
                    ),
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
                      if (val != null) {
                        setState(() {
                          _selectedMonthKey = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cards de Resumo Rápido da Célula
          Row(
            children: [
              _buildSummaryCard(
                'Relatórios',
                '$totalReports',
                Icons.description,
                Colors.purple,
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                'Visitantes',
                '$totalVisitors',
                Icons.person_add,
                Colors.orange,
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                'Conversões',
                '$totalConversions',
                Icons.volunteer_activism,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 1º Gráfico: Evolução Temporal da Célula (Membros, Visitantes, Conversões)
          CellAttendanceChartWidget(
            reports: _cellReports,
            selectedMonthKey: _selectedMonthKey,
          ),
          const SizedBox(height: 24),

          // 2º Gráfico: Status das Reuniões da Célula (Normais, Canceladas e Pontes)
          MeetingStatusChartWidget(
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
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
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
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}