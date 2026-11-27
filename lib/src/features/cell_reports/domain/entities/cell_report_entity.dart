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
  final String justificationStatus; // 'none', 'acknowledged', 'justification_pending', 'justified_approved', 'justification_rejected', 'presence_claim_pending', 'presence_claimed_approved', 'presence_claim_rejected'
  final String? justifiedByUserId;
  final DateTime? justifiedAt;

  const AttendanceEntity({
    required this.cellMemberId,
    this.memberName,
    required this.isPresent,
    this.isJustified = false,
    this.justificationReason,
    this.rolesPerformed = const [],
    this.isExcused = false,
    this.justificationStatus = 'none',
    this.justifiedByUserId,
    this.justifiedAt,
  });

  bool get isJustificationApproved =>
      justificationStatus == 'justified_approved' ||
      justificationStatus == 'presence_claimed_approved' ||
      (isJustified &&
          justificationStatus != 'justification_rejected' &&
          justificationStatus != 'justification_pending' &&
          justificationStatus != 'presence_claim_pending' &&
          justificationStatus != 'acknowledged');

  bool get isJustificationPending =>
      justificationStatus == 'justification_pending';

  bool get isPresenceClaimPending =>
      justificationStatus == 'presence_claim_pending';

  bool get isPendingApproval =>
      justificationStatus == 'justification_pending' ||
      justificationStatus == 'presence_claim_pending';

  bool get isAcknowledged => justificationStatus == 'acknowledged';
}

class VisitorEntity {
  final String name;
  final String? phone;

  const VisitorEntity({required this.name, this.phone});
}