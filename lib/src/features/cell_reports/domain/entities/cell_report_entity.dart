// lib/src/features/cell_reports/domain/entities/cell_report_entity.dart
enum ReportStatus { occurred, cacelled, bridgeEvent }

class CellReportEntity {
  final String id;
  final String cellId;
  final DateTime scheduledDate;
  final DateTime? actualDate;
  final ReportStatus status;
  final String? eventType;
  final String? cancellationReason;
  final List<AttendanceEntity> attendances;
  final List<VisitorEntity> visitors;
  final List<VisitorEntity> conversions;
  final String? testimoniesAndNotes;
  final String filledByUserId;
  final DateTime createdAt;
  final String? cycleKey;

  const CellReportEntity({
    required this.id,
    required this.cellId,
    required this.scheduledDate,
    this.actualDate,
    required this.status,
    this.eventType,
    this.cancellationReason,
    required this.attendances,
    required this.visitors,
    required this.conversions,
    this.testimoniesAndNotes,
    required this.filledByUserId,
    required this.createdAt,
    this.cycleKey,
  });
}

class AttendanceEntity {
  final String cellMemberId;
  final String? memberName; // Snapshot histórico do nome na data do relatório
  final bool isPresent;
  final bool isJustified;
  final String? justificationReason;
  final List<String> rolesPerformed;
  final bool isExcused; // Campo para abono (reunião cancelada)

  const AttendanceEntity({
    required this.cellMemberId,
    this.memberName,
    required this.isPresent,
    this.isJustified = false,
    this.justificationReason,
    this.rolesPerformed = const [],
    this.isExcused = false,
  });
}

class VisitorEntity {
  final String name;
  final String? phone;

  const VisitorEntity({required this.name, this.phone});
}