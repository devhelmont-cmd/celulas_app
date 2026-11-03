// lib/src/features/cell_reports/presentation/widgets/meeting_status_chart_widget.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';

class MeetingStatusChartWidget extends StatelessWidget {
  final List<CellMeetingModel> meetings;

  const MeetingStatusChartWidget({
    super.key,
    required this.meetings,
  });

  @override
  Widget build(BuildContext context) {
    // Filtra apenas reuniões que já aconteceram e que possuem registro real,
    // ou que foram explicitamente canceladas/pontes no histórico passado.
    final pastMeetings = meetings.where((m) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final mDate = DateTime(m.meetingDate.year, m.meetingDate.month, m.meetingDate.day);

      // A data precisa ser passada (anterior ou igual a hoje)
      final bool isPastDate = mDate.isBefore(today) || mDate.isAtSameMomentAs(today);

      // Se for cancelada ou evento ponte, o histórico de reunião em si já define o status.
      // Se for normal, garantimos que ela realmente aconteceu (ou foi preenchida/passada).
      if (!isPastDate) return false;

      if (m.status == 'canceled' || m.status == 'bridge_event') {
        return true;
      }

      // Para reuniões normais do passado, consideramos apenas as que foram preenchidas
      // ou que já passaram do dia de tolerância, evitando contar agendamentos vazios futuros.
      return m.isReportFilled || m.isExpired;
    }).toList();

    int normalCount = 0;
    int canceledCount = 0;
    int bridgeCount = 0;

    for (var m in pastMeetings) {
      // Ignora status 'rescheduled' conforme alinhado
      if (m.status == 'rescheduled') continue;

      if (m.status == 'bridge_event') {
        bridgeCount++;
      } else if (m.status == 'canceled') {
        canceledCount++;
      } else {
        // Considera como reunião normal (inclui status normal ou outros padrões ocorridos)
        normalCount++;
      }
    }

    if (pastMeetings.isEmpty) {
      return const Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text('Nenhum histórico de reuniões passadas no período.'),
          ),
        ),
      );
    }

    double maxY = [normalCount, canceledCount, bridgeCount]
        .reduce((curr, next) => curr > next ? curr : next)
        .toDouble();
    if (maxY < 5) maxY = 5;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status das Reuniões Realizadas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Distribuição histórica entre reuniões normais, canceladas e eventos ponte.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Legenda / Resumo em Chips (Sem As Remarcadas)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusChip('Normais', normalCount, Colors.blue),
                _buildStatusChip('Canceladas', canceledCount, Colors.red),
                _buildStatusChip('Eventos Ponte', bridgeCount, Colors.teal),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY * 1.2,
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
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          if (value == 0 || value == maxY * 1.2) return const SizedBox.shrink();
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          Widget text;
                          switch (value.toInt()) {
                            case 0:
                              text = const Text('Normais', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold));
                              break;
                            case 1:
                              text = const Text('Cancel.', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold));
                              break;
                            case 2:
                              text = const Text('Ponte', style: TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.bold));
                              break;
                            default:
                              text = const Text('', style: TextStyle(fontSize: 11));
                              break;
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: text,
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: normalCount.toDouble(),
                          color: Colors.blue,
                          width: 26,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: canceledCount.toDouble(),
                          color: Colors.red,
                          width: 26,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(
                          toY: bridgeCount.toDouble(),
                          color: Colors.teal,
                          width: 26,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
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

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}