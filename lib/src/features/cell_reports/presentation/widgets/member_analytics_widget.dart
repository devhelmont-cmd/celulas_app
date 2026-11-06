// lib/src/features/cell_reports/presentation/widgets/member_analytics_widget.dart

import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/core/utils/pastoral_cycle_helper.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MemberAnalyticsWidget extends StatefulWidget {
  final UserEntity currentUser;
  final bool isEmbedded;

  const MemberAnalyticsWidget({
    super.key,
    required this.currentUser,
    this.isEmbedded = false,
  });

  @override
  State<MemberAnalyticsWidget> createState() => _MemberAnalyticsWidgetState();
}

class _MemberAnalyticsWidgetState extends State<MemberAnalyticsWidget> {
  late final ICellReportsRepository _reportsRepository;
  late final ICellRemoteDataSource _cellDataSource;

  bool _isLoading = true;
  CellMemberEntity? _currentMember;
  List<CellReportEntity> _cellReports = [];
  String? _cellId;
  String? _cellName; // <--- Variável para armazenar o nome da célula

  String _selectedMonthKey = 'all';

  @override
  void initState() {
    super.initState();
    _reportsRepository = getIt<ICellReportsRepository>();
    _cellDataSource = getIt<ICellRemoteDataSource>();
    _loadMemberAnalyticsData();
  }

  Future<void> _loadMemberAnalyticsData() async {
    setState(() => _isLoading = true);
    try {
      final user = widget.currentUser;
      String? targetCellId = user.primaryCellId;

      final allCells = await _cellDataSource.getCells(currentUser: user);

      if (targetCellId == null || targetCellId.trim().isEmpty) {
        for (var cell in allCells) {
          final members = await _cellDataSource.getCellMembers(cell.id);
          final found = members.any(
                (m) =>
            m.userId == user.id ||
                (user.name != null &&
                    m.name.trim().toLowerCase() ==
                        user.name!.trim().toLowerCase()),
          );
          if (found) {
            targetCellId = cell.id;
            break;
          }
        }
      }

      if (targetCellId != null && targetCellId.trim().isNotEmpty) {
        final members = await _cellDataSource.getCellMembers(targetCellId);

        CellMemberEntity? foundMember;
        try {
          foundMember = members.firstWhere(
                (m) =>
            m.userId == user.id ||
                (user.name != null &&
                    m.name.trim().toLowerCase() ==
                        user.name!.trim().toLowerCase()),
          );
        } catch (_) {}

        final reports =
        await _reportsRepository.getReportsByCell(targetCellId);

        // Busca o nome da célula para exibição
        String? fetchedCellName;
        try {
          final cellEntity = await _cellDataSource.getCellById(targetCellId);
          fetchedCellName = cellEntity.name;
        } catch (_) {}

        if (mounted) {
          setState(() {
            _cellId = targetCellId;
            _cellName = fetchedCellName;
            _currentMember = foundMember;
            _cellReports = reports;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Erro ao carregar analíticos do membro: $e');
    }
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

    String monthName = DateFormat("MMMM 'de' yyyy", 'pt_BR').format(date);
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

    if (_currentMember == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Não foi possível vincular seu perfil de membro na célula atual.\n\nVerifique com o líder se seu nome está cadastrado na lista de membros da célula.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
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

    // --- REGRAS DE CÁLCULO DE FREQUÊNCIA ---
    int totalValidMeetingsHeld = 0;
    int presences = 0;
    int justifiedAbsences = 0;
    int unjustifiedAbsences = 0;
    final Map<String, int> rolesCountMap = {};

    final memberJoinedDateOnly = DateTime(
      _currentMember!.joinedAt.year,
      _currentMember!.joinedAt.month,
      _currentMember!.joinedAt.day,
    );

    for (var report in filteredReports) {
      if (report.status == ReportStatus.cacelled) {
        continue;
      }

      final meetingDateOnly = DateTime(
        report.scheduledDate.year,
        report.scheduledDate.month,
        report.scheduledDate.day,
      );

      if (meetingDateOnly.isBefore(memberJoinedDateOnly)) {
        continue;
      }

      totalValidMeetingsHeld++;

      final attendance = report.attendances
          .cast<AttendanceEntity?>()
          .firstWhere(
            (a) =>
        a != null &&
            (a.cellMemberId == _currentMember!.id ||
                a.cellMemberId == _currentMember!.userId),
        orElse: () => null,
      );

      if (attendance != null) {
        if (attendance.isPresent) {
          presences++;
          for (var role in attendance.rolesPerformed) {
            rolesCountMap[role] = (rolesCountMap[role] ?? 0) + 1;
          }
        } else if (attendance.isJustified) {
          justifiedAbsences++;
        } else {
          unjustifiedAbsences++;
        }
      }
    }

    double attendanceRate = totalValidMeetingsHeld > 0
        ? (presences / totalValidMeetingsHeld) * 100
        : 0.0;

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
                  const Text(
                    'Sua Jornada na Célula',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (_cellName != null && _cellName!.isNotEmpty)
                    Text(
                      'Célula: $_cellName',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    'Acompanhe sua frequência e participações.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
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
                  value:
                  availableMonths.any((m) => m['key'] == _selectedMonthKey)
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
                      setState(() => _selectedMonthKey = val);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildMetricCard(
              'Frequência',
              '${attendanceRate.toStringAsFixed(0)}%',
              Icons.pie_chart_outline,
              Colors.blue,
            ),
            const SizedBox(width: 12),
            _buildMetricCard(
              'Presenças',
              '$presences/$totalValidMeetingsHeld',
              Icons.check_circle_outline,
              Colors.green,
            ),
            const SizedBox(width: 12),
            _buildMetricCard(
              'Justificadas',
              '$justifiedAbsences',
              Icons.info_outline,
              Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 20),
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
                const Row(
                  children: [
                    Icon(
                      Icons.volunteer_activism,
                      color: Colors.purple,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Minha Cooperação em Servir',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (rolesCountMap.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      'Nenhuma função registrada no período selecionado.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: rolesCountMap.entries.map((entry) {
                      return Chip(
                        avatar: CircleAvatar(
                          backgroundColor: Colors.purple.shade100,
                          child: Text(
                            '${entry.value}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade900,
                            ),
                          ),
                        ),
                        label: Text(entry.key),
                        backgroundColor: Colors.purple.shade50,
                        side: BorderSide(color: Colors.purple.shade200),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return listViewContent;
    }

    return RefreshIndicator(
      onRefresh: _loadMemberAnalyticsData,
      child: listViewContent,
    );
  }

  Widget _buildMetricCard(
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
                fontSize: 18,
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