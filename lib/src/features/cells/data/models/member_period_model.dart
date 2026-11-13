// lib/src/features/cells/data/models/member_period_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/member_period_entity.dart';

class MemberPeriodModel extends MemberPeriodEntity {
  const MemberPeriodModel({
    required super.id,
    required super.cellId,
    required super.cellName,
    required super.startDate,
    super.endDate,
    required super.role,
  });

  factory MemberPeriodModel.fromMap(Map<String, dynamic> map, String id) {
    return MemberPeriodModel(
      id: id,
      cellId: map['cellId'] ?? '',
      cellName: map['cellName'] ?? '',
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      role: map['role'] ?? 'membro',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cellId': cellId,
      'cellName': cellName,
      'startDate': Timestamp.fromDate(startDate),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      'role': role,
    };
  }
}