import 'package:cloud_firestore/cloud_firestore.dart';

class CellMeetingModel {
  final String id;
  final String cellId;
  final DateTime meetingDate;
  final String status; // 'normal', 'bridge_event', 'canceled', 'rescheduled'
  final String? statusNote;
  final String? newMeetingDate;
  final String? newMeetingTime;
  final bool isReportFilled;

  // Funções da reunião
  final String? initialPrayerName;
  final String? icebreakerName;
  final String? worshipName;
  final String? wordName;
  final String? finalPrayerName;
  final String? snackName;
  final String? officialPhotoName;
  final String? reportFillerName;

  CellMeetingModel({
    required this.id,
    required this.cellId,
    required this.meetingDate,
    this.status = 'normal',
    this.statusNote,
    this.newMeetingDate,
    this.newMeetingTime,
    this.isReportFilled = false,
    this.initialPrayerName,
    this.icebreakerName,
    this.worshipName,
    this.wordName,
    this.finalPrayerName,
    this.snackName,
    this.officialPhotoName,
    this.reportFillerName,
  });

  factory CellMeetingModel.fromMap(Map<String, dynamic> map, String id) {
    return CellMeetingModel(
      id: id,
      cellId: map['cellId'] ?? '',
      meetingDate: (map['meetingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'normal',
      statusNote: map['statusNote'],
      newMeetingDate: map['newMeetingDate'],
      newMeetingTime: map['newMeetingTime'],
      isReportFilled: map['isReportFilled'] ?? false,
      initialPrayerName: map['initialPrayerName'],
      icebreakerName: map['icebreakerName'],
      worshipName: map['worshipName'],
      wordName: map['wordName'],
      finalPrayerName: map['finalPrayerName'],
      snackName: map['snackName'],
      officialPhotoName: map['officialPhotoName'],
      reportFillerName: map['reportFillerName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cellId': cellId,
      'meetingDate': Timestamp.fromDate(meetingDate),
      'status': status,
      'statusNote': statusNote,
      'newMeetingDate': newMeetingDate,
      'newMeetingTime': newMeetingTime,
      'isReportFilled': isReportFilled,
      'initialPrayerName': initialPrayerName,
      'icebreakerName': icebreakerName,
      'worshipName': worshipName,
      'wordName': wordName,
      'finalPrayerName': finalPrayerName,
      'snackName': snackName,
      'officialPhotoName': officialPhotoName,
      'reportFillerName': reportFillerName,
    };
  }
}