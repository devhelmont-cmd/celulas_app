// lib/src/features/cells/data/models/cell_multiplication_progress_model.dart

import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'multiplication_settings_model.dart';

class CellMultiplicationProgressModel {
  final CellModel cell;
  final MultiplicationSettingsModel settings;

  // Contadores Atuais e Metas Efetivas (com overrides)
  final int currentMembersCount;
  final int effectiveTargetMembers;
  final int effectiveTargetMonths;
  final double effectiveMinAttendance;
  final double effectiveMinVisitorAvg;
  final double effectiveMinReportRegularity;
  final String effectiveRequiredRole;
  final bool effectiveRequireHost;
  final bool effectiveCountExcusedAbsencesAsPresence;

  // Datas e prazos de multiplicação
  final DateTime effectiveStartDate;
  final DateTime targetEndDate;
  final bool isStartDateInFuture;
  final bool isCustomStartDateActive;

  final bool hasLeaderInTraining;
  final String? leaderInTrainingName;
  final bool hasCoLeader;
  final String? coLeaderName;
  final bool futureHostDefined;
  final double visitorAverage;
  final double attendancePercentage;
  final double reportRegularityPercentage;
  final int elapsedMonths;
  final int totalMeetingsHeld;

  // Status de cada Critério (Metas atingidas?)
  final bool isMembersTargetMet;
  final bool isLeadershipTargetMet;
  final bool isHostTargetMet;
  final bool isVisitorTargetMet;
  final bool isAttendanceTargetMet;
  final bool isReportTargetMet;
  final bool isTimeTargetMet;

  // Percentual Geral Calculado (0 a 100%)
  final double overallPercentage;
  final int totalCriteria;
  final int metCriteriaCount;

  CellMultiplicationProgressModel._({
    required this.cell,
    required this.settings,
    required this.currentMembersCount,
    required this.effectiveTargetMembers,
    required this.effectiveTargetMonths,
    required this.effectiveMinAttendance,
    required this.effectiveMinVisitorAvg,
    required this.effectiveMinReportRegularity,
    required this.effectiveRequiredRole,
    required this.effectiveRequireHost,
    required this.effectiveCountExcusedAbsencesAsPresence,
    required this.effectiveStartDate,
    required this.targetEndDate,
    required this.isStartDateInFuture,
    required this.isCustomStartDateActive,
    required this.hasLeaderInTraining,
    this.leaderInTrainingName,
    required this.hasCoLeader,
    this.coLeaderName,
    required this.futureHostDefined,
    required this.visitorAverage,
    required this.attendancePercentage,
    required this.reportRegularityPercentage,
    required this.elapsedMonths,
    required this.totalMeetingsHeld,
    required this.isMembersTargetMet,
    required this.isLeadershipTargetMet,
    required this.isHostTargetMet,
    required this.isVisitorTargetMet,
    required this.isAttendanceTargetMet,
    required this.isReportTargetMet,
    required this.isTimeTargetMet,
    required this.overallPercentage,
    required this.totalCriteria,
    required this.metCriteriaCount,
  });

  bool get isReadyForMultiplication => overallPercentage >= 100.0 || (metCriteriaCount == totalCriteria && totalCriteria > 0);

  factory CellMultiplicationProgressModel.calculate({
    required CellModel cell,
    required List<CellMemberEntity> members,
    required List<CellReportEntity> reports,
    required List<CellMeetingModel> meetings,
    required MultiplicationSettingsModel settings,
  }) {
    final now = DateTime.now();
    final useGlobal = cell.useGlobalGoals;

    // Metas Efetivas (Globais ou Individuais conforme cell.useGlobalGoals)
    final effectiveTargetMembers = useGlobal ? settings.targetMembers : (cell.customTargetMembers ?? settings.targetMembers);
    final effectiveTargetMonths = useGlobal ? settings.targetMonths : (cell.customTargetMonths ?? settings.targetMonths);
    final effectiveMinAttendance = useGlobal ? settings.minAttendancePercentage : (cell.customMinAttendancePercentage ?? settings.minAttendancePercentage);
    final effectiveMinVisitorAvg = useGlobal ? settings.minVisitorAverage : (cell.customMinVisitorAverage ?? settings.minVisitorAverage);
    final effectiveMinReportRegularity = useGlobal ? settings.minReportRegularityPercentage : (cell.customMinReportRegularityPercentage ?? settings.minReportRegularityPercentage);
    final effectiveRequiredRole = useGlobal ? settings.requiredLeadershipRole : (cell.customRequiredLeadershipRole ?? settings.requiredLeadershipRole);
    final effectiveRequireHost = useGlobal ? settings.requireHost : (cell.customRequireHost ?? settings.requireHost);
    final effectiveCountExcusedAbsencesAsPresence = useGlobal
        ? settings.countExcusedAbsencesAsPresence
        : (cell.customCountExcusedAbsencesAsPresence ?? settings.countExcusedAbsencesAsPresence);

    // Determinação da Data de Início Efetiva
    final isCustomStartDateActive = !useGlobal && cell.customMultiplicationStartDate != null;
    final effectiveStartDate = useGlobal
        ? (settings.multiplicationStartDate ?? cell.createdAt)
        : (cell.customMultiplicationStartDate ?? settings.multiplicationStartDate ?? cell.createdAt);

    // Data Limite (Meta final)
    final targetEndDate = DateTime(
      effectiveStartDate.year,
      effectiveStartDate.month + effectiveTargetMonths,
      effectiveStartDate.day,
    );

    // Tempo decorrido em meses a partir da data efetiva
    final isStartDateInFuture = now.isBefore(effectiveStartDate);
    int elapsedDays = 0;
    int elapsedMonths = 0;

    if (!isStartDateInFuture) {
      elapsedDays = now.difference(effectiveStartDate).inDays;
      elapsedMonths = (elapsedDays / 30.44).floor();
    }

    // Membros atuais
    final currentMembersCount = members.length;

    // Busca papéis entre os membros
    CellMemberEntity? ltMember;
    CellMemberEntity? coLeaderMember;

    for (var m in members) {
      final roleLower = m.role.toLowerCase().trim();
      if (roleLower == 'lider_treinamento' ||
          roleLower == 'líder em treinamento' ||
          roleLower == 'lider em treinamento' ||
          roleLower == 'lt') {
        ltMember = m;
      } else if (roleLower == 'colider' ||
          roleLower == 'co-líder' ||
          roleLower == 'colíder' ||
          roleLower == 'co-leader') {
        coLeaderMember = m;
      }
    }

    final hasLeaderInTraining = ltMember != null;
    final hasCoLeader = coLeaderMember != null;
    final futureHostDefined = cell.futureHostDefined;

    // Validação de liderança conforme configuração efetiva
    bool isLeadershipTargetMet = false;
    if (effectiveRequiredRole == 'lider_treinamento') {
      isLeadershipTargetMet = hasLeaderInTraining;
    } else if (effectiveRequiredRole == 'colider') {
      isLeadershipTargetMet = hasCoLeader;
    } else {
      // 'lider_treinamento_ou_colider'
      isLeadershipTargetMet = hasLeaderInTraining || hasCoLeader;
    }

    // Datas de início e fim da meta sem horário (apenas ano, mês e dia)
    final startDateOnly = DateTime(
      effectiveStartDate.year,
      effectiveStartDate.month,
      effectiveStartDate.day,
    );
    final endDateOnly = DateTime(
      targetEndDate.year,
      targetEndDate.month,
      targetEndDate.day,
    );

    // Processamento dos relatórios exclusivamente no período da meta
    // (Considera reuniões normais e eventos ponte realizados entre a data inicial e final da meta)
    final occurredReports = reports.where((r) {
      if (r.status == ReportStatus.cacelled) return false;
      final rDate = DateTime(
        r.scheduledDate.year,
        r.scheduledDate.month,
        r.scheduledDate.day,
      );
      return !rDate.isBefore(startDateOnly) && !rDate.isAfter(endDateOnly);
    }).toList();

    final totalMeetingsHeld = occurredReports.length;

    // Média de visitantes
    double visitorAverage = 0.0;
    if (occurredReports.isNotEmpty) {
      final totalVisitors = occurredReports.fold<int>(0, (sum, r) => sum + r.visitors.length);
      visitorAverage = totalVisitors / occurredReports.length;
    }

    // Assiduidade dos membros (% de chamadas com presença no período da meta)
    double attendancePercentage = 0.0;
    int totalAttendancesCount = 0;
    int presentCount = 0;

    for (var report in occurredReports) {
      for (var att in report.attendances) {
        if (!att.isExcused) {
          totalAttendancesCount++;
          // Exclusivamente para o cálculo de assiduidade na multiplicação de célula:
          // Faltas justificadas validadas contam como presença apenas se ativado pelo pastor
          final isPresentCounted = att.isPresent ||
              (effectiveCountExcusedAbsencesAsPresence && att.isJustificationApproved);
          if (isPresentCounted) presentCount++;
        }
      }
    }

    if (totalAttendancesCount > 0) {
      attendancePercentage = (presentCount / totalAttendancesCount) * 100.0;
    }

    // Todos os relatórios entregues referentes a reuniões agendadas no período da meta
    final allGoalPeriodReports = reports.where((r) {
      final rDate = DateTime(
        r.scheduledDate.year,
        r.scheduledDate.month,
        r.scheduledDate.day,
      );
      return !rDate.isBefore(startDateOnly) && !rDate.isAfter(endDateOnly);
    }).toList();

    // Regularidade rigorosa de relatórios baseada estritamente nas reuniões agendadas e relatórios entregues no período da meta:
    double reportRegularityPercentage = 0.0;
    if (allGoalPeriodReports.isNotEmpty) {
      if (meetings.isNotEmpty) {
        final today = DateTime(now.year, now.month, now.day);
        final pastGoalMeetings = meetings.where((m) {
          final meetingDay = DateTime(m.meetingDate.year, m.meetingDate.month, m.meetingDate.day);
          return !meetingDay.isBefore(startDateOnly) &&
              !meetingDay.isAfter(endDateOnly) &&
              (meetingDay.isBefore(today) || meetingDay.isAtSameMomentAs(today));
        }).toList();

        final expectedReports = pastGoalMeetings.length;
        if (expectedReports > 0) {
          reportRegularityPercentage = ((allGoalPeriodReports.length / expectedReports) * 100.0).clamp(0.0, 100.0);
        } else {
          reportRegularityPercentage = 100.0;
        }
      } else {
        reportRegularityPercentage = 100.0;
      }
    } else {
      reportRegularityPercentage = 0.0;
    }

    // Verificação de Metas
    final isMembersTargetMet = currentMembersCount >= effectiveTargetMembers;
    final isHostTargetMet = !effectiveRequireHost || futureHostDefined;
    final isVisitorTargetMet = visitorAverage >= effectiveMinVisitorAvg;
    final isAttendanceTargetMet = attendancePercentage >= effectiveMinAttendance;
    final isReportTargetMet = reportRegularityPercentage >= effectiveMinReportRegularity;
    final isTimeTargetMet = !isStartDateInFuture && elapsedMonths >= effectiveTargetMonths;

    // Cálculo do Percentual Ponderado / Pontuação de Critérios
    int totalCriteria = 6; // Membros, Liderança, Visitantes, Assiduidade, Relatórios, Tempo
    if (effectiveRequireHost) totalCriteria += 1;

    int metCriteriaCount = 0;
    if (isMembersTargetMet) metCriteriaCount++;
    if (isLeadershipTargetMet) metCriteriaCount++;
    if (isVisitorTargetMet) metCriteriaCount++;
    if (isAttendanceTargetMet) metCriteriaCount++;
    if (isReportTargetMet) metCriteriaCount++;
    if (isTimeTargetMet) metCriteriaCount++;
    if (effectiveRequireHost && isHostTargetMet) metCriteriaCount++;

    // Progresso contínuo em porcentagem (0% a 100%)
    double membersProg = (currentMembersCount / effectiveTargetMembers).clamp(0.0, 1.0);
    double leadershipProg = isLeadershipTargetMet ? 1.0 : 0.0;
    double hostProg = (!effectiveRequireHost || futureHostDefined) ? 1.0 : 0.0;
    double visitorProg = effectiveMinVisitorAvg > 0
        ? (visitorAverage / effectiveMinVisitorAvg).clamp(0.0, 1.0)
        : 1.0;
    double attendanceProg = effectiveMinAttendance > 0
        ? (attendancePercentage / effectiveMinAttendance).clamp(0.0, 1.0)
        : 1.0;
    double reportProg = effectiveMinReportRegularity > 0
        ? (reportRegularityPercentage / effectiveMinReportRegularity).clamp(0.0, 1.0)
        : 1.0;
    double timeProg = isStartDateInFuture
        ? 0.0
        : (effectiveTargetMonths > 0
            ? (elapsedMonths / effectiveTargetMonths).clamp(0.0, 1.0)
            : 1.0);

    double sumProg = membersProg + leadershipProg + visitorProg + attendanceProg + reportProg + timeProg;
    if (effectiveRequireHost) sumProg += hostProg;

    double overallPercentage = (sumProg / totalCriteria) * 100.0;

    return CellMultiplicationProgressModel._(
      cell: cell,
      settings: settings,
      currentMembersCount: currentMembersCount,
      effectiveTargetMembers: effectiveTargetMembers,
      effectiveTargetMonths: effectiveTargetMonths,
      effectiveMinAttendance: effectiveMinAttendance,
      effectiveMinVisitorAvg: effectiveMinVisitorAvg,
      effectiveMinReportRegularity: effectiveMinReportRegularity,
      effectiveRequiredRole: effectiveRequiredRole,
      effectiveRequireHost: effectiveRequireHost,
      effectiveCountExcusedAbsencesAsPresence: effectiveCountExcusedAbsencesAsPresence,
      effectiveStartDate: effectiveStartDate,
      targetEndDate: targetEndDate,
      isStartDateInFuture: isStartDateInFuture,
      isCustomStartDateActive: isCustomStartDateActive,
      hasLeaderInTraining: hasLeaderInTraining,
      leaderInTrainingName: ltMember?.name,
      hasCoLeader: hasCoLeader,
      coLeaderName: coLeaderMember?.name,
      futureHostDefined: futureHostDefined,
      visitorAverage: visitorAverage,
      attendancePercentage: attendancePercentage,
      reportRegularityPercentage: reportRegularityPercentage,
      elapsedMonths: elapsedMonths,
      totalMeetingsHeld: totalMeetingsHeld,
      isMembersTargetMet: isMembersTargetMet,
      isLeadershipTargetMet: isLeadershipTargetMet,
      isHostTargetMet: isHostTargetMet,
      isVisitorTargetMet: isVisitorTargetMet,
      isAttendanceTargetMet: isAttendanceTargetMet,
      isReportTargetMet: isReportTargetMet,
      isTimeTargetMet: isTimeTargetMet,
      overallPercentage: overallPercentage.clamp(0.0, 100.0),
      totalCriteria: totalCriteria,
      metCriteriaCount: metCriteriaCount,
    );
  }
}

