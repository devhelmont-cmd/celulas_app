// lib/src/features/cells/domain/entities/member_period_entity.dart
class MemberPeriodEntity {
  final String id;
  final String cellId;
  final String cellName;
  final DateTime startDate;
  final DateTime? endDate; // null se for a célula atual ativa
  final String role;

  const MemberPeriodEntity({
    required this.id,
    required this.cellId,
    required this.cellName,
    required this.startDate,
    this.endDate,
    required this.role,
  });

  bool get isActive => endDate == null;
}