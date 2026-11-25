// lib/src/features/cells/domain/entities/cell_entity.dart

class CellEntity {
  final String id;
  final String name;
  final String? leaderId;
  final String? coLeaderId;
  final String? hostId;
  final String address;
  final String neighborhood;
  final String meetingDay;
  final String meetingTime;
  final String category;
  final bool isActive;
  final DateTime createdAt;
  final bool futureHostDefined;
  final int? customTargetMembers;
  final int? customTargetMonths;
  final double? customMinAttendancePercentage;
  final double? customMinVisitorAverage;
  final double? customMinReportRegularityPercentage;
  final String? customRequiredLeadershipRole;
  final bool? customRequireHost;

  const CellEntity({
    required this.id,
    required this.name,
    this.leaderId,
    this.coLeaderId,
    this.hostId,
    required this.address,
    required this.neighborhood,
    required this.meetingDay,
    required this.meetingTime,
    required this.category,
    this.isActive = true,
    required this.createdAt,
    this.futureHostDefined = false,
    this.customTargetMembers,
    this.customTargetMonths,
    this.customMinAttendancePercentage,
    this.customMinVisitorAverage,
    this.customMinReportRegularityPercentage,
    this.customRequiredLeadershipRole,
    this.customRequireHost,
  });
}
