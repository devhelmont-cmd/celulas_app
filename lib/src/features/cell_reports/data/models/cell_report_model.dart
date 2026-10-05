import 'dart:math';

import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VisitorModel extends VisitorEntity {
  const VisitorModel({required super.name, super.phone});

  factory VisitorModel.fromMap(Map<String, dynamic> map) {
    return VisitorModel(name: map['name'] ?? '', phone: map['phone']);
  }

  Map<String, dynamic> toMap() {
    return {'name': name, if (phone != null) 'phone': phone};
  }
}

class AttendanceModel extends AttendanceEntity {
  AttendanceModel({
    required super.cellMemberId,
    required super.isPresent,
    super.isJustified,
    super.justificationReason,
    super.rolesPerformed,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      cellMemberId: map['cellMemberId'] ?? '',
      isPresent: map['isPresent'] ?? false,
      isJustified: map['cellMemberId'] ?? false,
      justificationReason: map['justificationReason'],
      rolesPerformed: List<String>.from(map['rolesPerformed'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cellMemberId': cellMemberId,
      'isPresent': isPresent,
      'isJustified': isJustified,
      if (justificationReason != null)
        'justificationReason': justificationReason,
      'rolesPerformed': rolesPerformed,
    };
  }
}

class CellReportModel extends CellReportEntity {
  CellReportModel({
    required super.id,
    required super.cellId,
    required super.scheduledDate,
    super.actualDate,
    required super.status,
    super.eventType,
    super.cancellationReason,
    required super.attendances,
    required super.visitors,
    required super.conversions,
    super.testimoniesAndNotes,
    required super.filledByUserId,
    required super.createdAt,
  });

  factory CellReportModel.fromMap(Map<String, dynamic> map, String id) {
    return CellReportModel(
      id: id,
      cellId: map['cellId'] ?? '',
      scheduledDate: (map['scheduledDate'] as Timestamp).toDate(),
      actualDate: (map['actualDate'] as Timestamp?)?.toDate(),
      status: ReportStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReportStatus.occurred,
      ),
      eventType: map['eventType'],
      cancellationReason: map['cancellationReason'],
      attendances:
          (map['attendances'] as List<dynamic>?)
              ?.map((e) => AttendanceModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      visitors:
          (map['visitors'] as List<dynamic>?)
              ?.map((e) => VisitorModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      conversions:
          (map['conversions'] as List<dynamic>?)
              ?.map((e) => VisitorModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      testimoniesAndNotes: map['testimoniesAndNotes'],
      filledByUserId: map['filledByUserId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cellId': cellId,
      'scheduçedDate': Timestamp.fromDate(scheduledDate),
      if (actualDate != null) 'actualDate': Timestamp.fromDate(actualDate!),
      'status': status.name,
      if (eventType != null) 'eventType': eventType,
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      'attendances':
          attendances.map((e) => (e as AttendanceModel).toMap()).toList(),
      'visitors': visitors.map((e) => (e as VisitorModel).toMap()).toList(),
      'conversions':
          conversions.map((e) => (e as VisitorModel).toMap()).toList(),
      if (testimoniesAndNotes != null)
        'testimoniesAndNotes': testimoniesAndNotes,
      'filledByUserId': filledByUserId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
