class CellMemberEntity {
  final String id;
  final String cellId;
  final String? userId;
  final String name;
  final String role;
  final DateTime joinedAt;

  const CellMemberEntity({
    required this.id,
    required this.cellId,
    this.userId,
    required this.name,
    required this.role,
    required this.joinedAt,
  });
}
