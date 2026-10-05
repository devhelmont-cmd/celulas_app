import 'package:celulas_app/src/features/cell_reports/data/models/cell_report_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

abstract class ICellReportsRemoteDataSource {
  Future<List<CellReportModel>> getReportsByCell(String cellId);

  Stream<List<CellReportModel>> watchReportsByCell(String cellId);

  Future<List<CellReportModel>> getAllReports({
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<void> saveReport(CellReportModel report);

  Future<void> justifyAbsence({
    required String reportId,
    required String cellMemberId,
    required String justification,
  });
}

class CellReportsRemoteDataSourceImpl implements ICellReportsRemoteDataSource {
  final FirebaseFirestore _firestore;

  CellReportsRemoteDataSourceImpl(this._firestore);

  // ================= RELATÓRIOS =================
  Future<List<CellReportModel>> getReportsByCell(String cellId) async {
    final snapshot =
        await _firestore
            .collection('reports')
            .where('cellId', isEqualTo: cellId)
            .orderBy('scheduledDate', descending: true)
            .get();

    return snapshot.docs
        .map((doc) => CellReportModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Stream<List<CellReportModel>> watchReportsByCell(String cellId) {
    return _firestore
        .collection('reports')
        .where('cellId', isEqualTo: cellId)
        .orderBy('scheduledDate', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => CellReportModel.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  Future<List<CellReportModel>> getAllReports({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query query = _firestore.collection('reports');

    if (startDate != null) {
      query = query.where(
        'scheduledDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'scheduledDate',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snapshot =
        await query.orderBy('scheduledDate', descending: true).get();
    return snapshot.docs
        .map(
          (doc) => CellReportModel.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  Future<void> saveReport(CellReportModel report) async {
    final docRef =
        report.id.isEmpty
            ? _firestore.collection('reports').doc()
            : _firestore.collection('reports').doc(report.id);

    await docRef.set(report.toMap());
  }

  Future<void> justifyAbsence({
    required String reportId,
    required String cellMemberId,
    required String justification,
  }) async {
    final docRef = _firestore.collection('reports').doc(reportId);

    // Usa uma Transaction para garantir consistência ao modificar um item dentro do Array
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Relatório não encontrado.');

      final data = snapshot.data()!;
      final report = CellReportModel.fromMap(data, snapshot.id);

      // Encontra e atualiza a presença específica do membro
      final updatedAttendances =
          report.attendances.map((attendance) {
            if (attendance.cellMemberId == cellMemberId) {
              return AttendanceModel(
                cellMemberId: attendance.cellMemberId,
                isPresent: attendance.isPresent,
                isJustified: true,
                justificationReason: justification,
                rolesPerformed: attendance.rolesPerformed,
              );
            }
            return attendance;
          }).toList();

      // Salva apenas o array de presenças atualizado no documento
      transaction.update(docRef, {
        'attendances':
            updatedAttendances
                .map((e) => (e as AttendanceModel).toMap())
                .toList(),
      });
    });
  }
}
