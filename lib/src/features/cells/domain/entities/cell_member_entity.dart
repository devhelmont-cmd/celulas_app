class CellMemberEntity {
  final String id;
  final String cellId;
  final String? userId;
  final String name;
  final String role;
  final DateTime joinedAt;
  final String? cellName;

  const CellMemberEntity({
    required this.id,
    required this.cellId,
    this.userId,
    required this.name,
    required this.role,
    required this.joinedAt,
    this.cellName,
  });
}