import 'package:cloud_firestore/cloud_firestore.dart';

class CellMeetingModel {
  final String id;
  final String cellId;
  final DateTime meetingDate;
  final String status; // 'normal', 'bridge_event', 'canceled', 'rescheduled'
  final String? statusNote; // Justificativa de cancelamento ou notas
  final String? eventName; // Título do Evento Ponte
  final String? meetingTime; // Horário no formato HH:mm
  final String? meetingLocation; // Local personalizado da reunião/evento
  final bool isReportFilled;

  final String? cycleKey;

  // Funções da reunião
  final String? initialPrayerName;
  final String? icebreakerName;
  final String? worshipName;
  final String? wordName;
  final String? finalPrayerName;
  final String? snackName;
  final String? officialPhotoName;
  final String? reportFillerName;

  final bool deletionRequested;
  final String? deletionReason;
  final String? deletionType; // 'only_report' ou 'entire_meeting'

  CellMeetingModel({
    required this.id,
    required this.cellId,
    required this.meetingDate,
    this.status = 'normal',
    this.statusNote,
    this.eventName,
    this.meetingTime,
    this.meetingLocation,
    this.isReportFilled = false,
    this.cycleKey,
    this.initialPrayerName,
    this.icebreakerName,
    this.worshipName,
    this.wordName,
    this.finalPrayerName,
    this.snackName,
    this.officialPhotoName,
    this.reportFillerName,
    this.deletionRequested = false,
    this.deletionReason,
    this.deletionType,
  });

  /// Verifica se esta reunião já aconteceu e expirou (passou o dia da ocorrência)
  bool get isExpired {
    DateTime targetDate = meetingDate;
    final expiry = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day + 1,
    );
    return DateTime.now().isAfter(expiry);
  }

  factory CellMeetingModel.fromMap(Map<String, dynamic> map, String id) {
    return CellMeetingModel(
      id: id,
      cellId: map['cellId'] ?? '',
      meetingDate:
          (map['meetingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'normal',
      statusNote: map['statusNote'],
      eventName: map['eventName'],
      meetingTime: map['meetingTime'],
      meetingLocation: map['meetingLocation'],
      isReportFilled: map['isReportFilled'] ?? false,
      cycleKey: map['cycleKey'],
      initialPrayerName: map['initialPrayerName'],
      icebreakerName: map['icebreakerName'],
      worshipName: map['worshipName'],
      wordName: map['wordName'],
      finalPrayerName: map['finalPrayerName'],
      snackName: map['snackName'],
      officialPhotoName: map['officialPhotoName'],
      reportFillerName: map['reportFillerName'],
      deletionRequested: map['deletionRequested'] ?? false,
      deletionReason: map['deletionReason'],
      deletionType: map['deletionType'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cellId': cellId,
      'meetingDate': Timestamp.fromDate(meetingDate),
      'status': status,
      'statusNote': statusNote,
      'eventName': eventName,
      'meetingTime': meetingTime,
      'meetingLocation': meetingLocation,
      'isReportFilled': isReportFilled,
      if (cycleKey != null) 'cycleKey': cycleKey,
      'initialPrayerName': initialPrayerName,
      'icebreakerName': icebreakerName,
      'worshipName': worshipName,
      'wordName': wordName,
      'finalPrayerName': finalPrayerName,
      'snackName': snackName,
      'officialPhotoName': officialPhotoName,
      'reportFillerName': reportFillerName,
      'deletionRequested': deletionRequested,
      if (deletionReason != null) 'deletionReason': deletionReason,
      if (deletionType != null) 'deletionType': deletionType,
    };
  }
}
