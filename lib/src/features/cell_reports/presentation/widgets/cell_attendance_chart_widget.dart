// lib/src/features/cell_reports/presentation/widgets/cell_attendance_chart_widget.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/core/utils/pastoral_cycle_helper.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_member_model.dart';
import 'package:celulas_app/src/features/cells/data/models/member_period_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ChartViewGrouping { cycles, dates, months }

class _ConsolidatedCycleReport {
  final String cycleKey;
  final DateTime anchorSunday;
  final String shortLabel;
  final String cleanLabel;
  final double totalMembers;
  final double totalVisitors;
  final double totalConversions;

  _ConsolidatedCycleReport({
    required this.cycleKey,
    required this.anchorSunday,
    required this.shortLabel,
    required this.cleanLabel,
    required this.totalMembers,
    required this.totalVisitors,
    required this.totalConversions,
  });
}

class _ConsolidatedMonthReport {
  final String monthKey;
  final DateTime anchorDate;
  final String shortLabel;
  final String cleanLabel;
  final double memberAttendanceRate; // Porcentagem (0% - 100%)
  final double totalUnexcused; // Quantidade de faltas não justificadas
  final double totalVisitors;
  final double totalConversions;

  _ConsolidatedMonthReport({
    required this.monthKey,
    required this.anchorDate,
    required this.shortLabel,
    required this.cleanLabel,
    required this.memberAttendanceRate,
    required this.totalUnexcused,
    required this.totalVisitors,
    required this.totalConversions,
  });
}

class CellAttendanceChartWidget extends StatefulWidget {
  final List<CellReportEntity> reports;
  final String selectedMonthKey; // Ex: "all" ou "2026-09"

  const CellAttendanceChartWidget({
    super.key,
    required this.reports,
    required this.selectedMonthKey,
  });

  @override
  State<CellAttendanceChartWidget> createState() =>
      _CellAttendanceChartWidgetState();
}

class _CellAttendanceChartWidgetState
    extends State<CellAttendanceChartWidget> {
  ChartViewGrouping _groupingMode = ChartViewGrouping.cycles;

  late final ICellRemoteDataSource _cellDataSource;
  final Map<String, List<CellMemberEntity>> _cellMembersMap = {};
  final Map<String, List<MemberPeriodModel>> _memberPeriodsMap = {};
  final Map<String, CellMemberEntity> _allMembersMap = {};
  bool _isLoadingMembers = true;

  @override
  void initState() {
    super.initState();
    _cellDataSource = getIt<ICellRemoteDataSource>();
    _loadAllCellMembers();
  }

  /// Carrega todos os membros e o histórico de períodos (`collectionGroup('periods')`)
  /// para calcular a frequência percentual exata e fiel no modo mensal.
  Future<void> _loadAllCellMembers() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Carrega todos os membros do Firestore
      final membersSnap = await firestore.collection('members').get();
      for (var doc in membersSnap.docs) {
        final m = CellMemberModel.fromMap(doc.data(), doc.id);
        _allMembersMap[m.id] = m;
        if (m.userId != null && m.userId!.isNotEmpty) {
          _allMembersMap[m.userId!] = m;
        }
      }

      // 2. Garante também a busca dos membros das células dos relatórios
      final cellIds = widget.reports.map((r) => r.cellId).toSet();
      for (var cellId in cellIds) {
        if (cellId.isNotEmpty) {
          try {
            final members = await _cellDataSource.getCellMembers(cellId);
            _cellMembersMap[cellId] = members;
            for (var m in members) {
              _allMembersMap[m.id] = m;
              if (m.userId != null && m.userId!.isNotEmpty) {
                _allMembersMap[m.userId!] = m;
              }
            }
          } catch (_) {}
        }
      }

      // 3. Busca a coleção de períodos históricos dos membros
      final periodsSnap = await firestore.collectionGroup('periods').get();
      for (var doc in periodsSnap.docs) {
        final parentMemberId = doc.reference.parent.parent?.id;
        if (parentMemberId != null && parentMemberId.isNotEmpty) {
          final period = MemberPeriodModel.fromMap(doc.data(), doc.id);
          _memberPeriodsMap.putIfAbsent(parentMemberId, () => []).add(period);
        }
      }
    } catch (e) {
      debugPrint('Erros ao carregar membros e períodos para o gráfico: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  /// Verifica se um determinado membro estava ativo na célula em uma data específica
  bool _isMemberActiveInCellOnDate({
    required CellMemberEntity member,
    required String cellId,
    required DateTime date,
  }) {
    final targetDate = DateTime(date.year, date.month, date.day);
    final memberId = member.id;
    final periods = _memberPeriodsMap[memberId] ?? [];

    if (periods.isNotEmpty) {
      for (var p in periods) {
        if (p.cellId != cellId) continue;

        final startOnly =
            DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
        final endOnly = p.endDate != null
            ? DateTime(p.endDate!.year, p.endDate!.month, p.endDate!.day)
            : null;

        if (!targetDate.isBefore(startOnly) &&
            (endOnly == null || !targetDate.isAfter(endOnly))) {
          return true;
        }
      }
      return false;
    }

    // Se não há histórico na subcoleção 'periods', verifica joinedAt e cellId direta
    if (member.cellId == cellId) {
      final joinedOnly = DateTime(
        member.joinedAt.year,
        member.joinedAt.month,
        member.joinedAt.day,
      );
      return !targetDate.isBefore(joinedOnly);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reports.isEmpty || _isLoadingMembers) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    // Se um mês específico foi filtrado e o modo atual for 'months', volta para 'cycles'
    if (widget.selectedMonthKey != 'all' &&
        _groupingMode == ChartViewGrouping.months) {
      _groupingMode = ChartViewGrouping.cycles;
    }

    // Filtra os relatórios baseando-se no cycleKey correspondente ao mês selecionado
    List<CellReportEntity> activeReports = widget.reports;
    if (widget.selectedMonthKey != 'all') {
      activeReports = widget.reports.where((r) {
        final cycleKey = (r.cycleKey != null && r.cycleKey!.isNotEmpty)
            ? r.cycleKey!
            : PastoralCycleHelper.getCycleKeyString(r.scheduledDate);
        return cycleKey.startsWith(widget.selectedMonthKey);
      }).toList();
    }

    List<FlSpot> memberSpots = [];
    List<FlSpot> visitorSpots = [];
    List<FlSpot> conversionSpots = [];
    List<FlSpot> unexcusedSpots = [];

    List<_ConsolidatedCycleReport> recentCycles = [];
    List<_ConsolidatedMonthReport> recentMonths = [];
    List<String> dateLabels = [];

    if (_groupingMode == ChartViewGrouping.cycles) {
      Map<String, List<CellReportEntity>> reportsByCycle = {};
      for (var r in activeReports) {
        final String cycleKey = (r.cycleKey != null && r.cycleKey!.isNotEmpty)
            ? r.cycleKey!
            : PastoralCycleHelper.getCycleKeyString(r.scheduledDate);

        reportsByCycle.putIfAbsent(cycleKey, () => []).add(r);
      }

      List<_ConsolidatedCycleReport> consolidatedList = [];
      reportsByCycle.forEach((cycleKey, cycleReports) {
        final parts = cycleKey.split('-');
        DateTime anchorSunday = cycleReports.first.scheduledDate;
        if (parts.length == 3) {
          anchorSunday = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }

        int weekNumber = ((anchorSunday.day - 1) ~/ 7) + 1;

        final monthFullName = DateFormat('MMMM', 'pt_BR').format(anchorSunday);
        final capitalizedFullName = monthFullName.isNotEmpty
            ? '${monthFullName[0].toUpperCase()}${monthFullName.substring(1)}'
            : '';

        final monthShortName = DateFormat('MMM', 'pt_BR').format(anchorSunday);
        final capitalizedShortName = monthShortName.isNotEmpty
            ? '${monthShortName[0].toUpperCase()}${monthShortName.substring(1).replaceAll('.', '')}'
            : '';

        final shortLabel = 'S$weekNumber $capitalizedShortName';
        final cleanLabel = 'Semana $weekNumber de $capitalizedFullName';

        double membersSum = 0;
        double visitorsSum = 0;
        double conversionsSum = 0;

        for (var r in cycleReports) {
          membersSum +=
              r.attendances.where((a) => a.isPresent).length.toDouble();
          visitorsSum += r.visitors.length.toDouble();
          conversionsSum += r.conversions.length.toDouble();
        }

        consolidatedList.add(_ConsolidatedCycleReport(
          cycleKey: cycleKey,
          anchorSunday: anchorSunday,
          shortLabel: shortLabel,
          cleanLabel: cleanLabel,
          totalMembers: membersSum,
          totalVisitors: visitorsSum,
          totalConversions: conversionsSum,
        ));
      });

      consolidatedList.sort((a, b) => a.anchorSunday.compareTo(b.anchorSunday));

      recentCycles = consolidatedList.length > 7
          ? consolidatedList.sublist(consolidatedList.length - 7)
          : consolidatedList;

      for (int i = 0; i < recentCycles.length; i++) {
        final c = recentCycles[i];
        memberSpots.add(FlSpot(i.toDouble(), c.totalMembers));
        visitorSpots.add(FlSpot(i.toDouble(), c.totalVisitors));
        conversionSpots.add(FlSpot(i.toDouble(), c.totalConversions));
      }
    } else if (_groupingMode == ChartViewGrouping.months) {
      // =========================================================
      // EXIBIÇÃO POR MESES: FREQUÊNCIA PERCENTUAL (%) E FALTAS NÃO JUSTIFICADAS (QTD)
      // =========================================================
      Map<String, List<CellReportEntity>> reportsByMonthKey = {};
      for (var r in activeReports) {
        final cycleKey = (r.cycleKey != null && r.cycleKey!.isNotEmpty)
            ? r.cycleKey!
            : PastoralCycleHelper.getCycleKeyString(r.scheduledDate);

        String monthKey = cycleKey.length >= 7
            ? cycleKey.substring(0, 7)
            : '${r.scheduledDate.year}-${r.scheduledDate.month.toString().padLeft(2, '0')}';

        reportsByMonthKey.putIfAbsent(monthKey, () => []).add(r);
      }

      List<_ConsolidatedMonthReport> consolidatedList = [];
      final uniqueMembers = _allMembersMap.values.toSet().toList();

      reportsByMonthKey.forEach((monthKey, monthReports) {
        final parts = monthKey.split('-');
        int year = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        DateTime anchorDate = DateTime(year, month, 1);

        final monthFullName =
            DateFormat('MMMM \'de\' yyyy', 'pt_BR').format(anchorDate);
        final capitalizedFullName = monthFullName.isNotEmpty
            ? '${monthFullName[0].toUpperCase()}${monthFullName.substring(1)}'
            : '';

        final monthShortName =
            DateFormat('MMM/yy', 'pt_BR').format(anchorDate);
        final capitalizedShortName = monthShortName.isNotEmpty
            ? '${monthShortName[0].toUpperCase()}${monthShortName.substring(1).replaceAll('.', '')}'
            : '';

        final shortLabel = capitalizedShortName;
        final cleanLabel = 'Mês de $capitalizedFullName';

        int totalExpectedAttendances = 0;
        int totalActualPresences = 0;
        int totalUnexcusedAbsences = 0;
        double visitorsSum = 0;
        double conversionsSum = 0;

        for (var report in monthReports) {
          visitorsSum += report.visitors.length.toDouble();
          conversionsSum += report.conversions.length.toDouble();

          if (report.status == ReportStatus.cacelled) continue; // Descarta reuniões canceladas

          final reportDate = report.scheduledDate;
          final reportCellId = report.cellId;

          // Avalia cada membro com base no histórico de períodos na data da reunião
          for (var member in uniqueMembers) {
            final isActiveInCell = _isMemberActiveInCellOnDate(
              member: member,
              cellId: reportCellId,
              date: reportDate,
            );

            if (!isActiveInCell) continue;

            totalExpectedAttendances++;

            final attendance = report.attendances.cast<AttendanceEntity?>().firstWhere(
                  (att) =>
                      att?.cellMemberId == member.id ||
                      (member.userId != null &&
                          member.userId!.isNotEmpty &&
                          att?.cellMemberId == member.userId),
                  orElse: () => null,
                );

            if (attendance != null) {
              if (attendance.isPresent) {
                totalActualPresences++;
              } else if (!attendance.isJustificationApproved) {
                totalUnexcusedAbsences++;
              }
            } else {
              // Membro ativo sem registro = falta não justificada
              totalUnexcusedAbsences++;
            }
          }
        }

        double attendanceRate = totalExpectedAttendances > 0
            ? (totalActualPresences / totalExpectedAttendances) * 100
            : 0.0;

        consolidatedList.add(_ConsolidatedMonthReport(
          monthKey: monthKey,
          anchorDate: anchorDate,
          shortLabel: shortLabel,
          cleanLabel: cleanLabel,
          memberAttendanceRate: attendanceRate,
          totalUnexcused: totalUnexcusedAbsences.toDouble(),
          totalVisitors: visitorsSum,
          totalConversions: conversionsSum,
        ));
      });

      consolidatedList.sort((a, b) => a.anchorDate.compareTo(b.anchorDate));

      recentMonths = consolidatedList.length > 7
          ? consolidatedList.sublist(consolidatedList.length - 7)
          : consolidatedList;

      for (int i = 0; i < recentMonths.length; i++) {
        final c = recentMonths[i];
        memberSpots.add(FlSpot(i.toDouble(), c.memberAttendanceRate));
        visitorSpots.add(FlSpot(i.toDouble(), c.totalVisitors));
        conversionSpots.add(FlSpot(i.toDouble(), c.totalConversions));
        unexcusedSpots.add(FlSpot(i.toDouble(), c.totalUnexcused));
      }
    } else {
      // Modo Datas Específicas
      Map<String, List<CellReportEntity>> reportsByDate = {};
      for (var r in activeReports) {
        final String dateKey =
            '${r.scheduledDate.year}-${r.scheduledDate.month.toString().padLeft(2, '0')}-${r.scheduledDate.day.toString().padLeft(2, '0')}';
        reportsByDate.putIfAbsent(dateKey, () => []).add(r);
      }

      var sortedDateKeys = reportsByDate.keys.toList()..sort();
      if (sortedDateKeys.length > 7) {
        sortedDateKeys = sortedDateKeys.sublist(sortedDateKeys.length - 7);
      }

      for (int i = 0; i < sortedDateKeys.length; i++) {
        final dateKey = sortedDateKeys[i];
        final dayReports = reportsByDate[dateKey]!;

        double membersSum = 0;
        double visitorsSum = 0;
        double conversionsSum = 0;

        for (var r in dayReports) {
          membersSum +=
              r.attendances.where((a) => a.isPresent).length.toDouble();
          visitorsSum += r.visitors.length.toDouble();
          conversionsSum += r.conversions.length.toDouble();
        }

        final parts = dateKey.split('-');
        final formattedDate = '${parts[2]}/${parts[1]}';
        dateLabels.add(formattedDate);

        memberSpots.add(FlSpot(i.toDouble(), membersSum));
        visitorSpots.add(FlSpot(i.toDouble(), visitorsSum));
        conversionSpots.add(FlSpot(i.toDouble(), conversionsSum));
      }
    }

    final isMonthMode = _groupingMode == ChartViewGrouping.months;

    int itemCount = 0;
    if (_groupingMode == ChartViewGrouping.cycles) {
      itemCount = recentCycles.length;
    } else if (_groupingMode == ChartViewGrouping.months) {
      itemCount = recentMonths.length;
    } else {
      itemCount = dateLabels.length;
    }

    final double minX = 0;
    final double maxX = itemCount > 1 ? (itemCount - 1).toDouble() : 1.0;

    return Card(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _groupingMode == ChartViewGrouping.cycles
                            ? 'Evolução por Ciclos Semanais'
                            : (_groupingMode == ChartViewGrouping.months
                            ? 'Evolução por Meses'
                            : 'Evolução por Datas Específicas'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _groupingMode == ChartViewGrouping.cycles
                            ? 'Consolidado geral por semanas pastorais.'
                            : (_groupingMode == ChartViewGrouping.months
                            ? 'Frequência (%), faltas e totais de visitantes/conversões.'
                            : 'Consolidado geral por dias de reunião.'),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                SegmentedButton<ChartViewGrouping>(
                  segments: [
                    const ButtonSegment(
                      value: ChartViewGrouping.cycles,
                      label: Text('Ciclos', style: TextStyle(fontSize: 11)),
                    ),
                    if (widget.selectedMonthKey == 'all')
                      const ButtonSegment(
                        value: ChartViewGrouping.months,
                        label: Text('Meses', style: TextStyle(fontSize: 11)),
                      ),
                    const ButtonSegment(
                      value: ChartViewGrouping.dates,
                      label: Text('Datas', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                  selected: {_groupingMode},
                  onSelectionChanged: (Set<ChartViewGrouping> newSelection) {
                    setState(() {
                      _groupingMode = newSelection.first;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            isMonthMode
                                ? '${value.toInt()}%'
                                : value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          final index = value.toInt();
                          if (_groupingMode == ChartViewGrouping.cycles) {
                            if (index >= 0 && index < recentCycles.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  recentCycles[index].shortLabel,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black87,
                                  ),
                                ),
                              );
                            }
                          } else if (_groupingMode == ChartViewGrouping.months) {
                            if (index >= 0 && index < recentMonths.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  recentMonths[index].shortLabel,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black87,
                                  ),
                                ),
                              );
                            }
                          } else {
                            if (index >= 0 && index < dateLabels.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  dateLabels[index],
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black87,
                                  ),
                                ),
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          String label = '';
                          String valStr = '';

                          if (spot.barIndex == 0) {
                            label = isMonthMode
                                ? 'Frequência Membros'
                                : 'Membros Presentes';
                            valStr = isMonthMode
                                ? '${spot.y.toStringAsFixed(1)}%'
                                : spot.y.toInt().toString();
                          } else if (spot.barIndex == 1) {
                            label = 'Visitantes';
                            valStr = spot.y.toInt().toString();
                          } else if (spot.barIndex == 2) {
                            label = 'Conversões';
                            valStr = spot.y.toInt().toString();
                          } else if (spot.barIndex == 3) {
                            label = 'Faltas Não Justificadas';
                            valStr = spot.y.toInt().toString();
                          }

                          return LineTooltipItem(
                            '$label: $valStr',
                            TextStyle(
                              color: spot.bar.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    // Linha 1: Membros (Presença)
                    LineChartBarData(
                      spots: memberSpots,
                      isCurved: true,
                      color: Colors.purple,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.purple.withValues(alpha: 0.1),
                      ),
                    ),
                    // Linha 2: Visitantes
                    LineChartBarData(
                      spots: visitorSpots,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                    ),
                    // Linha 3: Conversões
                    LineChartBarData(
                      spots: conversionSpots,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                    ),
                    if (isMonthMode) ...[
                      // Linha 4: Faltas Não Justificadas
                      LineChartBarData(
                        spots: unexcusedSpots,
                        isCurved: true,
                        color: Colors.red,
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legenda
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildLegendItem(
                  isMonthMode ? 'Frequência Membros (%)' : 'Membros Presentes',
                  Colors.purple,
                ),
                _buildLegendItem('Visitantes', Colors.orange),
                _buildLegendItem('Conversões', Colors.green),
                if (isMonthMode) ...[
                  _buildLegendItem('Faltas Não Justificadas', Colors.red),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
