// lib/src/features/cell_reports/presentation/widgets/cell_multiplication_ranking_chart_widget.dart

import 'package:flutter/material.dart';
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_multiplication_progress_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';

class CellMultiplicationRankingChartWidget extends StatefulWidget {
  final List<CellModel> cells;
  final List<CellReportEntity> allReports;
  final List<CellMeetingModel> allMeetings;
  final List<CellMemberEntity> allMembers;

  const CellMultiplicationRankingChartWidget({
    super.key,
    required this.cells,
    required this.allReports,
    required this.allMeetings,
    required this.allMembers,
  });

  @override
  State<CellMultiplicationRankingChartWidget> createState() =>
      _CellMultiplicationRankingChartWidgetState();
}

class _CellMultiplicationRankingChartWidgetState
    extends State<CellMultiplicationRankingChartWidget> {
  bool _isLoading = true;
  List<CellMultiplicationProgressModel> _progressList = [];

  @override
  void initState() {
    super.initState();
    _calculateProgress();
  }

  Future<void> _calculateProgress() async {
    try {
      final dataSource = getIt<ICellRemoteDataSource>();
      final settings = await dataSource.getMultiplicationSettings();

      List<CellMultiplicationProgressModel> list = [];

      for (var cell in widget.cells) {
        final cellMembers =
        widget.allMembers.where((m) => m.cellId == cell.id).toList();
        final cellReports =
        widget.allReports.where((r) => r.cellId == cell.id).toList();
        final cellMeetings =
        widget.allMeetings.where((m) => m.cellId == cell.id).toList();

        final progress = CellMultiplicationProgressModel.calculate(
          cell: cell,
          members: cellMembers,
          reports: cellReports.cast(),
          meetings: cellMeetings,
          settings: settings,
        );
        list.add(progress);
      }

      // Ordena por maior percentual de progresso (decrescente)
      list.sort((a, b) => b.overallPercentage.compareTo(a.overallPercentage));

      if (mounted) {
        setState(() {
          _progressList = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cells.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.diversity_3_outlined, color: Colors.indigo, size: 20),
                SizedBox(width: 8),
                Text(
                  'Ranking de Progresso de Multiplicação',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Acompanhamento consolidado do avanço das células rumo à multiplicação (independente do mês).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _progressList.length,
              itemBuilder: (context, index) {
                final progress = _progressList[index];
                final percentage =
                progress.overallPercentage.clamp(0.0, 100.0);
                final double value = (percentage / 100.0).clamp(0.0, 1.0);
                final metCount = progress.metCriteriaCount;
                final totalCriteria = progress.totalCriteria;

                Color barColor = Colors.indigo;
                if (percentage >= 100) {
                  barColor = Colors.green;
                } else if (percentage >= 70) {
                  barColor = Colors.blue;
                } else if (percentage >= 40) {
                  barColor = Colors.orange;
                } else {
                  barColor = Colors.redAccent;
                }

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
                              '${index + 1}. ${progress.cell.name}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: barColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${percentage.toStringAsFixed(0)}% ($metCount/$totalCriteria metas)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: barColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
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
