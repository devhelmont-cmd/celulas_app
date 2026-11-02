// lib/src/features/cell_reports/presentation/widgets/cell_attendance_chart_widget.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/core/utils/pastoral_cycle_helper.dart';
import 'package:intl/intl.dart';

enum ChartViewGrouping { cycles, dates }

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

class CellAttendanceChartWidget extends StatefulWidget {
  final List<CellReportEntity> reports;
  final String selectedMonthKey; // Ex: "all" ou "2026-09"

  const CellAttendanceChartWidget({
    super.key,
    required this.reports,
    required this.selectedMonthKey,
  });

  @override
  State<CellAttendanceChartWidget> createState() => _CellAttendanceChartWidgetState();
}

class _CellAttendanceChartWidgetState extends State<CellAttendanceChartWidget> {
  ChartViewGrouping _groupingMode = ChartViewGrouping.cycles;

  @override
  Widget build(BuildContext context) {
    if (widget.reports.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text('Sem relatórios suficientes para gerar gráficos.'),
          ),
        ),
      );
    }

    // Filtra os relatórios baseando-se sempre no cycleKey correspondente ao mês selecionado
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
          anchorSunday = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
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
          membersSum += r.attendances.where((a) => a.isPresent).length.toDouble();
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
    } else {
      // Modo Datas Específicas: Exibe os relatórios filtrados pelo ciclo do mês
      Map<String, List<CellReportEntity>> reportsByDate = {};
      for (var r in activeReports) {
        final String dateKey = '${r.scheduledDate.year}-${r.scheduledDate.month.toString().padLeft(2, '0')}-${r.scheduledDate.day.toString().padLeft(2, '0')}';
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
          membersSum += r.attendances.where((a) => a.isPresent).length.toDouble();
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
                            ? 'Evolução por Ciclos Pastorais'
                            : 'Evolução por Datas Específicas',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _groupingMode == ChartViewGrouping.cycles
                            ? 'Consolidado geral da igreja por semanas pastorais.'
                            : 'Consolidado geral da igreja por dias de reunião.',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                SegmentedButton<ChartViewGrouping>(
                  segments: const [
                    ButtonSegment(
                      value: ChartViewGrouping.cycles,
                      label: Text('Semanas', style: TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment(
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
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildLegendItem('Membros', Colors.blue),
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
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return List.generate(touchedSpots.length, (i) {
                          final spot = touchedSpots[i];

                          String headerTitle = '';
                          if (_groupingMode == ChartViewGrouping.cycles) {
                            if (spot.spotIndex >= 0 && spot.spotIndex < recentCycles.length) {
                              final cycle = recentCycles[spot.spotIndex];
                              headerTitle = cycle.cleanLabel;
                            }
                          } else {
                            if (spot.spotIndex >= 0 && spot.spotIndex < dateLabels.length) {
                              headerTitle = 'Data: ${dateLabels[spot.spotIndex]}';
                            }
                          }

                          String metricText = '';
                          if (spot.barIndex == 0) metricText = 'Membros: ${spot.y.toInt()}';
                          if (spot.barIndex == 1) metricText = 'Visitantes: ${spot.y.toInt()}';
                          if (spot.barIndex == 2) metricText = 'Conversões: ${spot.y.toInt()}';

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
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          // 1. Evita que índices fracionados repitam o mesmo número inteiro
                          if (value % 1 != 0) {
                            return const SizedBox.shrink();
                          }

                          final index = value.toInt();

                          if (_groupingMode == ChartViewGrouping.cycles) {
                            if (index < 0 || index >= recentCycles.length) {
                              return const SizedBox.shrink();
                            }

                            // 2. Remove espaços extras antes de comparar as strings
                            final currentLabel = recentCycles[index].shortLabel.trim();

                            if (index > 0) {
                              final previousLabel = recentCycles[index - 1].shortLabel.trim();
                              if (currentLabel == previousLabel) {
                                return const SizedBox.shrink();
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                recentCycles[index].shortLabel,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: visitorSpots,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: conversionSpots,
                      isCurved: true,
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