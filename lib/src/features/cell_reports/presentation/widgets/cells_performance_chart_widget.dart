// lib/src/features/cell_reports/presentation/widgets/cells_performance_chart_widget.dart
import 'package:flutter/material.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';

class CellsPerformanceChartWidget extends StatelessWidget {
  final List<CellReportEntity> reports;
  final List<CellModel> cells;

  const CellsPerformanceChartWidget({
    super.key,
    required this.reports,
    required this.cells,
  });

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) {
      return const SizedBox.shrink();
    }

    // 1. Conta quantos relatórios cada célula tem
    Map<String, int> reportsCountByCell = {};
    for (var r in reports) {
      reportsCountByCell[r.cellId] = (reportsCountByCell[r.cellId] ?? 0) + 1;
    }

    // 2. Cria uma lista combinada para ordenar da que mais entrega para a que menos entrega
    final sortedCells = List<CellModel>.from(cells);
    sortedCells.sort((a, b) {
      final countA = reportsCountByCell[a.id] ?? 0;
      final countB = reportsCountByCell[b.id] ?? 0;
      return countB.compareTo(countA); // Ordem decrescente
    });

    // Pega o maior valor para calcular a proporção da barra de progresso
    int maxReports = 1;
    for (var cell in cells) {
      final count = reportsCountByCell[cell.id] ?? 0;
      if (count > maxReports) maxReports = count;
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
              'Relatórios por Célula',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ranking de entrega de relatórios entre as células cadastradas.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Lista de Células com Barras de Progresso Proporcionais
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedCells.length,
              itemBuilder: (context, index) {
                final cell = sortedCells[index];
                final count = reportsCountByCell[cell.id] ?? 0;
                final double progress = (count / maxReports).clamp(0.0, 1.0);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              cell.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$count ${count == 1 ? 'relatório' : 'relatórios'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            count > 0 ? Colors.purple.shade400 : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}