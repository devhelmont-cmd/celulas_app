// lib/src/features/cell_reports/presentation/widgets/cell_attendance_chart_widget.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';

class _ConsolidatedReport {
  final DateTime date;
  final double totalMembers;
  final double totalVisitors;
  final double totalConversions;

  _ConsolidatedReport({
    required this.date,
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

    // 1. Agrupa e soma os relatórios por data exata (ano, mês, dia)
    Map<String, List<CellReportEntity>> reportsByDate = {};
    for (var r in reports) {
      final dateKey = '${r.scheduledDate.year}-${r.scheduledDate.month.toString().padLeft(2, '0')}-${r.scheduledDate.day.toString().padLeft(2, '0')}';
      reportsByDate.putIfAbsent(dateKey, () => []).add(r);
    }

    // 2. Converte o agrupamento em pontos consolidados
    List<_ConsolidatedReport> consolidatedList = [];
    reportsByDate.forEach((dateKey, dateReports) {
      final date = dateReports.first.scheduledDate;
      double membersSum = 0;
      double visitorsSum = 0;
      double conversionsSum = 0;

      for (var r in dateReports) {
        membersSum += r.attendances.where((a) => a.isPresent).length.toDouble();
        visitorsSum += r.visitors.length.toDouble();
        conversionsSum += r.conversions.length.toDouble();
      }

      consolidatedList.add(_ConsolidatedReport(
        date: date,
        totalMembers: membersSum,
        totalVisitors: visitorsSum,
        totalConversions: conversionsSum,
      ));
    });

    // 3. Ordena cronologicamente do mais antigo para o mais recente
    consolidatedList.sort((a, b) => a.date.compareTo(b.date));

    // 4. Pega apenas as últimas 8 datas para manter o gráfico limpo
    final recentReports = consolidatedList.length > 8
        ? consolidatedList.sublist(consolidatedList.length - 8)
        : consolidatedList;

    List<FlSpot> memberSpots = [];
    List<FlSpot> visitorSpots = [];
    List<FlSpot> conversionSpots = [];

    for (int i = 0; i < recentReports.length; i++) {
      final r = recentReports[i];
      memberSpots.add(FlSpot(i.toDouble(), r.totalMembers));
      visitorSpots.add(FlSpot(i.toDouble(), r.totalVisitors));
      conversionSpots.add(FlSpot(i.toDouble(), r.totalConversions));
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
              'Evolução Geral da Igreja (Últimas Datas)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              height: 220,
              child: LineChart(
                LineChartData(
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
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= recentReports.length) {
                            return const SizedBox.shrink();
                          }
                          final date = recentReports[index].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // Linha de Membros
                    LineChartBarData(
                      spots: memberSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                    // Linha de Visitantes
                    LineChartBarData(
                      spots: visitorSpots,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                    // Linha de Conversões
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