// lib/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';

abstract class ICellReportsRepository {
  // ================= RELATÓRIOS =================
  /// Retorna relatórios para a célula (visão do líder/membros)
  Future<List<CellReportEntity>> getReportsByCell(String cellId);

  Stream<List<CellReportEntity>> watchReportsByCell(String cellId);

  /// Retorna relatórios globais (visão Dashboard do Pastor)
  /// Pode passar filtros de data (startDate, endDate)
  Future<List<CellReportEntity>> getAllReports({
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Salva ou atualiza um relatório semanal / evento ponte
  Future<void> saveReport(CellReportEntity report);

  /// Permite ao membro justificar uma falta posteriormente
  Future<void> justifyAbsence({
    required String reportId,
    required String cellMemberId,
    required String justification,
  });

  /// Exclui o relatório da coleção com base na célula e na data agendada
  Future<void> deleteReportByCellAndDate({
    required String cellId,
    required DateTime date,
  });
}