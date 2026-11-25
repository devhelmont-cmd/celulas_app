// lib/src/features/cells/data/models/multiplication_settings_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class MultiplicationSettingsModel {
  final int targetMonths;
  final int targetMembers;
  final double minAttendancePercentage;
  final double minVisitorAverage;
  final double minReportRegularityPercentage;
  final String requiredLeadershipRole; // 'lider_treinamento', 'colider', 'lider_treinamento_ou_colider'
  final bool requireHost;
  final DateTime? multiplicationStartDate;

  const MultiplicationSettingsModel({
    this.targetMonths = 6,
    this.targetMembers = 15,
    this.minAttendancePercentage = 80.0,
    this.minVisitorAverage = 3.0,
    this.minReportRegularityPercentage = 80.0,
    this.requiredLeadershipRole = 'lider_treinamento_ou_colider',
    this.requireHost = true,
    this.multiplicationStartDate,
  });

  factory MultiplicationSettingsModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MultiplicationSettingsModel();

    DateTime? parsedStartDate;
    if (map['multiplicationStartDate'] != null) {
      if (map['multiplicationStartDate'] is Timestamp) {
        parsedStartDate = (map['multiplicationStartDate'] as Timestamp).toDate();
      } else if (map['multiplicationStartDate'] is String) {
        parsedStartDate = DateTime.tryParse(map['multiplicationStartDate']);
      }
    }

    return MultiplicationSettingsModel(
      targetMonths: (map['targetMonths'] as num?)?.toInt() ?? 6,
      targetMembers: (map['targetMembers'] as num?)?.toInt() ?? 15,
      minAttendancePercentage:
          (map['minAttendancePercentage'] as num?)?.toDouble() ?? 80.0,
      minVisitorAverage:
          (map['minVisitorAverage'] as num?)?.toDouble() ?? 3.0,
      minReportRegularityPercentage:
          (map['minReportRegularityPercentage'] as num?)?.toDouble() ?? 80.0,
      requiredLeadershipRole:
          (map['requiredLeadershipRole'] as String?) ?? 'lider_treinamento_ou_colider',
      requireHost: (map['requireHost'] as bool?) ?? true,
      multiplicationStartDate: parsedStartDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetMonths': targetMonths,
      'targetMembers': targetMembers,
      'minAttendancePercentage': minAttendancePercentage,
      'minVisitorAverage': minVisitorAverage,
      'minReportRegularityPercentage': minReportRegularityPercentage,
      'requiredLeadershipRole': requiredLeadershipRole,
      'requireHost': requireHost,
      'multiplicationStartDate': multiplicationStartDate != null
          ? Timestamp.fromDate(multiplicationStartDate!)
          : null,
    };
  }

  MultiplicationSettingsModel copyWith({
    int? targetMonths,
    int? targetMembers,
    double? minAttendancePercentage,
    double? minVisitorAverage,
    double? minReportRegularityPercentage,
    String? requiredLeadershipRole,
    bool? requireHost,
    DateTime? multiplicationStartDate,
    bool clearMultiplicationStartDate = false,
  }) {
    return MultiplicationSettingsModel(
      targetMonths: targetMonths ?? this.targetMonths,
      targetMembers: targetMembers ?? this.targetMembers,
      minAttendancePercentage:
          minAttendancePercentage ?? this.minAttendancePercentage,
      minVisitorAverage: minVisitorAverage ?? this.minVisitorAverage,
      minReportRegularityPercentage:
          minReportRegularityPercentage ?? this.minReportRegularityPercentage,
      requiredLeadershipRole:
          requiredLeadershipRole ?? this.requiredLeadershipRole,
      requireHost: requireHost ?? this.requireHost,
      multiplicationStartDate: clearMultiplicationStartDate
          ? null
          : (multiplicationStartDate ?? this.multiplicationStartDate),
    );
  }
}

