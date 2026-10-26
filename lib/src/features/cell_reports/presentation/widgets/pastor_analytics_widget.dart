// lib/src/features/cell_reports/presentation/widgets/pastor_analytics_widget.dart
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/widgets/cell_attendance_chart_widget.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/widgets/cells_performance_chart_widget.dart';
import 'package:flutter/material.dart';

class PastorAnalyticsWidget extends StatefulWidget {
  const PastorAnalyticsWidget({super.key});

  @override
  State<PastorAnalyticsWidget> createState() => _PastorAnalyticsWidgetState();
}

class _PastorAnalyticsWidgetState extends State<PastorAnalyticsWidget> {
  late final ICellReportsRepository _reportsRepository;
  late final ICellRemoteDataSource _cellDataSource;

  bool _isLoading = true;
  List<CellReportEntity> _allReports = [];
  List<CellModel> _cells = [];

  @override
  void initState() {
    super.initState();
    _reportsRepository = getIt<ICellReportsRepository>();
    _cellDataSource = getIt<ICellRemoteDataSource>();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _reportsRepository.getAllReports();
      final cells = await _cellDataSource.getCells();
      if (mounted) {
        setState(() {
          _allReports = reports;
          _cells = cells;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Erro ao carregar dados analíticos para o pastor: $e');
    }
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

    int totalReports = _allReports.length;
    int totalVisitors = _allReports.fold(0, (sum, r) => sum + r.visitors.length);
    int totalConversions = _allReports.fold(0, (sum, r) => sum + r.conversions.length);

    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Análise Geral de Crescimento',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Acompanhe o desempenho consolidado de todas as células.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Cards de Resumo Rápido
          Row(
            children: [
              _buildSummaryCard('Relatórios', '$totalReports', Icons.description, Colors.purple),
              const SizedBox(width: 12),
              _buildSummaryCard('Visitantes', '$totalVisitors', Icons.person_add, Colors.orange),
              const SizedBox(width: 12),
              _buildSummaryCard('Conversões', '$totalConversions', Icons.volunteer_activism, Colors.green),
            ],
          ),
          const SizedBox(height: 24),

          // 1º Gráfico: Evolução Geral Temporal
          CellAttendanceChartWidget(reports: _allReports),
          const SizedBox(height: 24),

          // 2º Gráfico: Comparativo de Relatórios por Célula
          CellsPerformanceChartWidget(reports: _allReports, cells: _cells),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
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