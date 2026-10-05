import 'package:celulas_app/src/features/cell_reports/data/datasources/cell_reports_remote_datasource.dart';
import 'package:celulas_app/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart';

import '../../domain/entities/cell_report_entity.dart';
import '../models/cell_report_model.dart';

class CellReportsRepositoryImpl implements ICellReportsRepository {
  final ICellReportsRemoteDataSource _dataSource;

  CellReportsRepositoryImpl(this._dataSource);

  Future<List<CellReportEntity>> getReportsByCell(String cellId) async {
    return await _dataSource.getReportsByCell(cellId);
  }

  Stream<List<CellReportEntity>> watchReportsByCell(String cellId) {
    return _dataSource.watchReportsByCell(cellId);
  }

  Future<List<CellReportEntity>> getAllReports({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _dataSource.getAllReports(
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> saveReport(CellReportEntity report) async {
    // Verifica se já é modelo, senão cria através de um map (workaround para heranças complexas)
    final model =
        report is CellReportModel
            ? report
            : CellReportModel(
              id: report.id,
              cellId: report.cellId,
              scheduledDate: report.scheduledDate,
              actualDate: report.actualDate,
              status: report.status,
              eventType: report.eventType,
              cancellationReason: report.cancellationReason,
              attendances: report.attendances, // Será convertido via toMap/fromMap na DataSource se necessário
              visitors: report.visitors,
              conversions: report.conversions,
              testimoniesAndNotes: report.testimoniesAndNotes,
              filledByUserId: report.filledByUserId,
              createdAt: report.createdAt,
            );

    await _dataSource.saveReport(model);
  }

  Future<void> justifyAbsence({
    required String reportId,
    required String cellMemberId,
    required String justification,
  }) async {
    await _dataSource.justifyAbsence(
      reportId: reportId,
      cellMemberId: cellMemberId,
      justification: justification,
    );
  }
}
