// lib/src/features/cell_reports/presentation/widgets/cell_attendance_chart_widget.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/core/utils/pastoral_cycle_helper.dart';
import 'package:intl/intl.dart';

class _ConsolidatedCycleReport {
  final String cycleKey;
  final DateTime anchorSunday;
  final String shortLabel; // Ex: "S1 Out"
  final String cleanLabel; // Ex: "Semana 1 de Outubro" (sem data)
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

class CellAttendanceChartWidget extends StatelessWidget {
  final List<CellReportEntity> reports;

  const CellAttendanceChartWidget({
    super.key,
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text('Sem relatórios suficientes para gerar gráficos.'),
          ),
        ),
      );
    }

    // 1. Agrupa e soma os relatórios por Ciclo Pastoral
    Map<String, List<CellReportEntity>> reportsByCycle = {};
    for (var r in reports) {
      final String cycleKey = (r.cycleKey != null && r.cycleKey!.isNotEmpty)
          ? r.cycleKey!
          : PastoralCycleHelper.getCycleKeyString(r.scheduledDate);

      reportsByCycle.putIfAbsent(cycleKey, () => []).add(r);
    }

    // 2. Converte o agrupamento em pontos consolidados por ciclo
    List<_ConsolidatedCycleReport> consolidatedList = [];
    reportsByCycle.forEach((cycleKey, cycleReports) {
      final parts = cycleKey.split('-');
      DateTime anchorSunday = cycleReports.first.scheduledDate;
      if (parts.length == 3) {
        anchorSunday = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }

      // Calcula a semana do mês (1º, 2º, 3º...)
      int weekNumber = ((anchorSunday.day - 1) ~/ 7) + 1;

      // Nome do mês por extenso (ex: "Outubro")
      final monthFullName = DateFormat('MMMM', 'pt_BR').format(anchorSunday);
      final capitalizedFullName = monthFullName.isNotEmpty
          ? '${monthFullName[0].toUpperCase()}${monthFullName.substring(1)}'
          : '';

      // Nome abreviado do mês para o eixo X (ex: "Out")
      final monthShortName = DateFormat('MMM', 'pt_BR').format(anchorSunday);
      final capitalizedShortName = monthShortName.isNotEmpty
          ? '${monthShortName[0].toUpperCase()}${monthShortName.substring(1).replaceAll('.', '')}'
          : '';

      final shortLabel = 'S$weekNumber $capitalizedShortName'; // Ex: "S1 Out"
      final cleanLabel = 'Semana $weekNumber de $capitalizedFullName'; // Ex: "Semana 1 de Outubro" (sem data)

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

    // 3. Ordena cronologicamente
    consolidatedList.sort((a, b) => a.anchorSunday.compareTo(b.anchorSunday));

    // 4. Pega apenas os últimos 7 ciclos para manter o gráfico limpo
    final recentCycles = consolidatedList.length > 7
        ? consolidatedList.sublist(consolidatedList.length - 7)
        : consolidatedList;

    List<FlSpot> memberSpots = [];
    List<FlSpot> visitorSpots = [];
    List<FlSpot> conversionSpots = [];

    for (int i = 0; i < recentCycles.length; i++) {
      final c = recentCycles[i];
      memberSpots.add(FlSpot(i.toDouble(), c.totalMembers));
      visitorSpots.add(FlSpot(i.toDouble(), c.totalVisitors));
      conversionSpots.add(FlSpot(i.toDouble(), c.totalConversions));
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Evolução por Ciclos Pastorais',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Consolidado geral da igreja por semanas pastorais.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),

            // Legenda
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
                  // Tooltip sem data do domingo, apenas o número/nome da semana e os dados abaixo
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return List.generate(touchedSpots.length, (i) {
                          final spot = touchedSpots[i];
                          final cycle = recentCycles[spot.spotIndex];

                          String metricText = '';
                          if (spot.barIndex == 0) metricText = 'Membros: ${spot.y.toInt()}';
                          if (spot.barIndex == 1) metricText = 'Visitantes: ${spot.y.toInt()}';
                          if (spot.barIndex == 2) metricText = 'Conversões: ${spot.y.toInt()}';

                          if (i == 0) {
                            return LineTooltipItem(
                              '${cycle.cleanLabel}\n$metricText',
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
                          final index = value.toInt();
                          if (index < 0 || index >= recentCycles.length) {
                            return const SizedBox.shrink();
                          }

                          if (index > 0 && recentCycles[index].shortLabel == recentCycles[index - 1].shortLabel) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              recentCycles[index].shortLabel,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          );
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