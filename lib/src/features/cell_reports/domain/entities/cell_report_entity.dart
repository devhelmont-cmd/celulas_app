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
  });
}

class AttendanceEntity {
  final String cellMemberId;
  final bool isPresent;
  final bool isJustified;
  final String? justificationReason;
  final List<String> rolesPerformed;

  const AttendanceEntity({
    required this.cellMemberId,
    required this.isPresent,
    this.isJustified = false,
    this.justificationReason,
    this.rolesPerformed = const [],
  });
}

class VisitorEntity {
  final String name;
  final String? phone;

  const VisitorEntity({required this.name, this.phone});
}
