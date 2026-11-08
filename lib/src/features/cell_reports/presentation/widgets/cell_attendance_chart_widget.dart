// lib/src/features/cell_reports/presentation/widgets/cell_attendance_chart_widget.dart

import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/core/utils/pastoral_cycle_helper.dart';
import 'package:celulas_app/src/features/cell_reports/data/models/cell_report_model.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
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
  final double totalVisitors;
  final double totalConversions;

  _ConsolidatedMonthReport({
    required this.monthKey,
    required this.anchorDate,
    required this.shortLabel,
    required this.cleanLabel,
    required this.memberAttendanceRate,
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
  bool _isLoadingMembers = true;

  @override
  void initState() {
    super.initState();
    _cellDataSource = getIt<ICellRemoteDataSource>();
    _loadAllCellMembers();
  }

  /// Carrega os membros de todas as células presentes nos relatórios para poder calcular o
  /// ingresso efetivo e a frequência percentual no modo mensal.
  Future<void> _loadAllCellMembers() async {
    try {
      final cellIds = widget.reports.map((r) => r.cellId).toSet();
      for (var cellId in cellIds) {
        if (cellId.isNotEmpty) {
          final members = await _cellDataSource.getCellMembers(cellId);
          _cellMembersMap[cellId] = members;
        }
      }
    } catch (e) {
      debugPrint('Erros ao carregar membros para o gráfico: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
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
      // EXIBIÇÃO POR MESES: FREQUÊNCIA PERCENTUAL (%) PARA MEMBROS
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
        double visitorsSum = 0;
        double conversionsSum = 0;

        // Agrupa os relatórios do mês por célula para avaliar o histórico dos membros
        Map<String, List<CellReportEntity>> cellMonthReportsMap = {};
        for (var r in monthReports) {
          visitorsSum += r.visitors.length.toDouble();
          conversionsSum += r.conversions.length.toDouble();

          if (r.status == ReportStatus.cacelled) continue; // Descarta reuniões canceladas
          cellMonthReportsMap.putIfAbsent(r.cellId, () => []).add(r);
        }

        // Para cada célula com relatórios no mês
        cellMonthReportsMap.forEach((cellId, validReports) {
          final members = _cellMembersMap[cellId] ?? [];

          // Calcula a data de ingresso efetiva de cada membro na célula
          Map<String, DateTime> memberEffectiveStartDateMap = {};
          final allCellReportsSorted = List<CellReportEntity>.from(
              widget.reports.where((r) => r.cellId == cellId))
            ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

          for (var m in members) {
            DateTime? firstPresenceDate;
            for (var r in allCellReportsSorted) {
              if (r.status == ReportStatus.cacelled) continue;
              final att = r.attendances.cast<AttendanceModel?>().firstWhere(
                    (a) => a != null && (a.cellMemberId == m.id || a.cellMemberId == m.userId),
                orElse: () => null,
              );
              if (att != null && att.isPresent) {
                firstPresenceDate = DateTime(
                  r.scheduledDate.year,
                  r.scheduledDate.month,
                  r.scheduledDate.day,
                );
                break;
              }
            }

            final systemJoinedDateOnly = DateTime(
              m.joinedAt.year,
              m.joinedAt.month,
              m.joinedAt.day,
            );

            DateTime effectiveStart = systemJoinedDateOnly;
            if (firstPresenceDate != null &&
                firstPresenceDate.isBefore(systemJoinedDateOnly)) {
              effectiveStart = firstPresenceDate;
            }

            memberEffectiveStartDateMap[m.id] = effectiveStart;
            if (m.userId != null && m.userId!.isNotEmpty) {
              memberEffectiveStartDateMap[m.userId!] = effectiveStart;
            }
          }

          // Para cada reunião válida no mês
          for (var report in validReports) {
            final meetingDateOnly = DateTime(
              report.scheduledDate.year,
              report.scheduledDate.month,
              report.scheduledDate.day,
            );

            // Contabiliza apenas os membros que já eram ativos na data da reunião
            for (var m in members) {
              final effectiveStart = memberEffectiveStartDateMap[m.id] ??
                  memberEffectiveStartDateMap[m.userId] ??
                  m.joinedAt;

              if (!meetingDateOnly.isBefore(effectiveStart)) {
                totalExpectedAttendances++;

                final attendance = report.attendances.cast<AttendanceModel?>().firstWhere(
                      (a) => a != null && (a.cellMemberId == m.id || a.cellMemberId == m.userId),
                  orElse: () => null,
                );

                if (attendance != null && attendance.isPresent) {
                  totalActualPresences++;
                }
              }
            }
          }
        });

        double attendanceRate = totalExpectedAttendances > 0
            ? (totalActualPresences / totalExpectedAttendances) * 100
            : 0.0;

        consolidatedList.add(_ConsolidatedMonthReport(
          monthKey: monthKey,
          anchorDate: anchorDate,
          shortLabel: shortLabel,
          cleanLabel: cleanLabel,
          memberAttendanceRate: attendanceRate,
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
                            ? 'Frequência de membros (%) e totais de visitantes/conversões.'
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
                      label: Text('Semanas', style: TextStyle(fontSize: 11)),
                    ),
                    const ButtonSegment(
                      value: ChartViewGrouping.dates,
                      label: Text('Datas', style: TextStyle(fontSize: 11)),
                    ),
                    if (widget.selectedMonthKey == 'all')
                      const ButtonSegment(
                        value: ChartViewGrouping.months,
                        label: Text('Meses', style: TextStyle(fontSize: 11)),
                      ),
                  ],
                  selected: {_groupingMode},
                  onSelectionChanged: (Set<ChartViewGrouping> newSelection) {
                    setState(() {
                      _groupingMode = newSelection.first;
                    });
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildLegendItem(
                  isMonthMode ? 'Frequência Membros (%)' : 'Membros (Presenças)',
                  Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildLegendItem('Visitantes', Colors.orange),
                const SizedBox(width: 12),
                _buildLegendItem('Conversões', Colors.green),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 230,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return List.generate(touchedSpots.length, (i) {
                          final spot = touchedSpots[i];

                          String headerTitle = '';
                          if (_groupingMode == ChartViewGrouping.cycles) {
                            if (spot.spotIndex >= 0 &&
                                spot.spotIndex < recentCycles.length) {
                              final cycle = recentCycles[spot.spotIndex];
                              headerTitle = cycle.cleanLabel;
                            }
                          } else if (_groupingMode == ChartViewGrouping.months) {
                            if (spot.spotIndex >= 0 &&
                                spot.spotIndex < recentMonths.length) {
                              final m = recentMonths[spot.spotIndex];
                              headerTitle = m.cleanLabel;
                            }
                          } else {
                            if (spot.spotIndex >= 0 &&
                                spot.spotIndex < dateLabels.length) {
                              headerTitle =
                              'Data: ${dateLabels[spot.spotIndex]}';
                            }
                          }

                          String metricText = '';
                          if (spot.barIndex == 0) {
                            metricText = isMonthMode
                                ? 'Frequência Membros: ${spot.y.toStringAsFixed(0)}%'
                                : 'Membros: ${spot.y.toInt()}';
                          }
                          if (spot.barIndex == 1) {
                            metricText = 'Visitantes: ${spot.y.toInt()}';
                          }
                          if (spot.barIndex == 2) {
                            metricText = 'Conversões: ${spot.y.toInt()}';
                          }

                          if (i == 0) {
                            return LineTooltipItem(
                              '$headerTitle\n$metricText',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            );
                          } else {
                            return LineTooltipItem(
                              metricText,
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            );
                          }
                        });
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade300,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) {
                            return const SizedBox.shrink();
                          }

                          final index = value.toInt();

                          if (_groupingMode == ChartViewGrouping.cycles) {
                            if (index < 0 || index >= recentCycles.length) {
                              return const SizedBox.shrink();
                            }

                            final currentLabel =
                            recentCycles[index].shortLabel.trim();

                            if (index > 0) {
                              final previousLabel =
                              recentCycles[index - 1].shortLabel.trim();
                              if (currentLabel == previousLabel) {
                                return const SizedBox.shrink();
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                recentCycles[index].shortLabel,
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            );
                          } else if (_groupingMode == ChartViewGrouping.months) {
                            if (index < 0 || index >= recentMonths.length) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                recentMonths[index].shortLabel,
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            );
                          } else {
                            if (index < 0 || index >= dateLabels.length) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                dateLabels[index],
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: memberSpots,
                      isCurved: true,
                      curveSmoothness: 0.15,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: visitorSpots,
                      isCurved: true,
                      curveSmoothness: 0.15,
                      color: Colors.orange,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: conversionSpots,
                      isCurved: true,
                      curveSmoothness: 0.15,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}