import 'package:cloud_firestore/cloud_firestore.dart';

class PrayerRequestModel {
  final String id;
  final String cellId;
  final String? authorId;
  final String authorName;
  final String request;
  final DateTime createdAt;
  final bool isAnswered;

  PrayerRequestModel({
    required this.id,
    required this.cellId,
    this.authorId,
    required this.authorName,
    required this.request,
    required this.createdAt,
    this.isAnswered = false,
  });

  factory PrayerRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return PrayerRequestModel(
      id: id,
      cellId: map['cellId'] ?? '',
      authorId: map['authorId'],
      authorName: map['authorName'] ?? 'Anônimo',
      request: map['request'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAnswered: map['isAnswered'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cellId': cellId,
      'authorId': authorId,
      'authorName': authorName,
      'request': request,
      'createdAt': Timestamp.fromDate(createdAt),
      'isAnswered': isAnswered,
    };
  }
}