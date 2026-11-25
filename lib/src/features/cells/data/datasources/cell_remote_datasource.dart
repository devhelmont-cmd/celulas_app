// lib/src/features/cells/data/datasources/cell_remote_datasource.dart
import 'package:celulas_app/src/core/utils/gender_helper.dart';
import 'package:celulas_app/src/core/utils/pastoral_cycle_helper.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_join_request_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_member_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/cells/data/models/member_period_model.dart';
import 'package:celulas_app/src/features/cells/data/models/multiplication_settings_model.dart';
import 'package:celulas_app/src/features/cells/data/models/prayer_request_model.dart';
import 'package:celulas_app/src/features/cells/data/models/unlinked_user_or_member_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

abstract class ICellRemoteDataSource {
  Future<List<CellModel>> getCells({
    String? filterByUserId,
    UserEntity? currentUser,
  });

  Stream<List<CellModel>> watchCells({
    String? filterByUserId,
    UserEntity? currentUser,
  });

  Stream<List<PrayerRequestModel>> watchPrayerRequests(String cellId);

  Stream<CellMeetingModel?> watchLatestMeeting(String cellId);

  Future<CellModel> getCellById(String id);

  Future<void> createCell(CellModel cell);

  Future<void> updateCell(CellModel cell);

  Future<void> deleteCell(String cellId);

  Future<void> toggleCellStatus(String cellId, bool isActive);

  Future<List<CellMemberEntity>> getCellMembers(String cellId);

  Future<List<CellMemberEntity>> getCellMembersForDate(String cellId, DateTime meetingDate);

  Stream<List<CellMemberEntity>> watchCellMembers(String cellId);

  // Períodos do Membro
  Future<List<MemberPeriodModel>> getMemberPeriods(String memberId);

  Future<void> saveMemberPeriod({
    required String memberId,
    required MemberPeriodModel period,
    required bool isPastorOrCoordinator,
  });

  Future<void> deleteMemberPeriod({
    required String memberId,
    required String periodId,
    required bool isPastorOrCoordinator,
  });

  Future<String?> getUserNameById(String userId, {String? cellId});

  Future<List<Map<String, dynamic>>> getAllMembers();

  Future<void> addCellMember(CellMemberModel member);

  Future<void> updateCellMember(CellMemberModel member);

  Future<void> removeCellMember(String memberId, String cellId);

  Future<void> linkMemberToUserAccount({
    required String cellId,
    required String memberId,
    required String newUserId,
  });

  Future<List<CellMemberModel>> getUnlinkedMembers();

  Future<List<UnlinkedUserOrMember>> getUsersAndMembersWithoutCell();

  Future<void> addExistingUserOrMemberToCell({
    required String cellId,
    required UnlinkedUserOrMember item,
    required String role,
    String? matchedMemberId,
    bool setAsLeader = false,
  });

  Future<void> requestCellJoin(CellJoinRequestEntity request);

  Future<List<CellJoinRequestEntity>> getPendingRequestsByLeader(
      String leaderId,
      );

  Future<List<CellJoinRequestEntity>> getPendingRequestsForCell(String cellId);

  Future<CellJoinRequestEntity?> getUserPendingRequest(String userId);

  Future<void> approveJoinRequest({
    required String requestId,
    required String cellId,
    required String userId,
    String? matchedMemberId,
    required String memberName,
    required bool setAsLeader,
  });

  Future<void> rejectJoinRequest(String requestId);

  Future<void> cancelCellJoinRequest(String requestId);

  Future<void> changeMemberRole({
    required String cellId,
    required String memberId,
    required String userId,
    required String newRole,
  });

  Future<void> transferMember({
    required String currentCellId,
    required String newCellId,
    required String memberId,
    required String userId,
    required String memberName,
  });

  // Reuniões & Relatórios
  Future<CellMeetingModel?> getLatestMeeting(String cellId);

  Future<List<CellMeetingModel>> getAllMeetingsForCell(String cellId);

  Future<List<CellMeetingModel>> getPendingMeetingsForCell(String cellId);

  Future<void> saveOrUpdateMeeting(CellMeetingModel meeting);

  Future<void> requestReportDeletion(
      String cellId,
      String meetingId,
      String reason,
      String deletionType,
      );

  Future<void> deleteOnlyReport(
      String cellId,
      String meetingId,
      DateTime meetingDate,
      );

  Future<void> deleteMeetingAndReport(
      String cellId,
      String meetingId,
      DateTime meetingDate,
      );

  // Pedidos de Oração
  Future<List<PrayerRequestModel>> getPrayerRequests(String cellId);

  Future<void> addPrayerRequest(PrayerRequestModel request);

  Future<void> deletePrayerRequest(String cellId, String requestId);

  Future<void> updatePrayerRequest(PrayerRequestModel request);

  Future<void> deleteMemberCompletely(String memberId);

  // Configurações de Multiplicação
  Future<MultiplicationSettingsModel> getMultiplicationSettings();

  Future<void> saveMultiplicationSettings(MultiplicationSettingsModel settings);
}

class CellRemoteDataSourceImpl implements ICellRemoteDataSource {
  final FirebaseFirestore _firestore;

  CellRemoteDataSourceImpl(this._firestore);

  @override
  Future<List<CellModel>> getCells({
    String? filterByUserId,
    UserEntity? currentUser,
  }) async {
    Query query = _firestore.collection('cells');

    final bool isPastorOrCoord = currentUser?.isPastorOrCoordinator ?? false;
    if (!isPastorOrCoord) {
      query = query.where('isActive', isEqualTo: true);
    }

    if (filterByUserId != null) {
      query = query.where('leaderId', isEqualTo: filterByUserId);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map(
          (doc) =>
          CellModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
    )
        .toList();
  }

  @override
  Stream<List<CellModel>> watchCells({
    String? filterByUserId,
    UserEntity? currentUser,
  }) {
    Query query = _firestore.collection('cells');

    final bool isPastorOrCoord = currentUser?.isPastorOrCoordinator ?? false;
    if (!isPastorOrCoord) {
      query = query.where('isActive', isEqualTo: true);
    }

    if (filterByUserId != null) {
      query = query.where('leaderId', isEqualTo: filterByUserId);
    }

    return query.snapshots().map(
          (snapshot) =>
          snapshot.docs
              .map(
                (doc) => CellModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
              .toList(),
    );
  }

  @override
  Stream<CellMeetingModel?> watchLatestMeeting(String cellId) {
    return _firestore
        .collection('cells')
        .doc(cellId)
        .collection('meetings')
        .orderBy('meetingDate', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return CellMeetingModel.fromMap(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );
    });
  }

  // ================= PERÍODOS DE CÉLULAS =================
  @override
  Future<List<MemberPeriodModel>> getMemberPeriods(String memberId) async {
    final snapshot = await _firestore
        .collection('members')
        .doc(memberId)
        .collection('periods')
        .orderBy('startDate')
        .get();

    return snapshot.docs
        .map((doc) => MemberPeriodModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> saveMemberPeriod({
    required String memberId,
    required MemberPeriodModel period,
    required bool isPastorOrCoordinator,
  }) async {
    if (!isPastorOrCoordinator) {
      throw Exception('Apenas pastores ou coordenadores podem gerenciar os períodos de um membro.');
    }

    final periodsRef = _firestore.collection('members').doc(memberId).collection('periods');
    final existingSnap = await periodsRef.orderBy('startDate').get();

    List<MemberPeriodModel> existingPeriods = existingSnap.docs
        .map((doc) => MemberPeriodModel.fromMap(doc.data(), doc.id))
        .where((p) => p.id != period.id)
        .toList();

    final newStart = DateTime(period.startDate.year, period.startDate.month, period.startDate.day);
    final newEnd = period.endDate != null
        ? DateTime(period.endDate!.year, period.endDate!.month, period.endDate!.day)
        : null;

    if (newEnd != null && newEnd.isBefore(newStart)) {
      throw Exception('A data de término não pode ser anterior à data de início.');
    }

    List<String> conflicts = [];
    for (var p in existingPeriods) {
      final pStart = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
      final pEnd = p.endDate != null
          ? DateTime(p.endDate!.year, p.endDate!.month, p.endDate!.day)
          : DateTime(2100, 12, 31);

      final effectiveNewEnd = newEnd ?? DateTime(2100, 12, 31);

      final latestStart = newStart.isAfter(pStart) ? newStart : pStart;
      final earliestEnd = effectiveNewEnd.isBefore(pEnd) ? effectiveNewEnd : pEnd;

      if (!latestStart.isAfter(earliestEnd)) {
        conflicts.add('• ${p.cellName} (${DateFormat('dd/MM/yyyy').format(p.startDate)} até ${p.endDate != null ? DateFormat('dd/MM/yyyy').format(p.endDate!) : 'Atual'})');
      }
    }

    if (conflicts.isNotEmpty) {
      throw Exception('O intervalo informado conflita com os seguintes períodos já cadastrados:\n${conflicts.join('\n')}\nPor favor, ajuste ou exclua os períodos conflitantes antes de continuar.');
    }

    existingPeriods.sort((a, b) => a.startDate.compareTo(b.startDate));
    if (existingPeriods.isNotEmpty) {
      final latestExisting = existingPeriods.last;
      if (newStart.isBefore(latestExisting.startDate) && newEnd == null) {
        throw Exception('Para períodos com data de início anterior aos períodos existentes, é obrigatório informar a data de término (endDate).');
      }
    }

    final docRef = period.id.isEmpty ? periodsRef.doc() : periodsRef.doc(period.id);
    final batch = _firestore.batch();
    batch.set(docRef, period.toMap());

    if (existingPeriods.isNotEmpty) {
      final activeOrLatest = existingPeriods.firstWhere(
            (p) => p.endDate == null || p.startDate.isBefore(newStart),
        orElse: () => existingPeriods.last,
      );
      if (activeOrLatest.endDate == null && newStart.isAfter(activeOrLatest.startDate)) {
        final adjustedEnd = newStart.subtract(const Duration(days: 1));
        if (!adjustedEnd.isBefore(activeOrLatest.startDate)) {
          batch.update(periodsRef.doc(activeOrLatest.id), {
            'endDate': Timestamp.fromDate(adjustedEnd),
          });
        }
      }
    }

    await batch.commit();
    await _enforceMemberDataIntegrity(memberId);
  }

  @override
  Future<void> deleteMemberPeriod({
    required String memberId,
    required String periodId,
    required bool isPastorOrCoordinator,
  }) async {
    if (!isPastorOrCoordinator) {
      throw Exception('Apenas pastores ou coordenadores podem excluir períodos de um membro.');
    }

    final memberRef = _firestore.collection('members').doc(memberId);
    final periodRef = memberRef.collection('periods').doc(periodId);
    final periodDoc = await periodRef.get();

    if (!periodDoc.exists) return;
    final periodData = periodDoc.data() as Map<String, dynamic>;
    final periodCellId = periodData['cellId'] as String?;
    final periodEndDate = periodData['endDate'] as Timestamp?;
    final bool isCurrentPeriod = periodEndDate == null;

    await periodRef.delete();
    await _enforceMemberDataIntegrity(memberId);

    if (isCurrentPeriod && periodCellId != null && periodCellId.isNotEmpty) {
      final memberDoc = await memberRef.get();
      if (memberDoc.exists) {
        final memberData = memberDoc.data() as Map<String, dynamic>;
        final currentCellId = memberData['cellId'] as String?;
        if (currentCellId == periodCellId) {
          final userId = memberData['userId'] as String?;
          final batch = _firestore.batch();
          batch.update(memberRef, {'cellId': null, 'role': 'membro'});

          if (userId != null && userId.isNotEmpty) {
            final userRef = _firestore.collection('users').doc(userId);
            batch.update(userRef, {'primaryCellId': null});
          }

          final cellRef = _firestore.collection('cells').doc(periodCellId);
          final cellDoc = await cellRef.get();
          if (cellDoc.exists) {
            final cellData = cellDoc.data() as Map<String, dynamic>;
            final Map<String, dynamic> cellUpdates = {};
            if (cellData['leaderId'] == memberId || (userId != null && cellData['leaderId'] == userId)) {
              cellUpdates['leaderId'] = null;
            }
            if (cellData['coLeaderId'] == memberId || (userId != null && cellData['coLeaderId'] == userId)) {
              cellUpdates['coLeaderId'] = null;
            }
            if (cellData['hostId'] == memberId || (userId != null && cellData['hostId'] == userId)) {
              cellUpdates['hostId'] = null;
            }
            if (cellUpdates.isNotEmpty) {
              batch.update(cellRef, cellUpdates);
              if (cellUpdates.containsKey('leaderId') && userId != null && userId.isNotEmpty) {
                batch.update(_firestore.collection('users').doc(userId), {
                  'roles': FieldValue.arrayRemove(['leader']),
                });
              }
            }
          }

          await batch.commit();
        }
      }
    }
  }

  Future<void> _enforceMemberDataIntegrity(String memberId) async {
    final periodsSnap = await _firestore
        .collection('members')
        .doc(memberId)
        .collection('periods')
        .get();

    final periods = periodsSnap.docs.map((d) => d.data()).toList();
    final reportsSnap = await _firestore.collection('reports').get();

    for (var reportDoc in reportsSnap.docs) {
      final reportData = reportDoc.data();
      final cellId = reportData['cellId'] as String? ?? '';
      final scheduledDate = (reportData['scheduledDate'] as Timestamp).toDate();
      final dateOnly = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);

      bool hasValidPeriod = false;
      for (var p in periods) {
        if (p['cellId'] == cellId) {
          final start = (p['startDate'] as Timestamp).toDate();
          final startOnly = DateTime(start.year, start.month, start.day);
          final endTs = p['endDate'] as Timestamp?;
          final endOnly = endTs != null ? DateTime(endTs.toDate().year, endTs.toDate().month, endTs.toDate().day) : null;

          if (!dateOnly.isBefore(startOnly) && (endOnly == null || !dateOnly.isAfter(endOnly))) {
            hasValidPeriod = true;
            break;
          }
        }
      }

      if (!hasValidPeriod) {
        final attendances = (reportData['attendances'] as List<dynamic>?) ?? [];
        bool modified = false;
        List<String> rolesToTransfer = [];

        // Filtra para remover completamente o membro da lista de frequência se ele não tem período válido
        List<Map<String, dynamic>> updatedAttendances = [];

        for (var att in attendances) {
          final map = Map<String, dynamic>.from(att as Map<String, dynamic>);
          if (map['cellMemberId'] == memberId) {
            final roles = List<String>.from(map['rolesPerformed'] ?? []);
            rolesToTransfer.addAll(roles);
            modified = true;
            // Não adiciona o membro de volta em updatedAttendances (remove o card de falta)
          } else {
            updatedAttendances.add(map);
          }
        }

        if (modified) {
          if (rolesToTransfer.isNotEmpty) {
            final leaderId = await _getCellLeaderIdForReportOrCell(cellId);
            if (leaderId != null && leaderId.isNotEmpty) {
              for (var att in updatedAttendances) {
                if (att['cellMemberId'] == leaderId) {
                  final leaderRoles = List<String>.from(att['rolesPerformed'] ?? []);
                  for (var r in rolesToTransfer) {
                    if (!leaderRoles.contains(r)) leaderRoles.add(r);
                  }
                  att['rolesPerformed'] = leaderRoles;
                  att['isPresent'] = true;
                }
              }
            }
          }

          await reportDoc.reference.update({
            'attendances': updatedAttendances,
          });
        }
      }
    }
  }

  Future<String?> _getCellLeaderIdForReportOrCell(String cellId) async {
    try {
      final cellDoc = await _firestore.collection('cells').doc(cellId).get();
      if (cellDoc.exists) {
        final leaderId = cellDoc.data()?['leaderId'] as String?;
        if (leaderId != null && leaderId.isNotEmpty) return leaderId;
      }
      final membersSnap = await _firestore
          .collection('members')
          .where('cellId', isEqualTo: cellId)
          .get();
      for (var doc in membersSnap.docs) {
        final role = (doc.data()['role'] ?? '').toString().toLowerCase();
        if (role == 'lider' || role == 'leader' || role == 'líder') {
          return doc.id;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<List<CellMemberEntity>> getCellMembersForDate(String cellId, DateTime meetingDate) async {
    final targetDate = DateTime(meetingDate.year, meetingDate.month, meetingDate.day);
    final allMembersSnap = await _firestore.collection('members').get();
    List<CellMemberModel> validMembers = [];

    for (var doc in allMembersSnap.docs) {
      final memberData = doc.data();
      final memberId = doc.id;

      final periodsSnap = await _firestore
          .collection('members')
          .doc(memberId)
          .collection('periods')
          .get();

      if (periodsSnap.docs.isEmpty) {
        if (memberData['cellId'] == cellId) {
          validMembers.add(CellMemberModel.fromMap(memberData, memberId));
        }
        continue;
      }

      bool coveredInCell = false;
      for (var pDoc in periodsSnap.docs) {
        final pData = pDoc.data();
        final pCellId = pData['cellId'] as String? ?? '';
        if (pCellId != cellId) continue;

        final start = (pData['startDate'] as Timestamp).toDate();
        final startDateOnly = DateTime(start.year, start.month, start.day);
        final endTs = pData['endDate'] as Timestamp?;
        final endDateOnly = endTs != null ? DateTime(endTs.toDate().year, endTs.toDate().month, endTs.toDate().day) : null;

        if (!targetDate.isBefore(startDateOnly) && (endDateOnly == null || !targetDate.isAfter(endDateOnly))) {
          coveredInCell = true;
          break;
        }
      }

      if (coveredInCell) {
        validMembers.add(CellMemberModel.fromMap(memberData, memberId));
      }
    }

    return validMembers;
  }

  Future<String> _formatNameWithPastor(String name, {String? userId, String? role, Map<String, dynamic>? userData}) async {
    bool isPastor = (role != null && role.toLowerCase().contains('pastor'));
    String? gender = userData?['gender'] as String?;

    if (userId != null && userId.trim().isNotEmpty) {
      try {
        final uDoc = userData ?? (await _firestore.collection('users').doc(userId).get()).data();
        if (uDoc != null) {
          gender ??= uDoc['gender'] as String?;
          final roles = (uDoc['roles'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
          if (roles.contains('pastor')) {
            isPastor = true;
          }
        }
      } catch (_) {}
    }

    return GenderHelper.formatDisplayName(
      name: name,
      isPastor: isPastor,
      gender: gender,
    );
  }

  @override
  Future<String?> getUserNameById(String userId, {String? cellId}) async {
    if (userId.trim().isEmpty) {
      return await _findLeaderNameByCellId(cellId);
    }
    try {
      if (userId.contains(' ')) {
        return userId;
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final userName = data['name'] as String?;
        if (userName != null && userName.trim().isNotEmpty) {
          return await _formatNameWithPastor(userName, userId: userId, userData: data);
        }
      }

      final memberDoc = await _firestore.collection('members').doc(userId).get();
      if (memberDoc.exists) {
        final data = memberDoc.data() as Map<String, dynamic>;
        final memberUserId = data['userId'] as String?;
        final role = data['role'] as String?;

        if (memberUserId != null && memberUserId.trim().isNotEmpty) {
          final linkedUserDoc =
          await _firestore.collection('users').doc(memberUserId).get();
          if (linkedUserDoc.exists) {
            final linkedData = linkedUserDoc.data() as Map<String, dynamic>;
            final linkedName = linkedData['name'] as String?;
            if (linkedName != null && linkedName.trim().isNotEmpty) {
              return await _formatNameWithPastor(linkedName, userId: memberUserId, role: role, userData: linkedData);
            }
          }
        }

        final memberName = data['name'] as String?;
        if (memberName != null && memberName.trim().isNotEmpty) {
          return await _formatNameWithPastor(memberName, userId: memberUserId, role: role);
        }
      }

      final membersByUserId = await _firestore
          .collection('members')
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in membersByUserId.docs) {
        final memberName = doc.data()['name'] as String?;
        final role = doc.data()['role'] as String?;
        final mUserId = doc.data()['userId'] as String?;
        if (memberName != null && memberName.trim().isNotEmpty) {
          return await _formatNameWithPastor(memberName, userId: mUserId, role: role);
        }
      }

      if (cellId != null && cellId.trim().isNotEmpty) {
        final cellLeaderName = await _findLeaderNameByCellId(cellId);
        if (cellLeaderName != null) {
          return cellLeaderName;
        }
      }

      if (userId.length < 15) {
        return userId;
      }

      return null;
    } catch (_) {
      if (cellId != null) {
        final cellLeaderName = await _findLeaderNameByCellId(cellId);
        if (cellLeaderName != null) return cellLeaderName;
      }
      if (userId.contains(' ') || userId.length < 15) {
        return userId;
      }
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAllMembers() async {
    final snapshot =
    await _firestore.collection('members').orderBy('name').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<String?> _findLeaderNameByCellId(String? cellId) async {
    if (cellId == null || cellId.trim().isEmpty) return null;
    try {
      final membersSnap = await _firestore
          .collection('members')
          .where('cellId', isEqualTo: cellId)
          .get();

      for (var doc in membersSnap.docs) {
        final data = doc.data();
        final role = (data['role'] ?? '').toString().toLowerCase().trim();
        if (role == 'lider' || role == 'leader' || role == 'líder') {
          final name = data['name'] as String?;
          final memberUserId = data['userId'] as String?;
          if (name != null && name.trim().isNotEmpty) {
            return await _formatNameWithPastor(name, userId: memberUserId, role: role);
          }
          if (memberUserId != null && memberUserId.trim().isNotEmpty) {
            final userDoc =
            await _firestore.collection('users').doc(memberUserId).get();
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              final userName = userData['name'] as String?;
              if (userName != null && userName.trim().isNotEmpty) {
                return await _formatNameWithPastor(userName, userId: memberUserId, role: role, userData: userData);
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<CellModel> getCellById(String id) async {
    final doc = await _firestore.collection('cells').doc(id).get();
    if (!doc.exists) throw Exception('Célula não encontrada.');
    return CellModel.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<void> createCell(CellModel cell) async {
    final docRef =
    cell.id.isEmpty
        ? _firestore.collection('cells').doc()
        : _firestore.collection('cells').doc(cell.id);
    await docRef.set(cell.toMap());
  }

  @override
  Future<void> updateCell(CellModel cell) async {
    await _firestore.collection('cells').doc(cell.id).update(cell.toMap());
  }

  @override
  Future<void> deleteCell(String cellId) async {
    final cellRef = _firestore.collection('cells').doc(cellId);
    final batch = _firestore.batch();

    final usersSnapshot =
    await _firestore
        .collection('users')
        .where('primaryCellId', isEqualTo: cellId)
        .get();

    for (var userDoc in usersSnapshot.docs) {
      batch.update(userDoc.reference, {
        'primaryCellId': null,
        'roles': FieldValue.arrayRemove(['leader']),
      });
    }

    final membersSnapshot =
    await _firestore
        .collection('members')
        .where('cellId', isEqualTo: cellId)
        .get();

    for (var doc in membersSnapshot.docs) {
      final data = doc.data();
      final memberUserId = data['userId'] as String?;

      await _closeActivePeriodsBeforeBatch(batch, doc.reference, DateTime.now());

      if (memberUserId != null && memberUserId.trim().isNotEmpty) {
        final userRef = _firestore.collection('users').doc(memberUserId);
        batch.update(userRef, {
          'primaryCellId': null,
          'roles': FieldValue.arrayRemove(['leader']),
        });
      }

      batch.update(doc.reference, {'cellId': null, 'role': 'membro'});
    }

    final requestsSnapshot =
    await _firestore
        .collection('cell_requests')
        .where('cellId', isEqualTo: cellId)
        .get();
    for (var doc in requestsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(cellRef);
    await batch.commit();
  }

  @override
  Future<void> toggleCellStatus(String cellId, bool isActive) async {
    final batch = _firestore.batch();
    final cellRef = _firestore.collection('cells').doc(cellId);
    batch.update(cellRef, {'isActive': isActive});

    if (!isActive) {
      final usersSnapshot =
      await _firestore
          .collection('users')
          .where('primaryCellId', isEqualTo: cellId)
          .get();

      for (var userDoc in usersSnapshot.docs) {
        batch.update(userDoc.reference, {
          'primaryCellId': null,
          'roles': FieldValue.arrayRemove(['leader']),
        });
      }

      final membersSnapshot =
      await _firestore
          .collection('members')
          .where('cellId', isEqualTo: cellId)
          .get();

      for (var memberDoc in membersSnapshot.docs) {
        final role = (memberDoc.data()['role'] ?? '').toString().toLowerCase();
        if (role == 'lider' || role == 'leader') {
          batch.update(memberDoc.reference, {'role': 'membro'});
        }
      }
    }

    await batch.commit();
  }

  @override
  Future<List<CellMemberModel>> getCellMembers(String cellId) async {
    final snapshot =
    await _firestore
        .collection('members')
        .where('cellId', isEqualTo: cellId)
        .get();

    return snapshot.docs
        .map((doc) => CellMemberModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Stream<List<CellMemberModel>> watchCellMembers(String cellId) {
    return _firestore
        .collection('members')
        .where('cellId', isEqualTo: cellId)
        .snapshots()
        .map(
          (snapshot) =>
          snapshot.docs
              .map((doc) => CellMemberModel.fromMap(doc.data(), doc.id))
              .toList(),
    );
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  Future<void> _closeActivePeriod(
      Transaction transaction,
      DocumentReference memberRef,
      DateTime transitionDate,
      ) async {
    final periodsRef = memberRef.collection('periods');
    final activePeriodsSnap =
    await periodsRef.where('endDate', isNull: true).get();

    final transDateOnly = _dateOnly(transitionDate);

    for (var doc in activePeriodsSnap.docs) {
      final data = doc.data();
      final startTs = data['startDate'] as Timestamp?;
      DateTime targetEnd = transDateOnly;

      if (startTs != null) {
        final startOnly = _dateOnly(startTs.toDate());
        if (transDateOnly.isAfter(startOnly)) {
          targetEnd = transDateOnly.subtract(const Duration(days: 1));
        } else {
          targetEnd = startOnly;
        }
      }

      transaction.update(doc.reference, {
        'endDate': Timestamp.fromDate(targetEnd),
      });
    }
  }

  Future<void> _closeActivePeriodsBeforeBatch(
      WriteBatch batch,
      DocumentReference memberRef,
      DateTime transitionDate,
      ) async {
    final periodsRef = memberRef.collection('periods');
    final activePeriodsSnap =
    await periodsRef.where('endDate', isNull: true).get();

    final transDateOnly = _dateOnly(transitionDate);

    for (var doc in activePeriodsSnap.docs) {
      final data = doc.data();
      final startTs = data['startDate'] as Timestamp?;
      DateTime targetEnd = transDateOnly;

      if (startTs != null) {
        final startOnly = _dateOnly(startTs.toDate());
        if (transDateOnly.isAfter(startOnly)) {
          targetEnd = transDateOnly.subtract(const Duration(days: 1));
        } else {
          targetEnd = startOnly;
        }
      }

      batch.update(doc.reference, {
        'endDate': Timestamp.fromDate(targetEnd),
      });
    }
  }

  void _openNewPeriodBatch(
      WriteBatch batch,
      DocumentReference memberRef,
      String cellId,
      String cellName,
      String role,
      DateTime startDate,
      ) {
    final newPeriodRef = memberRef.collection('periods').doc();
    batch.set(newPeriodRef, {
      'cellId': cellId,
      'cellName': cellName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': null,
      'role': role,
    });
  }

  Future<void> _openNewPeriod(
      Transaction transaction,
      DocumentReference memberRef,
      String cellId,
      String cellName,
      String role,
      DateTime startDate,
      ) async {
    final newPeriodRef = memberRef.collection('periods').doc();
    transaction.set(newPeriodRef, {
      'cellId': cellId,
      'cellName': cellName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': null,
      'role': role,
    });
  }

  @override
  Future<void> addCellMember(CellMemberModel member) async {
    DocumentReference memberRef;

    if (member.id.isNotEmpty) {
      memberRef = _firestore.collection('members').doc(member.id);
    } else if (member.userId != null && member.userId!.isNotEmpty) {
      final existingMembersQuery = await _firestore
          .collection('members')
          .where('userId', isEqualTo: member.userId)
          .limit(1)
          .get();
      if (existingMembersQuery.docs.isNotEmpty) {
        memberRef = existingMembersQuery.docs.first.reference;
      } else {
        final docByUserId =
            await _firestore.collection('members').doc(member.userId!).get();
        if (docByUserId.exists) {
          memberRef = docByUserId.reference;
        } else {
          memberRef = _firestore.collection('members').doc();
        }
      }
    } else {
      memberRef = _firestore.collection('members').doc();
    }

    final cellRef = _firestore.collection('cells').doc(member.cellId);
    final normalizedRole = member.role.toLowerCase().trim();
    final actualId =
    (member.userId != null && member.userId!.isNotEmpty)
        ? member.userId!
        : memberRef.id;

    final cellDocSnap = await cellRef.get();
    final cellName =
    cellDocSnap.exists
        ? (cellDocSnap.data()?['name'] ?? 'Célula')
        : 'Célula';

    final batch = _firestore.batch();

    await _closeActivePeriodsBeforeBatch(batch, memberRef, DateTime.now());
    _openNewPeriodBatch(
      batch,
      memberRef,
      member.cellId,
      cellName,
      member.role,
      member.joinedAt,
    );

    batch.set(memberRef, member.toMap(), SetOptions(merge: true));

    if (normalizedRole == 'lider' || normalizedRole == 'leader') {
      batch.update(cellRef, {'leaderId': actualId});
      if (member.userId != null && member.userId!.isNotEmpty) {
        batch.update(_firestore.collection('users').doc(member.userId!), {
          'roles': FieldValue.arrayUnion(['leader']),
          'primaryCellId': member.cellId,
        });
      }
      final membersSnapshot =
      await _firestore
          .collection('members')
          .where('cellId', isEqualTo: member.cellId)
          .get();
      for (var doc in membersSnapshot.docs) {
        if (doc.id != memberRef.id) {
          final role = (doc.data()['role'] ?? '').toString().toLowerCase();
          if (role == 'lider' || role == 'leader') {
            batch.update(doc.reference, {'role': 'membro'});
            final oldUserId = doc.data()['userId'] as String?;
            if (oldUserId != null && oldUserId.isNotEmpty) {
              batch.update(_firestore.collection('users').doc(oldUserId), {
                'roles': FieldValue.arrayRemove(['leader']),
              });
            }
          }
        }
      }
    } else if (normalizedRole == 'colider' || normalizedRole == 'co-leader') {
      batch.update(cellRef, {'coLeaderId': actualId});
    } else if (normalizedRole == 'anfitriao' || normalizedRole == 'host') {
      batch.update(cellRef, {'hostId': actualId});
    }

    await batch.commit();
  }

  @override
  Future<void> updateCellMember(CellMemberModel member) async {
    await _firestore
        .collection('members')
        .doc(member.id)
        .update(member.toMap());
  }

  @override
  Future<void> removeCellMember(String memberId, String cellId) async {
    final cellRef = _firestore.collection('cells').doc(cellId);
    final memberRef = _firestore.collection('members').doc(memberId);

    final memberDoc = await memberRef.get();
    if (!memberDoc.exists) return;

    final memberData = memberDoc.data() as Map<String, dynamic>;
    final memberName = memberData['name'] as String? ?? '';
    final memberUserId = memberData['userId'] as String? ?? '';

    final cellDoc = await cellRef.get();
    if (!cellDoc.exists) return;

    final cellData = cellDoc.data() as Map<String, dynamic>;
    final currentLeaderId = cellData['leaderId'] as String? ?? '';
    final currentCoLeaderId = cellData['coLeaderId'] as String? ?? '';
    final currentHostId = cellData['hostId'] as String? ?? '';

    final batch = _firestore.batch();

    await _closeActivePeriodsBeforeBatch(batch, memberRef, DateTime.now());

    batch.update(memberRef, {'cellId': null, 'role': 'membro'});

    final Map<String, dynamic> cellUpdates = {};

    if (currentLeaderId == memberName ||
        currentLeaderId == memberUserId ||
        currentLeaderId == memberId) {
      cellUpdates['leaderId'] = null;
    }
    if (currentCoLeaderId == memberName ||
        currentCoLeaderId == memberUserId ||
        currentCoLeaderId == memberId) {
      cellUpdates['coLeaderId'] = null;
    }
    if (currentHostId == memberName ||
        currentHostId == memberUserId ||
        currentHostId == memberId) {
      cellUpdates['hostId'] = null;
    }

    if (cellUpdates.isNotEmpty) {
      batch.update(cellRef, cellUpdates);
    }

    if (memberUserId.isNotEmpty) {
      final userRef = _firestore.collection('users').doc(memberUserId);
      final Map<String, dynamic> userUpdates = {'primaryCellId': null};

      if (cellUpdates.containsKey('leaderId')) {
        userUpdates['roles'] = FieldValue.arrayRemove(['leader']);
      }
      batch.update(userRef, userUpdates);
    }

    await batch.commit();
  }

  @override
  Future<void> linkMemberToUserAccount({
    required String cellId,
    required String memberId,
    required String newUserId,
  }) async {
    final batch = _firestore.batch();
    final memberRef = _firestore.collection('members').doc(memberId);
    final cellRef = _firestore.collection('cells').doc(cellId);

    final memberDoc = await memberRef.get();
    String? memberRole;
    if (memberDoc.exists) {
      memberRole = (memberDoc.data()?['role'] ?? '').toString().toLowerCase();
    }

    final userDoc = await _firestore.collection('users').doc(newUserId).get();
    String? newUserName;
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      newUserName = userData['name'] as String?;
    }

    final Map<String, dynamic> memberUpdates = {
      'userId': newUserId,
      'cellId': cellId,
    };
    if (newUserName != null && newUserName.trim().isNotEmpty) {
      memberUpdates['name'] = newUserName;
    }

    batch.update(memberRef, memberUpdates);

    final userRef = _firestore.collection('users').doc(newUserId);
    final userUpdates = <String, dynamic>{'primaryCellId': cellId};

    final cellDoc = await cellRef.get();
    if (cellDoc.exists) {
      final cellData = cellDoc.data() as Map<String, dynamic>;
      final cellUpdates = <String, dynamic>{};

      if (cellData['leaderId'] == memberId ||
          memberRole == 'lider' ||
          memberRole == 'leader' ||
          memberRole == 'líder') {
        cellUpdates['leaderId'] = newUserId;
        userUpdates['roles'] = FieldValue.arrayUnion(['leader']);
      }
      if (cellData['coLeaderId'] == memberId) {
        cellUpdates['coLeaderId'] = newUserId;
      }
      if (cellData['hostId'] == memberId) {
        cellUpdates['hostId'] = newUserId;
      }

      if (cellUpdates.isNotEmpty) {
        batch.update(cellRef, cellUpdates);
      }
    }

    batch.update(userRef, userUpdates);
    await batch.commit();
  }

  @override
  Future<List<CellMemberModel>> getUnlinkedMembers() async {
    final cellsSnapshot = await _firestore.collection('cells').get();
    final Map<String, Map<String, dynamic>> cellDataMap = {
      for (var doc in cellsSnapshot.docs) doc.id: doc.data(),
    };

    final snapshot = await _firestore.collection('members').get();
    final List<CellMemberModel> unlinkedMembers = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final userId = data['userId'] as String?;

      if (userId == null || userId.trim().isEmpty) {
        final cellId = data['cellId'] as String?;
        String cellName = 'Sem Célula';

        if (cellId != null && cellId.trim().isNotEmpty) {
          final cellData = cellDataMap[cellId];
          if (cellData != null) {
            cellName = cellData['name'] as String? ?? 'Sem Nome';
          } else {
            cellName = 'Célula Excluída';
          }
        }

        unlinkedMembers.add(
          CellMemberModel.fromMap(data, doc.id, cellName: cellName),
        );
      }
    }

    return unlinkedMembers;
  }

  @override
  Future<List<UnlinkedUserOrMember>> getUsersAndMembersWithoutCell() async {
    final List<UnlinkedUserOrMember> result = [];

    final cellsSnapshot = await _firestore.collection('cells').get();
    final Map<String, Map<String, dynamic>> cellDataMap = {
      for (var doc in cellsSnapshot.docs) doc.id: doc.data(),
    };

    final usersSnapshot = await _firestore.collection('users').get();
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      final primaryCellId = data['primaryCellId'] as String?;

      bool hasNoActiveCell = true;
      if (primaryCellId != null && primaryCellId.trim().isNotEmpty) {
        final cellData = cellDataMap[primaryCellId];
        final bool cellExists = cellData != null;
        final bool cellIsActive =
            cellExists &&
                (cellData['isActive'] == true || cellData['isActive'] == 'true');
        if (cellExists && cellIsActive) {
          hasNoActiveCell = false;
        }
      }

      if (hasNoActiveCell) {
        result.add(
          UnlinkedUserOrMember(
            id: doc.id,
            name: data['name'] as String? ?? 'Usuário sem Nome',
            email: data['email'] as String?,
            isRegisteredUser: true,
            userId: doc.id,
          ),
        );
      }
    }

    final membersSnapshot = await _firestore.collection('members').get();
    for (var doc in membersSnapshot.docs) {
      final data = doc.data();
      final userId = data['userId'] as String?;

      if (userId == null || userId.trim().isEmpty) {
        final cellId = data['cellId'] as String?;
        bool hasNoActiveCell = true;

        if (cellId != null && cellId.trim().isNotEmpty) {
          final cellData = cellDataMap[cellId];
          final bool cellExists = cellData != null;
          final bool cellIsActive =
              cellExists &&
                  (cellData['isActive'] == true || cellData['isActive'] == 'true');
          if (cellExists && cellIsActive) {
            hasNoActiveCell = false;
          }
        }

        if (hasNoActiveCell) {
          String cellName = 'Sem Célula';
          if (cellId != null && cellId.trim().isNotEmpty) {
            final cellData = cellDataMap[cellId];
            if (cellData != null) {
              cellName = cellData['name'] as String? ?? 'Sem Nome';
            } else {
              cellName = 'Célula Excluída';
            }
          }

          if (!result.any((item) => item.id == doc.id)) {
            result.add(
              UnlinkedUserOrMember(
                id: doc.id,
                name: data['name'] as String? ?? 'Membro sem Nome',
                currentCellName: cellName,
                isRegisteredUser: false,
                userId: null,
              ),
            );
          }
        }
      }
    }

    return result;
  }

  @override
  Future<void> addExistingUserOrMemberToCell({
    required String cellId,
    required UnlinkedUserOrMember item,
    required String role,
    String? matchedMemberId,
    bool setAsLeader = false,
  }) async {
    final cellRef = _firestore.collection('cells').doc(cellId);
    final cellDocSnap = await cellRef.get();
    final cellName =
    cellDocSnap.exists
        ? (cellDocSnap.data()?['name'] ?? 'Célula')
        : 'Célula';

    final batch = _firestore.batch();

    DocumentReference memberRef;
    Map<String, dynamic> memberData = {};
    bool shouldBeLeader = setAsLeader;

    if (item.isRegisteredUser && item.userId != null) {
      final existingMembersQuery = await _firestore
          .collection('members')
          .where('userId', isEqualTo: item.userId)
          .limit(1)
          .get();

      if (existingMembersQuery.docs.isNotEmpty) {
        final existingDoc = existingMembersQuery.docs.first;
        memberRef = existingDoc.reference;
        final oldData = existingDoc.data();
        final oldRole = (oldData['role'] ?? '').toString().toLowerCase().trim();
        if (oldRole == 'lider' || oldRole == 'leader' || oldRole == 'líder') {
          shouldBeLeader = true;
        }

        await _closeActivePeriodsBeforeBatch(batch, memberRef, DateTime.now());
        _openNewPeriodBatch(
          batch,
          memberRef,
          cellId,
          cellName,
          shouldBeLeader ? 'lider' : role,
          DateTime.now(),
        );

        memberData = Map<String, dynamic>.from(oldData);
        memberData['cellId'] = cellId;
        memberData['role'] = shouldBeLeader ? 'lider' : role;
        if (item.name.trim().isNotEmpty) {
          memberData['name'] = item.name;
        }
      } else if (matchedMemberId != null && matchedMemberId.trim().isNotEmpty) {
        final foundDoc =
        await _firestore.collection('members').doc(matchedMemberId).get();
        if (foundDoc.exists) {
          memberRef = foundDoc.reference;
          final oldData = foundDoc.data() as Map<String, dynamic>;
          final oldRole = (oldData['role'] ?? '').toString().toLowerCase().trim();
          if (oldRole == 'lider' || oldRole == 'leader' || oldRole == 'líder') {
            shouldBeLeader = true;
          }

          await _closeActivePeriodsBeforeBatch(batch, memberRef, DateTime.now());
          _openNewPeriodBatch(
            batch,
            memberRef,
            cellId,
            cellName,
            shouldBeLeader ? 'lider' : role,
            DateTime.now(),
          );

          memberData = Map<String, dynamic>.from(oldData);
          memberData['userId'] = item.userId;
          memberData['cellId'] = cellId;
          memberData['role'] = shouldBeLeader ? 'lider' : role;
          if (item.name.trim().isNotEmpty) {
            memberData['name'] = item.name;
          }
        } else {
          memberRef = _firestore.collection('members').doc();
          _openNewPeriodBatch(
            batch,
            memberRef,
            cellId,
            cellName,
            shouldBeLeader ? 'lider' : role,
            DateTime.now(),
          );
          memberData = {
            'cellId': cellId,
            'userId': item.userId,
            'name': item.name,
            'role': shouldBeLeader ? 'lider' : role,
            'joinedAt': FieldValue.serverTimestamp(),
          };
        }
      } else {
        memberRef = _firestore.collection('members').doc();
        _openNewPeriodBatch(
          batch,
          memberRef,
          cellId,
          cellName,
          shouldBeLeader ? 'lider' : role,
          DateTime.now(),
        );
        memberData = {
          'cellId': cellId,
          'userId': item.userId,
          'name': item.name,
          'role': shouldBeLeader ? 'lider' : role,
          'joinedAt': FieldValue.serverTimestamp(),
        };
      }

      batch.set(memberRef, memberData, SetOptions(merge: true));

      final userRef = _firestore.collection('users').doc(item.userId);
      final userUpdates = <String, dynamic>{'primaryCellId': cellId};

      final normalizedRole =
      (memberData['role'] ?? role).toString().toLowerCase().trim();
      if (normalizedRole == 'lider' ||
          normalizedRole == 'leader' ||
          normalizedRole == 'líder') {
        shouldBeLeader = true;
        userUpdates['roles'] = FieldValue.arrayUnion(['leader']);
        batch.update(cellRef, {'leaderId': item.userId});
      }

      batch.update(userRef, userUpdates);
    } else {
      memberRef = _firestore.collection('members').doc(item.id);
      final memberDoc = await memberRef.get();

      if (memberDoc.exists) {
        final oldData = memberDoc.data() as Map<String, dynamic>;
        final oldRole = (oldData['role'] ?? '').toString().toLowerCase().trim();
        if (oldRole == 'lider' || oldRole == 'leader' || oldRole == 'líder') {
          shouldBeLeader = true;
        }

        await _closeActivePeriodsBeforeBatch(batch, memberRef, DateTime.now());
        _openNewPeriodBatch(
          batch,
          memberRef,
          cellId,
          cellName,
          shouldBeLeader ? 'lider' : role,
          DateTime.now(),
        );

        batch.update(memberRef, {
          'cellId': cellId,
          'role': shouldBeLeader ? 'lider' : role,
        });
      } else {
        _openNewPeriodBatch(
          batch,
          memberRef,
          cellId,
          cellName,
          role,
          DateTime.now(),
        );
        memberData = {
          'cellId': cellId,
          'userId': null,
          'name': item.name,
          'role': role,
          'joinedAt': FieldValue.serverTimestamp(),
        };
        batch.set(memberRef, memberData);
      }
    }

    final pendingRequestsSnap = await _firestore
        .collection('cell_requests')
        .where('cellId', isEqualTo: cellId)
        .where('status', isEqualTo: RequestStatus.pending.name)
        .get();

    for (var reqDoc in pendingRequestsSnap.docs) {
      final reqData = reqDoc.data();
      final reqUserId = reqData['userId'] as String?;
      final reqUserName = reqData['userName'] as String?;

      if ((item.userId != null && reqUserId == item.userId) ||
          (reqUserName != null &&
              reqUserName.trim().toLowerCase() ==
                  item.name.trim().toLowerCase())) {
        batch.delete(reqDoc.reference);
      }
    }

    await batch.commit();
  }

  @override
  Future<void> requestCellJoin(CellJoinRequestEntity request) async {
    await _firestore
        .collection('cell_requests')
        .doc(request.id.isEmpty ? null : request.id)
        .set(request.toMap());
  }

  @override
  Future<List<CellJoinRequestEntity>> getPendingRequestsByLeader(
      String leaderId,
      ) async {
    final cells = await getCells(filterByUserId: leaderId);
    if (cells.isEmpty) return [];

    final cellIds = cells.map((c) => c.id).toList();

    final snapshot =
    await _firestore
        .collection('cell_requests')
        .where('cellId', whereIn: cellIds)
        .where('status', isEqualTo: RequestStatus.pending.name)
        .get();

    return snapshot.docs
        .map((doc) => CellJoinRequestEntity.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<CellJoinRequestEntity?> getUserPendingRequest(String userId) async {
    final snapshot =
    await _firestore
        .collection('cell_requests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: RequestStatus.pending.name)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return CellJoinRequestEntity.fromMap(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    );
  }

  @override
  Future<List<CellJoinRequestEntity>> getPendingRequestsForCell(
      String cellId,
      ) async {
    final snapshot =
    await _firestore
        .collection('cell_requests')
        .where('cellId', isEqualTo: cellId)
        .where('status', isEqualTo: RequestStatus.pending.name)
        .get();

    return snapshot.docs
        .map((doc) => CellJoinRequestEntity.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> approveJoinRequest({
    required String requestId,
    required String cellId,
    required String userId,
    String? matchedMemberId,
    required String memberName,
    required bool setAsLeader,
  }) async {
    final batch = _firestore.batch();
    final requestRef = _firestore.collection('cell_requests').doc(requestId);

    batch.update(requestRef, {
      'status': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final targetCellRef = _firestore.collection('cells').doc(cellId);
    final targetCellDocSnap = await targetCellRef.get();
    final cellName =
    targetCellDocSnap.exists
        ? (targetCellDocSnap.data()?['name'] ?? 'Célula')
        : 'Célula';

    DocumentReference targetMemberRef;
    Map<String, dynamic> memberData = {};

    final Map<String, dynamic> targetCellUpdates = {};
    bool shouldBeLeader = setAsLeader;

    DocumentSnapshot<Map<String, dynamic>>? foundDocSnap;

    if (matchedMemberId != null && matchedMemberId.trim().isNotEmpty) {
      final docSnap =
          await _firestore.collection('members').doc(matchedMemberId).get();
      if (docSnap.exists) {
        foundDocSnap = docSnap;
      }
    }

    if (foundDocSnap == null && userId.isNotEmpty) {
      final existingMembersQuery = await _firestore
          .collection('members')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (existingMembersQuery.docs.isNotEmpty) {
        foundDocSnap = existingMembersQuery.docs.first;
      } else {
        final docByUserId =
            await _firestore.collection('members').doc(userId).get();
        if (docByUserId.exists) {
          foundDocSnap = docByUserId;
        }
      }
    }

    if (foundDocSnap != null && foundDocSnap.exists) {
      final oldData = Map<String, dynamic>.from(
        foundDocSnap.data() as Map<String, dynamic>,
      );
      final oldCellId = oldData['cellId'] as String? ?? '';
      final oldRole = (oldData['role'] ?? '').toString().toLowerCase().trim();

      if (oldRole == 'lider' || oldRole == 'leader' || oldRole == 'líder') {
        shouldBeLeader = true;
      }

      targetMemberRef = foundDocSnap.reference;
      final memberRefId = targetMemberRef.id;

      await _closeActivePeriodsBeforeBatch(
        batch,
        targetMemberRef,
        DateTime.now(),
      );
      _openNewPeriodBatch(
        batch,
        targetMemberRef,
        cellId,
        cellName,
        shouldBeLeader ? 'lider' : 'membro',
        DateTime.now(),
      );

      memberData = oldData;
      memberData['userId'] = userId;
      memberData['cellId'] = cellId;
      if (memberName.trim().isNotEmpty) {
        memberData['name'] = memberName;
      }
      if (shouldBeLeader) {
        memberData['role'] = 'lider';
      }

      batch.set(targetMemberRef, memberData, SetOptions(merge: true));

      if (oldCellId.isNotEmpty && oldCellId != cellId) {
        final oldCellRef = _firestore.collection('cells').doc(oldCellId);
        final oldCellDoc = await oldCellRef.get();
        if (oldCellDoc.exists) {
          final cellData = oldCellDoc.data() as Map<String, dynamic>;
          final Map<String, dynamic> oldCellUpdates = {};
          if (cellData['leaderId'] == memberRefId || cellData['leaderId'] == userId) {
            oldCellUpdates['leaderId'] = null;
          }
          if (cellData['coLeaderId'] == memberRefId || cellData['coLeaderId'] == userId) {
            oldCellUpdates['coLeaderId'] = null;
          }
          if (cellData['hostId'] == memberRefId || cellData['hostId'] == userId) {
            oldCellUpdates['hostId'] = null;
          }
          if (oldCellUpdates.isNotEmpty) {
            batch.update(oldCellRef, oldCellUpdates);
          }
        }
      } else {
        if (targetCellDocSnap.exists) {
          final cellData =
              targetCellDocSnap.data() as Map<String, dynamic>;
          if (cellData['leaderId'] == memberRefId || cellData['leaderId'] == userId || shouldBeLeader) {
            targetCellUpdates['leaderId'] = userId;
          }
          if (cellData['coLeaderId'] == memberRefId || cellData['coLeaderId'] == userId) {
            targetCellUpdates['coLeaderId'] = userId;
          }
          if (cellData['hostId'] == memberRefId || cellData['hostId'] == userId) {
            targetCellUpdates['hostId'] = userId;
          }
        }
      }
    } else {
      targetMemberRef = matchedMemberId != null && matchedMemberId.trim().isNotEmpty
          ? _firestore.collection('members').doc(matchedMemberId)
          : _firestore.collection('members').doc();
      _openNewPeriodBatch(
        batch,
        targetMemberRef,
        cellId,
        cellName,
        shouldBeLeader ? 'lider' : 'membro',
        DateTime.now(),
      );
      memberData = {
        'cellId': cellId,
        'userId': userId,
        'name': memberName,
        'role': shouldBeLeader ? 'lider' : 'membro',
        'joinedAt': FieldValue.serverTimestamp(),
      };
      batch.set(targetMemberRef, memberData);
    }

    final userRef = _firestore.collection('users').doc(userId);
    final userUpdates = <String, dynamic>{'primaryCellId': cellId};

    if (shouldBeLeader) {
      userUpdates['roles'] = FieldValue.arrayUnion(['leader']);
      targetCellUpdates['leaderId'] = userId;

      if (targetCellUpdates.containsKey('coLeaderId')) {
        targetCellUpdates['coLeaderId'] = null;
      }
      if (targetCellUpdates.containsKey('hostId')) {
        targetCellUpdates['hostId'] = null;
      }

      final membersSnapshot =
      await _firestore
          .collection('members')
          .where('cellId', isEqualTo: cellId)
          .get();
      for (var doc in membersSnapshot.docs) {
        if (doc.id != targetMemberRef.id) {
          final role = (doc.data()['role'] ?? '').toString().toLowerCase();
          if (role == 'lider' || role == 'leader') {
            batch.update(doc.reference, {'role': 'membro'});
            final oldLeaderUserId = doc.data()['userId'] as String?;
            if (oldLeaderUserId != null && oldLeaderUserId.isNotEmpty) {
              batch.update(
                _firestore.collection('users').doc(oldLeaderUserId),
                {
                  'roles': FieldValue.arrayRemove(['leader']),
                },
              );
            }
          }
        }
      }
    }

    if (targetCellUpdates.isNotEmpty) {
      batch.update(targetCellRef, targetCellUpdates);
    }

    batch.update(userRef, userUpdates);
    await batch.commit();
  }

  @override
  Future<void> rejectJoinRequest(String requestId) async {
    await _firestore.collection('cell_requests').doc(requestId).update({
      'status': RequestStatus.rejected.name,
    });
  }

  @override
  Future<void> cancelCellJoinRequest(String requestId) async {
    await _firestore.collection('cell_requests').doc(requestId).delete();
  }

  @override
  Future<void> changeMemberRole({
    required String cellId,
    required String memberId,
    required String userId,
    required String newRole,
  }) async {
    try {
      final cellRef = _firestore.collection('cells').doc(cellId);
      final memberRef = _firestore.collection('members').doc(memberId);
      final userRef =
      userId.isNotEmpty ? _firestore.collection('users').doc(userId) : null;

      final memberDoc = await memberRef.get();
      if (!memberDoc.exists) {
        throw Exception(
          "O documento do membro ($memberId) não foi encontrado no Firestore.",
        );
      }

      final currentRole =
      (memberDoc.data()?['role'] ?? '').toString().toLowerCase().trim();
      final normalizedNewRole = newRole.toLowerCase().trim();

      final batch = _firestore.batch();
      batch.update(memberRef, {'role': normalizedNewRole});

      final Map<String, dynamic> cellUpdates = {};
      final actualId = userId.isNotEmpty ? userId : memberId;

      if (currentRole == 'lider' ||
          currentRole == 'leader' ||
          currentRole == 'líder') {
        cellUpdates['leaderId'] = null;
        if (userRef != null) {
          batch.set(userRef, {
            'roles': FieldValue.arrayRemove(['leader']),
          }, SetOptions(merge: true));
        }
      } else if (currentRole == 'colider' ||
          currentRole == 'co-leader' ||
          currentRole == 'co-líder') {
        cellUpdates['coLeaderId'] = null;
      } else if (currentRole == 'anfitriao' ||
          currentRole == 'host' ||
          currentRole == 'anfitrião') {
        cellUpdates['hostId'] = null;
      }

      final membersSnapshot =
      await _firestore
          .collection('members')
          .where('cellId', isEqualTo: cellId)
          .get();

      if (normalizedNewRole == 'lider' || normalizedNewRole == 'leader') {
        cellUpdates['leaderId'] = actualId;
        if (userRef != null) {
          batch.set(userRef, {
            'roles': FieldValue.arrayUnion(['leader']),
          }, SetOptions(merge: true));
        }

        for (var doc in membersSnapshot.docs) {
          if (doc.id != memberId) {
            final role = (doc.data()['role'] ?? '').toString().toLowerCase();
            if (role == 'lider' || role == 'leader' || role == 'líder') {
              batch.update(doc.reference, {'role': 'membro'});
              final oldLeaderUserId = doc.data()['userId'] as String?;
              if (oldLeaderUserId != null && oldLeaderUserId.isNotEmpty) {
                batch.set(
                  _firestore.collection('users').doc(oldLeaderUserId),
                  {
                    'roles': FieldValue.arrayRemove(['leader']),
                  },
                  SetOptions(merge: true),
                );
              }
            }
          }
        }
      } else if (normalizedNewRole == 'colider' ||
          normalizedNewRole == 'co-leader') {
        cellUpdates['coLeaderId'] = actualId;
        for (var doc in membersSnapshot.docs) {
          if (doc.id != memberId) {
            final role = (doc.data()['role'] ?? '').toString().toLowerCase();
            if (role == 'colider' ||
                role == 'co-leader' ||
                role == 'co-líder') {
              batch.update(doc.reference, {'role': 'membro'});
            }
          }
        }
      } else if (normalizedNewRole == 'anfitriao' ||
          normalizedNewRole == 'host') {
        cellUpdates['hostId'] = actualId;
        for (var doc in membersSnapshot.docs) {
          if (doc.id != memberId) {
            final role = (doc.data()['role'] ?? '').toString().toLowerCase();
            if (role == 'anfitriao' || role == 'host' || role == 'anfitrião') {
              batch.update(doc.reference, {'role': 'membro'});
            }
          }
        }
      }

      if (cellUpdates.isNotEmpty) {
        batch.update(cellRef, cellUpdates);
      }

      await batch.commit();
    } catch (e, stack) {
      debugPrint("ERRO EM changeMemberRole: $e");
      debugPrint(stack.toString());
      rethrow;
    }
  }

  @override
  Future<void> transferMember({
    required String currentCellId,
    required String newCellId,
    required String memberId,
    required String userId,
    required String memberName,
  }) async {
    final memberRef = _firestore.collection('members').doc(memberId);
    final now = DateTime.now();

    final newCellDoc = await _firestore.collection('cells').doc(newCellId).get();
    final newCellName =
    newCellDoc.exists ? (newCellDoc.data()?['name'] ?? 'Célula') : 'Célula';

    await _firestore.runTransaction((transaction) async {
      await _closeActivePeriod(transaction, memberRef, now);
      await _openNewPeriod(transaction, memberRef, newCellId, newCellName, 'membro', now);

      transaction.update(memberRef, {
        'cellId': newCellId,
        'role': 'membro',
        if (userId.isNotEmpty) 'userId': userId,
        if (memberName.trim().isNotEmpty) 'name': memberName,
      });

      if (userId.isNotEmpty) {
        transaction.update(_firestore.collection('users').doc(userId), {
          'primaryCellId': newCellId,
        });
      }
    });
  }

  Future<void> _ensureUpcomingMeetings(String cellId) async {
    try {
      final cellDoc = await _firestore.collection('cells').doc(cellId).get();
      if (!cellDoc.exists) return;
      final cellData = cellDoc.data()!;
      final meetingDay = cellData['meetingDay'] as String?;

      final meetingsRef = _firestore
          .collection('cells')
          .doc(cellId)
          .collection('meetings');

      final snapshot =
      await meetingsRef.orderBy('meetingDate', descending: true).get();

      List<CellMeetingModel> meetings =
      snapshot.docs
          .map((doc) => CellMeetingModel.fromMap(doc.data(), doc.id))
          .toList();

      DateTime now = DateTime.now();

      if (meetings.isEmpty) {
        DateTime firstDate = _calculateNextMeetingDateStatic(meetingDay, now);
        final cycleKeyStr = PastoralCycleHelper.getCycleKeyString(firstDate);
        final dateId =
            '${firstDate.year}-${firstDate.month.toString().padLeft(2, '0')}-${firstDate.day.toString().padLeft(2, '0')}';

        final newMeeting = CellMeetingModel(
          id: dateId,
          cellId: cellId,
          meetingDate: firstDate,
          status: 'normal',
          isReportFilled: false,
          cycleKey: cycleKeyStr,
        );
        await meetingsRef.doc(dateId).set(newMeeting.toMap());
        return;
      }

      meetings.sort((a, b) => a.meetingDate.compareTo(b.meetingDate));
      CellMeetingModel latestMeeting = meetings.last;

      int safetyCounter = 0;

      while (latestMeeting.isExpired && safetyCounter < 10) {
        safetyCounter++;
        DateTime nextDate = _calculateNextMeetingDateAfter(
          latestMeeting.meetingDate,
          meetingDay,
        );

        String dateId =
            "${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}";

        bool exists = meetings.any(
              (m) =>
          m.meetingDate.year == nextDate.year &&
              m.meetingDate.month == nextDate.month &&
              m.meetingDate.day == nextDate.day,
        );

        if (!exists) {
          final cycleKeyStr = PastoralCycleHelper.getCycleKeyString(nextDate);

          final newMeeting = CellMeetingModel(
            id: dateId,
            cellId: cellId,
            meetingDate: nextDate,
            status: 'normal',
            isReportFilled: false,
            cycleKey: cycleKeyStr,
          );

          await meetingsRef
              .doc(dateId)
              .set(newMeeting.toMap(), SetOptions(merge: true));
          latestMeeting = newMeeting;
          meetings.add(latestMeeting);
        } else {
          break;
        }
      }
    } catch (e) {
      debugPrint('Erro em _ensureUpcomingMeetings: $e');
    }
  }

  DateTime _calculateNextMeetingDateStatic(
      String? meetingDayStr,
      DateTime fromDate,
      ) {
    if (meetingDayStr == null || meetingDayStr.trim().isEmpty) {
      return fromDate;
    }

    int targetWeekday = 2;
    final lower = meetingDayStr.toLowerCase().trim();
    if (lower.contains('segunda')) {
      targetWeekday = DateTime.monday;
    } else if (lower.contains('terça') || lower.contains('terca')) {
      targetWeekday = DateTime.tuesday;
    } else if (lower.contains('quarta')) {
      targetWeekday = DateTime.wednesday;
    } else if (lower.contains('quinta')) {
      targetWeekday = DateTime.thursday;
    } else if (lower.contains('sexta')) {
      targetWeekday = DateTime.friday;
    } else if (lower.contains('sábado') || lower.contains('sabado')) {
      targetWeekday = DateTime.saturday;
    } else if (lower.contains('domingo')) {
      targetWeekday = DateTime.sunday;
    }

    int daysUntil = targetWeekday - fromDate.weekday;
    if (daysUntil <= 0) {
      daysUntil += 7;
    }

    return DateTime(
      fromDate.year,
      fromDate.month,
      fromDate.day,
    ).add(Duration(days: daysUntil));
  }

  DateTime _calculateNextMeetingDateAfter(
      DateTime afterDate,
      String? meetingDayStr,
      ) {
    if (meetingDayStr == null || meetingDayStr.trim().isEmpty) {
      return afterDate.add(const Duration(days: 7));
    }

    int targetWeekday = 2;
    final lower = meetingDayStr.toLowerCase().trim();
    if (lower.contains('segunda')) {
      targetWeekday = DateTime.monday;
    } else if (lower.contains('terça') || lower.contains('terca')) {
      targetWeekday = DateTime.tuesday;
    } else if (lower.contains('quarta')) {
      targetWeekday = DateTime.wednesday;
    } else if (lower.contains('quinta')) {
      targetWeekday = DateTime.thursday;
    } else if (lower.contains('sexta')) {
      targetWeekday = DateTime.friday;
    } else if (lower.contains('sábado') || lower.contains('sabado')) {
      targetWeekday = DateTime.saturday;
    } else if (lower.contains('domingo')) {
      targetWeekday = DateTime.sunday;
    }

    DateTime candidate = DateTime(
      afterDate.year,
      afterDate.month,
      afterDate.day,
    ).add(const Duration(days: 1));
    while (candidate.weekday != targetWeekday) {
      candidate = candidate.add(const Duration(days: 1));
    }

    return candidate;
  }

  @override
  Future<CellMeetingModel?> getLatestMeeting(String cellId) async {
    await _ensureUpcomingMeetings(cellId);
    final snapshot =
    await _firestore
        .collection('cells')
        .doc(cellId)
        .collection('meetings')
        .orderBy('meetingDate', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return CellMeetingModel.fromMap(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    );
  }

  @override
  Future<List<CellMeetingModel>> getAllMeetingsForCell(String cellId) async {
    await _ensureUpcomingMeetings(cellId);
    final snapshot =
    await _firestore
        .collection('cells')
        .doc(cellId)
        .collection('meetings')
        .orderBy('meetingDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CellMeetingModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<List<CellMeetingModel>> getPendingMeetingsForCell(
      String cellId,
      ) async {
    await _ensureUpcomingMeetings(cellId);
    final snapshot =
    await _firestore
        .collection('cells')
        .doc(cellId)
        .collection('meetings')
        .where('isReportFilled', isEqualTo: false)
        .orderBy('meetingDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CellMeetingModel.fromMap(doc.data(), doc.id))
        .where((m) => m.isExpired)
        .toList();
  }

  @override
  Future<void> saveOrUpdateMeeting(CellMeetingModel meeting) async {
    final meetingsRef = _firestore
        .collection('cells')
        .doc(meeting.cellId)
        .collection('meetings');

    final docRef =
    meeting.id.isEmpty ? meetingsRef.doc() : meetingsRef.doc(meeting.id);
    await docRef.set(meeting.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> requestReportDeletion(
      String cellId,
      String meetingId,
      String reason,
      String deletionType,
      ) async {
    await _firestore
        .collection('cells')
        .doc(cellId)
        .collection('meetings')
        .doc(meetingId)
        .update({
      'deletionRequested': true,
      'deletionReason': reason,
      'deletionType': deletionType,
    });
  }

  @override
  Future<void> deleteOnlyReport(
      String cellId,
      String meetingId,
      DateTime meetingDate,
      ) async {
    await _firestore
        .collection('cells')
        .doc(cellId)
        .collection('meetings')
        .doc(meetingId)
        .update({
      'isReportFilled': false,
      'deletionRequested': false,
      'deletionReason': FieldValue.delete(),
    });

    final snapshot =
    await _firestore
        .collection('reports')
        .where('cellId', isEqualTo: cellId)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['scheduledDate'] != null) {
        final DateTime scheduled =
        (data['scheduledDate'] as Timestamp).toDate();
        if (scheduled.year == meetingDate.year &&
            scheduled.month == meetingDate.month &&
            scheduled.day == meetingDate.day) {
          batch.delete(doc.reference);
        }
      }
    }
    await batch.commit();
  }

  @override
  Future<void> deleteMeetingAndReport(
      String cellId,
      String meetingId,
      DateTime meetingDate,
      ) async {
    await _firestore
        .collection('cells')
        .doc(cellId)
        .collection('meetings')
        .doc(meetingId)
        .delete();

    final snapshot =
    await _firestore
        .collection('reports')
        .where('cellId', isEqualTo: cellId)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['scheduledDate'] != null) {
        final DateTime scheduled =
        (data['scheduledDate'] as Timestamp).toDate();
        if (scheduled.year == meetingDate.year &&
            scheduled.month == meetingDate.month &&
            scheduled.day == meetingDate.day) {
          batch.delete(doc.reference);
        }
      }
    }
    await batch.commit();
  }

  @override
  Future<List<PrayerRequestModel>> getPrayerRequests(String cellId) async {
    final snapshot =
    await _firestore
        .collection('cells')
        .doc(cellId)
        .collection('prayer_requests')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => PrayerRequestModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Stream<List<PrayerRequestModel>> watchPrayerRequests(String cellId) {
    return _firestore
        .collection('cells')
        .doc(cellId)
        .collection('prayer_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
          snapshot.docs
              .map((doc) => PrayerRequestModel.fromMap(doc.data(), doc.id))
              .toList(),
    );
  }

  @override
  Future<void> addPrayerRequest(PrayerRequestModel request) async {
    final requestsRef = _firestore
        .collection('cells')
        .doc(request.cellId)
        .collection('prayer_requests');

    final docRef =
    request.id.isEmpty ? requestsRef.doc() : requestsRef.doc(request.id);
    await docRef.set(request.toMap());
  }

  @override
  Future<void> deletePrayerRequest(String cellId, String requestId) async {
    await _firestore
        .collection('cells')
        .doc(cellId)
        .collection('prayer_requests')
        .doc(requestId)
        .delete();
  }

  @override
  Future<void> updatePrayerRequest(PrayerRequestModel request) async {
    await _firestore
        .collection('cells')
        .doc(request.cellId)
        .collection('prayer_requests')
        .doc(request.id)
        .update(request.toMap());
  }

  @override
  Future<void> deleteMemberCompletely(String memberId) async {
    final batch = _firestore.batch();
    final memberRef = _firestore.collection('members').doc(memberId);
    
    final periodsSnap = await memberRef.collection('periods').get();
    for (var doc in periodsSnap.docs) {
      batch.delete(doc.reference);
    }
    
    batch.delete(memberRef);
    await batch.commit();
  }

  @override
  Future<MultiplicationSettingsModel> getMultiplicationSettings() async {
    try {
      final doc = await _firestore.collection('multiplication_settings').doc('default').get();
      if (doc.exists && doc.data() != null) {
        return MultiplicationSettingsModel.fromMap(doc.data()!);
      }
    } catch (e) {
      debugPrint('Erro ao carregar multiplication_settings: $e');
    }
    return const MultiplicationSettingsModel();
  }

  @override
  Future<void> saveMultiplicationSettings(MultiplicationSettingsModel settings) async {
    await _firestore
        .collection('multiplication_settings')
        .doc('default')
        .set(settings.toMap(), SetOptions(merge: true));
  }
}