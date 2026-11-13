// lib/src/features/cell_reports/data/datasources/cell_reports_remote_datasource.dart
import 'package:celulas_app/src/features/cell_reports/data/models/cell_report_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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

  Future<void> deleteReportByCellAndDate({
    required String cellId,
    required DateTime date,
  });
}

class CellReportsRemoteDataSourceImpl implements ICellReportsRemoteDataSource {
  final FirebaseFirestore _firestore;

  CellReportsRemoteDataSourceImpl(this._firestore);

  // ================= RELATÓRIOS =================
  @override
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

  @override
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

  @override
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

  @override
  Future<void> saveReport(CellReportModel report) async {
    final docRef =
    report.id.isEmpty
        ? _firestore.collection('reports').doc()
        : _firestore.collection('reports').doc(report.id);

    await docRef.set(report.toMap());

    // Ajusta automaticamente os períodos dos membros presentes conforme a data da reunião
    for (var att in report.attendances) {
      if (att.isPresent && att.cellMemberId.isNotEmpty) {
        try {
          await _adjustMemberPeriodForReport(
            _firestore,
            att.cellMemberId,
            report.cellId,
            report.scheduledDate,
          );
        } catch (e) {
          debugPrint('Erro ao ajustar período do membro ${att.cellMemberId}: $e');
        }
      }
    }
  }

  /// Lógica para ajustar os períodos do membro quando um relatório passado/manual é salvo
  Future<void> _adjustMemberPeriodForReport(
      FirebaseFirestore firestore,
      String memberId,
      String cellId,
      DateTime reportDate,
      ) async {
    final targetDate = DateTime(reportDate.year, reportDate.month, reportDate.day);

    // Busca o nome da célula atual do relatório
    String cellName = 'Célula';
    try {
      final cellDoc = await firestore.collection('cells').doc(cellId).get();
      if (cellDoc.exists) {
        cellName = cellDoc.data()?['name'] ?? 'Célula';
      }
    } catch (_) {}

    final periodsRef = firestore.collection('members').doc(memberId).collection('periods');
    final periodsSnap = await periodsRef.orderBy('startDate').get();

    List<Map<String, dynamic>> periods = periodsSnap.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'cellId': data['cellId'] as String? ?? '',
        'cellName': data['cellName'] as String? ?? '',
        'startDate': (data['startDate'] as Timestamp).toDate(),
        'endDate': (data['endDate'] as Timestamp?)?.toDate(),
        'role': data['role'] as String? ?? 'membro',
      };
    }).toList();

    // 1. Se não houver nenhum período cadastrado, cria o primeiro período a partir desta data
    if (periods.isEmpty) {
      await periodsRef.add({
        'cellId': cellId,
        'cellName': cellName,
        'startDate': Timestamp.fromDate(targetDate),
        'endDate': null, // Período ativo/atual
        'role': 'membro',
      });
      return;
    }

    // 2. Verifica se a data já está coberta por algum período existente
    bool isCovered = false;
    for (var p in periods) {
      final start = DateTime(p['startDate'].year, p['startDate'].month, p['startDate'].day);
      final end = p['endDate'] != null
          ? DateTime(p['endDate'].year, p['endDate'].month, p['endDate'].day)
          : null;

      if (!targetDate.isBefore(start) && (end == null || !targetDate.isAfter(end))) {
        isCovered = true;
        break;
      }
    }

    if (isCovered) return; // Já está coberto, não precisa alterar

    periods.sort((a, b) => (a['startDate'] as DateTime).compareTo(b['startDate'] as DateTime));

    // 3. Se a data for anterior ao primeiro período registrado
    final firstPeriod = periods.first;
    final firstStart = DateTime(firstPeriod['startDate'].year, firstPeriod['startDate'].month, firstPeriod['startDate'].day);

    if (targetDate.isBefore(firstStart)) {
      if (firstPeriod['cellId'] == cellId) {
        // Mesma célula: apenas atualiza o start do período existente para a data mais antiga
        await periodsRef.doc(firstPeriod['id']).update({
          'startDate': Timestamp.fromDate(targetDate),
        });
      } else {
        // Célula diferente: insere um novo período antes
        final newEnd = firstStart.subtract(const Duration(days: 1));
        await periodsRef.add({
          'cellId': cellId,
          'cellName': cellName,
          'startDate': Timestamp.fromDate(targetDate),
          'endDate': Timestamp.fromDate(newEnd.isBefore(targetDate) ? targetDate : newEnd),
          'role': 'membro',
        });
      }
      return;
    }

    // 4. Se a data estiver entre dois períodos (lacuna)
    for (int i = 0; i < periods.length - 1; i++) {
      final current = periods[i];
      final next = periods[i + 1];

      final currentEnd = current['endDate'] != null
          ? DateTime(current['endDate'].year, current['endDate'].month, current['endDate'].day)
          : DateTime(current['startDate'].year, current['startDate'].month, current['startDate'].day);

      final nextStart = DateTime(next['startDate'].year, next['startDate'].month, next['startDate'].day);

      if (targetDate.isAfter(currentEnd) && targetDate.isBefore(nextStart)) {
        if (next['cellId'] == cellId) {
          // A célula do período posterior é a mesma: atualiza o start do período posterior
          await periodsRef.doc(next['id']).update({
            'startDate': Timestamp.fromDate(targetDate),
          });
        } else if (current['cellId'] == cellId) {
          // A célula do período anterior é a mesma: atualiza o end do período anterior
          await periodsRef.doc(current['id']).update({
            'endDate': Timestamp.fromDate(targetDate),
          });
        } else {
          // Células diferentes: cria um período no meio com start e end iguais à data
          await periodsRef.add({
            'cellId': cellId,
            'cellName': cellName,
            'startDate': Timestamp.fromDate(targetDate),
            'endDate': Timestamp.fromDate(targetDate),
            'role': 'membro',
          });
        }
        return;
      }
    }
  }

  @override
  Future<void> justifyAbsence({
    required String reportId,
    required String cellMemberId,
    required String justification,
  }) async {
    final docRef = _firestore.collection('reports').doc(reportId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Relatório não encontrado.');

      final data = snapshot.data()!;
      final report = CellReportModel.fromMap(data, snapshot.id);

      final updatedAttendances =
      report.attendances.map((attendance) {
        if (attendance.cellMemberId == cellMemberId) {
          return AttendanceModel(
            cellMemberId: attendance.cellMemberId,
            memberName: attendance.memberName,
            isPresent: attendance.isPresent,
            isJustified: true,
            justificationReason: justification,
            rolesPerformed: attendance.rolesPerformed,
            isExcused: attendance.isExcused,
          );
        }
        return attendance;
      }).toList();

      transaction.update(docRef, {
        'attendances':
        updatedAttendances
            .map((e) => (e as AttendanceModel).toMap())
            .toList(),
      });
    });
  }

  @override
  Future<void> deleteReportByCellAndDate({
    required String cellId,
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection('reports')
        .where('cellId', isEqualTo: cellId)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}