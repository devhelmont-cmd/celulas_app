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
    int normalCount = 0;
    int rescheduledCount = 0;
    int canceledCount = 0;
    int bridgeCount = 0;

    for (var m in meetings) {
      if (m.status == 'bridge_event') {
        bridgeCount++;
      } else if (m.status == 'canceled') {
        canceledCount++;
      } else if (m.status == 'rescheduled') {
        rescheduledCount++;
      } else {
        normalCount++;
      }
    }

    if (meetings.isEmpty) {
      return const SizedBox.shrink();
    }

    double maxY = [normalCount, rescheduledCount, canceledCount, bridgeCount]
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
              'Status das Reuniões e Eventos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Distribuição geral entre reuniões normais, remarcadas, canceladas e eventos ponte.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Legenda / Resumo em Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusChip('Normais', normalCount, Colors.blue),
                _buildStatusChip('Remarcadas', rescheduledCount, Colors.purple),
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
                              text = const Text('Remarc.', style: TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold));
                              break;
                            case 2:
                              text = const Text('Cancel.', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold));
                              break;
                            case 3:
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
                          width: 22,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: rescheduledCount.toDouble(),
                          color: Colors.purple,
                          width: 22,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(
                          toY: canceledCount.toDouble(),
                          color: Colors.red,
                          width: 22,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 3,
                      barRods: [
                        BarChartRodData(
                          toY: bridgeCount.toDouble(),
                          color: Colors.teal,
                          width: 22,
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