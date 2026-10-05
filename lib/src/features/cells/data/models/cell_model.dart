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
  });

  factory CellModel.fromMap(Map<String, dynamic> map, String id) {
    // Blindagem para a data de criação:
    DateTime parsedDate = DateTime.now();
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        parsedDate = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is String) {
        parsedDate = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
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
      // Aceita true booleano ou a string 'true' de bancos antigos
      isActive: map['isActive'] == true || map['isActive'] == 'true',
      createdAt: parsedDate,
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
    );
  }
}
