import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestStatus { pending, approved, rejected }

class CellJoinRequestEntity {
  final String id;
  final String cellId;
  final String cellName;
  final String userId;
  final String userName;
  final String? userPhone;
  final RequestStatus status;
  final DateTime createdAt;

  const CellJoinRequestEntity({
    required this.id,
    required this.cellId,
    required this.cellName,
    required this.userId,
    required this.userName,
    this.userPhone,
    required this.status,
    required this.createdAt,
  });

  factory CellJoinRequestEntity.fromMap(Map<String, dynamic> map, String id) {
    return CellJoinRequestEntity(
      id: id,
      cellId: map['cellId'] ?? '',
      cellName: map['cellName'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhone: map['userPhone'],
      status: RequestStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RequestStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cellId': cellId,
      'cellName': cellName,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
