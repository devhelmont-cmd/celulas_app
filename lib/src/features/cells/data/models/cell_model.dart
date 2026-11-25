// lib/src/features/cells/data/models/cell_model.dart

import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CellModel extends CellEntity {
  CellModel({
    required super.id,
    required super.name,
    super.leaderId,
    super.coLeaderId,
    super.hostId,
    required super.address,
    required super.neighborhood,
    required super.meetingDay,
    required super.meetingTime,
    required super.category,
    super.isActive,
    required super.createdAt,
    super.futureHostDefined,
    super.customTargetMembers,
    super.customTargetMonths,
    super.customMinAttendancePercentage,
    super.customMinVisitorAverage,
    super.customMinReportRegularityPercentage,
    super.customRequiredLeadershipRole,
    super.customRequireHost,
    super.customMultiplicationStartDate,
  });

  factory CellModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedDate = DateTime.now();
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        parsedDate = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is String) {
        parsedDate = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
      }
    }

    DateTime? parsedCustomStartDate;
    if (map['customMultiplicationStartDate'] != null) {
      if (map['customMultiplicationStartDate'] is Timestamp) {
        parsedCustomStartDate =
            (map['customMultiplicationStartDate'] as Timestamp).toDate();
      } else if (map['customMultiplicationStartDate'] is String) {
        parsedCustomStartDate =
            DateTime.tryParse(map['customMultiplicationStartDate']);
      }
    }

    return CellModel(
      id: id,
      name: map['name']?.toString() ?? 'Sem nome',
      leaderId: map['leaderId']?.toString(),
      coLeaderId: map['coLeaderId']?.toString(),
      hostId: map['hostId']?.toString(),
      address: map['address']?.toString() ?? '',
      neighborhood: map['neighborhood']?.toString() ?? '',
      meetingDay: map['meetingDay']?.toString() ?? '',
      meetingTime: map['meetingTime']?.toString() ?? '',
      category: map['category']?.toString() ?? 'Geral',
      isActive: map['isActive'] == null
          ? true
          : (map['isActive'] == true || map['isActive'] == 'true'),
      createdAt: parsedDate,
      futureHostDefined: map['futureHostDefined'] == true || map['futureHostDefined'] == 'true',
      customTargetMembers: (map['customTargetMembers'] as num?)?.toInt(),
      customTargetMonths: (map['customTargetMonths'] as num?)?.toInt(),
      customMinAttendancePercentage: (map['customMinAttendancePercentage'] as num?)?.toDouble(),
      customMinVisitorAverage: (map['customMinVisitorAverage'] as num?)?.toDouble(),
      customMinReportRegularityPercentage: (map['customMinReportRegularityPercentage'] as num?)?.toDouble(),
      customRequiredLeadershipRole: map['customRequiredLeadershipRole']?.toString(),
      customRequireHost: map['customRequireHost'] as bool?,
      customMultiplicationStartDate: parsedCustomStartDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'leaderId': leaderId,
      'coLeaderId': coLeaderId,
      'hostId': hostId,
      'address': address,
      'neighborhood': neighborhood,
      'meetingDay': meetingDay,
      'meetingTime': meetingTime,
      'category': category,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'futureHostDefined': futureHostDefined,
      'customTargetMembers': customTargetMembers,
      'customTargetMonths': customTargetMonths,
      'customMinAttendancePercentage': customMinAttendancePercentage,
      'customMinVisitorAverage': customMinVisitorAverage,
      'customMinReportRegularityPercentage': customMinReportRegularityPercentage,
      'customRequiredLeadershipRole': customRequiredLeadershipRole,
      'customRequireHost': customRequireHost,
      'customMultiplicationStartDate': customMultiplicationStartDate != null
          ? Timestamp.fromDate(customMultiplicationStartDate!)
          : null,
    };
  }

  factory CellModel.fromEntity(CellEntity entity) {
    return CellModel(
      id: entity.id,
      name: entity.name,
      leaderId: entity.leaderId,
      coLeaderId: entity.coLeaderId,
      hostId: entity.hostId,
      address: entity.address,
      neighborhood: entity.neighborhood,
      meetingDay: entity.meetingDay,
      meetingTime: entity.meetingTime,
      category: entity.category,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      futureHostDefined: entity.futureHostDefined,
      customTargetMembers: entity.customTargetMembers,
      customTargetMonths: entity.customTargetMonths,
      customMinAttendancePercentage: entity.customMinAttendancePercentage,
      customMinVisitorAverage: entity.customMinVisitorAverage,
      customMinReportRegularityPercentage: entity.customMinReportRegularityPercentage,
      customRequiredLeadershipRole: entity.customRequiredLeadershipRole,
      customRequireHost: entity.customRequireHost,
      customMultiplicationStartDate: entity.customMultiplicationStartDate,
    );
  }

  CellModel copyWith({
    String? id,
    String? name,
    String? leaderId,
    String? coLeaderId,
    String? hostId,
    String? address,
    String? neighborhood,
    String? meetingDay,
    String? meetingTime,
    String? category,
    bool? isActive,
    DateTime? createdAt,
    bool? futureHostDefined,
    int? customTargetMembers,
    int? customTargetMonths,
    double? customMinAttendancePercentage,
    double? customMinVisitorAverage,
    double? customMinReportRegularityPercentage,
    String? customRequiredLeadershipRole,
    bool? customRequireHost,
    DateTime? customMultiplicationStartDate,
    bool clearCustomMultiplicationStartDate = false,
  }) {
    return CellModel(
      id: id ?? this.id,
      name: name ?? this.name,
      leaderId: leaderId ?? this.leaderId,
      coLeaderId: coLeaderId ?? this.coLeaderId,
      hostId: hostId ?? this.hostId,
      address: address ?? this.address,
      neighborhood: neighborhood ?? this.neighborhood,
      meetingDay: meetingDay ?? this.meetingDay,
      meetingTime: meetingTime ?? this.meetingTime,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      futureHostDefined: futureHostDefined ?? this.futureHostDefined,
      customTargetMembers: customTargetMembers ?? this.customTargetMembers,
      customTargetMonths: customTargetMonths ?? this.customTargetMonths,
      customMinAttendancePercentage:
          customMinAttendancePercentage ?? this.customMinAttendancePercentage,
      customMinVisitorAverage:
          customMinVisitorAverage ?? this.customMinVisitorAverage,
      customMinReportRegularityPercentage:
          customMinReportRegularityPercentage ??
              this.customMinReportRegularityPercentage,
      customRequiredLeadershipRole:
          customRequiredLeadershipRole ?? this.customRequiredLeadershipRole,
      customRequireHost: customRequireHost ?? this.customRequireHost,
      customMultiplicationStartDate: clearCustomMultiplicationStartDate
          ? null
          : (customMultiplicationStartDate ?? this.customMultiplicationStartDate),
    );
  }
}

