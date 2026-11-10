import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/cell_member_entity.dart';

class CellMemberModel extends CellMemberEntity {
  CellMemberModel({
    required super.id,
    required super.cellId,
    super.userId,
    required super.name,
    required super.role,
    required super.joinedAt,
    super.cellName,
    super.photoUrl,
  });

  factory CellMemberModel.fromMap(
      Map<String, dynamic> map,
      String id, {
        String? cellName,
      }) {
    return CellMemberModel(
      id: id,
      cellId: map['cellId'] ?? '',
      userId: map['userId'],
      name: map['name'] ?? '',
      role: map['role'] ?? 'membro',
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      cellName: cellName ?? map['cellName'],
      photoUrl: map['photoUrl'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'cellId': cellId,
      'userId': userId,
      'name': name,
      'role': role,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'photoUrl': photoUrl,
    };
  }

  factory CellMemberModel.fromEntity(CellMemberEntity entity) {
    return CellMemberModel(
      id: entity.id,
      cellId: entity.cellId,
      userId: entity.userId,
      name: entity.name,
      role: entity.role,
      joinedAt: entity.joinedAt,
      cellName: entity.cellName,
      photoUrl: entity.photoUrl,
    );
  }
}