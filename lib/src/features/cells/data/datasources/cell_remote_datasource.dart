import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_join_request_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_member_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/cells/data/models/prayer_request_model.dart';
import 'package:celulas_app/src/features/cells/data/models/unlinked_user_or_member_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  Stream<List<CellMemberEntity>> watchCellMembers(String cellId);

  Future<String?> getUserNameById(String userId);

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

  // Reuniões & Atividades da Célula
  Future<CellMeetingModel?> getLatestMeeting(String cellId);

  Future<void> saveOrUpdateMeeting(CellMeetingModel meeting);

  // Pedidos de Oração
  Future<List<PrayerRequestModel>> getPrayerRequests(String cellId);

  Future<void> addPrayerRequest(PrayerRequestModel request);

  Future<void> deletePrayerRequest(String cellId, String requestId);

  Future<void> updatePrayerRequest(PrayerRequestModel request);
}

class CellRemoteDataSourceImpl implements ICellRemoteDataSource {
  final FirebaseFirestore _firestore;

  CellRemoteDataSourceImpl(this._firestore);

  // ================= CÉLULAS =================
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

  @override
  Future<String?> getUserNameById(String userId) async {
    if (userId.trim().isEmpty) return null;
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final userName = data['name'] as String?;
        if (userName != null && userName.trim().isNotEmpty) {
          return userName;
        }
      }

      final membersSnapshot = await _firestore.collection('members').get();

      for (var doc in membersSnapshot.docs) {
        if (doc.id == userId) {
          final data = doc.data();
          final memberUserId = data['userId'] as String?;

          if (memberUserId != null && memberUserId.trim().isNotEmpty) {
            final linkedUserDoc =
                await _firestore.collection('users').doc(memberUserId).get();
            if (linkedUserDoc.exists) {
              final linkedUserData =
                  linkedUserDoc.data() as Map<String, dynamic>;
              final linkedName = linkedUserData['name'] as String?;
              if (linkedName != null && linkedName.trim().isNotEmpty) {
                return linkedName;
              }
            }
          }

          final memberName = data['name'] as String?;
          if (memberName != null && memberName.trim().isNotEmpty) {
            return memberName;
          }
        }
      }

      for (var doc in membersSnapshot.docs) {
        final data = doc.data();
        if (data['userId'] == userId) {
          final memberName = data['name'] as String?;
          if (memberName != null && memberName.trim().isNotEmpty) {
            return memberName;
          }
        }
      }

      return null;
    } catch (_) {
      return null;
    }
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

  // ================= MEMBROS =================
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

  @override
  Future<void> addCellMember(CellMemberModel member) async {
    final memberRef =
        member.id.isEmpty
            ? _firestore.collection('members').doc()
            : _firestore.collection('members').doc(member.id);

    final cellRef = _firestore.collection('cells').doc(member.cellId);
    final normalizedRole = member.role.toLowerCase().trim();
    final actualId =
        (member.userId != null && member.userId!.isNotEmpty)
            ? member.userId!
            : memberRef.id;

    final batch = _firestore.batch();
    batch.set(memberRef, member.toMap());

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
      final membersSnapshot =
          await _firestore
              .collection('members')
              .where('cellId', isEqualTo: member.cellId)
              .get();
      for (var doc in membersSnapshot.docs) {
        if (doc.id != memberRef.id) {
          final role = (doc.data()['role'] ?? '').toString().toLowerCase();
          if (role == 'colider' || role == 'co-leader') {
            batch.update(doc.reference, {'role': 'membro'});
          }
        }
      }
    } else if (normalizedRole == 'anfitriao' || normalizedRole == 'host') {
      batch.update(cellRef, {'hostId': actualId});
      final membersSnapshot =
          await _firestore
              .collection('members')
              .where('cellId', isEqualTo: member.cellId)
              .get();
      for (var doc in membersSnapshot.docs) {
        if (doc.id != memberRef.id) {
          final role = (doc.data()['role'] ?? '').toString().toLowerCase();
          if (role == 'anfitriao' || role == 'host') {
            batch.update(doc.reference, {'role': 'membro'});
          }
        }
      }
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

    // 1. Utilizadores com conta que não têm célula ativa
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

    // 2. Membros sem conta que NÃO possuem célula ativa
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
  }) async {
    final cellRef = _firestore.collection('cells').doc(cellId);
    final batch = _firestore.batch();

    if (item.isRegisteredUser && item.userId != null) {
      final memberRef = _firestore.collection('members').doc();
      final newMember = CellMemberModel(
        id: memberRef.id,
        cellId: cellId,
        userId: item.userId,
        name: item.name,
        role: role,
        joinedAt: DateTime.now(),
      );

      batch.set(memberRef, newMember.toMap());

      final userRef = _firestore.collection('users').doc(item.userId);
      final userUpdates = <String, dynamic>{'primaryCellId': cellId};

      final normalizedRole = role.toLowerCase().trim();
      if (normalizedRole == 'lider' || normalizedRole == 'leader') {
        userUpdates['roles'] = FieldValue.arrayUnion(['leader']);
        batch.update(cellRef, {'leaderId': item.userId});
      }

      batch.update(userRef, userUpdates);
    } else {
      final memberRef = _firestore.collection('members').doc(item.id);
      final memberDoc = await memberRef.get();

      if (memberDoc.exists) {
        batch.update(memberRef, {'cellId': cellId, 'role': role});
      } else {
        final newMember = CellMemberModel(
          id: memberRef.id,
          cellId: cellId,
          userId: null,
          name: item.name,
          role: role,
          joinedAt: DateTime.now(),
        );
        batch.set(memberRef, newMember.toMap());
      }
    }

    final pendingRequestsSnap =
        await _firestore
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
    DocumentReference targetMemberRef;
    Map<String, dynamic> memberData = {};

    final Map<String, dynamic> targetCellUpdates = {};
    bool shouldBeLeader = setAsLeader;

    if (matchedMemberId != null && matchedMemberId.trim().isNotEmpty) {
      final foundDoc =
          await _firestore.collection('members').doc(matchedMemberId).get();

      if (foundDoc.exists) {
        final oldData = Map<String, dynamic>.from(
          foundDoc.data() as Map<String, dynamic>,
        );
        final oldCellId = oldData['cellId'] as String? ?? '';
        final oldRole = (oldData['role'] ?? '').toString().toLowerCase().trim();

        if (oldRole == 'lider' || oldRole == 'leader' || oldRole == 'líder') {
          shouldBeLeader = true;
        }

        memberData = oldData;
        memberData['userId'] = userId;
        memberData['cellId'] = cellId;
        if (memberName.trim().isNotEmpty) {
          memberData['name'] = memberName;
        }
        if (shouldBeLeader) {
          memberData['role'] = 'lider';
        }

        targetMemberRef = _firestore.collection('members').doc(matchedMemberId);
        batch.update(targetMemberRef, memberData);

        if (oldCellId.isNotEmpty && oldCellId != cellId) {
          final oldCellRef = _firestore.collection('cells').doc(oldCellId);
          final oldCellDoc = await oldCellRef.get();
          if (oldCellDoc.exists) {
            final cellData = oldCellDoc.data() as Map<String, dynamic>;
            final Map<String, dynamic> oldCellUpdates = {};
            if (cellData['leaderId'] == matchedMemberId) {
              oldCellUpdates['leaderId'] = null;
            }
            if (cellData['coLeaderId'] == matchedMemberId) {
              oldCellUpdates['coLeaderId'] = null;
            }
            if (cellData['hostId'] == matchedMemberId) {
              oldCellUpdates['hostId'] = null;
            }
            if (oldCellUpdates.isNotEmpty) {
              batch.update(oldCellRef, oldCellUpdates);
            }
          }
        } else {
          final targetCellDoc = await targetCellRef.get();
          if (targetCellDoc.exists) {
            final cellData = targetCellDoc.data() as Map<String, dynamic>;
            if (cellData['leaderId'] == matchedMemberId || shouldBeLeader) {
              targetCellUpdates['leaderId'] = userId;
            }
            if (cellData['coLeaderId'] == matchedMemberId) {
              targetCellUpdates['coLeaderId'] = userId;
            }
            if (cellData['hostId'] == matchedMemberId) {
              targetCellUpdates['hostId'] = userId;
            }
          }
        }
      } else {
        targetMemberRef = _firestore.collection('members').doc(matchedMemberId);
        memberData = {
          'cellId': cellId,
          'userId': userId,
          'name': memberName,
          'role': shouldBeLeader ? 'lider' : 'membro',
          'joinedAt': FieldValue.serverTimestamp(),
        };
        batch.set(targetMemberRef, memberData);
      }
    } else {
      targetMemberRef = _firestore.collection('members').doc();
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
    final memberDoc = await memberRef.get();
    if (!memberDoc.exists) return;

    final memberData = Map<String, dynamic>.from(memberDoc.data()!);

    String actualUserId = memberData['userId'] as String? ?? '';
    if (actualUserId.trim().isEmpty) {
      actualUserId = userId;
    }

    final userRef =
        actualUserId.isNotEmpty
            ? _firestore.collection('users').doc(actualUserId)
            : null;

    final batch = _firestore.batch();

    batch.update(memberRef, {
      'cellId': newCellId,
      'role': 'membro',
      if (actualUserId.isNotEmpty) 'userId': actualUserId,
      if (memberName.trim().isNotEmpty) 'name': memberName,
    });

    final currentCellRef = _firestore.collection('cells').doc(currentCellId);
    final oldCellDoc = await currentCellRef.get();
    if (oldCellDoc.exists) {
      final cellData = oldCellDoc.data() as Map<String, dynamic>;
      final currentLeaderId = cellData['leaderId'] as String? ?? '';
      final currentCoLeaderId = cellData['coLeaderId'] as String? ?? '';
      final currentHostId = cellData['hostId'] as String? ?? '';

      final Map<String, dynamic> oldCellUpdates = {};
      if (currentLeaderId == memberId ||
          currentLeaderId == actualUserId ||
          currentLeaderId == memberName) {
        oldCellUpdates['leaderId'] = null;
        if (userRef != null) {
          batch.update(userRef, {
            'roles': FieldValue.arrayRemove(['leader']),
          });
        }
      }
      if (currentCoLeaderId == memberId ||
          currentCoLeaderId == actualUserId ||
          currentCoLeaderId == memberName) {
        oldCellUpdates['coLeaderId'] = null;
      }
      if (currentHostId == memberId ||
          currentHostId == actualUserId ||
          currentHostId == memberName) {
        oldCellUpdates['hostId'] = null;
      }

      if (oldCellUpdates.isNotEmpty) {
        batch.update(currentCellRef, oldCellUpdates);
      }
    }

    if (userRef != null) {
      batch.update(userRef, {'primaryCellId': newCellId});
    }

    await batch.commit();
  }

  // ================= REUNIÕES & ATIVIDADES =================
  @override
  Future<CellMeetingModel?> getLatestMeeting(String cellId) async {
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
  Future<void> saveOrUpdateMeeting(CellMeetingModel meeting) async {
    final meetingsRef = _firestore
        .collection('cells')
        .doc(meeting.cellId)
        .collection('meetings');

    final docRef =
        meeting.id.isEmpty ? meetingsRef.doc() : meetingsRef.doc(meeting.id);
    await docRef.set(meeting.toMap(), SetOptions(merge: true));
  }

  // ================= PEDIDOS DE ORAÇÃO =================
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

  Future<void> updatePrayerRequest(PrayerRequestModel request) async {
    await _firestore
        .collection('cells')
        .doc(request.cellId)
        .collection('prayer_requests')
        .doc(request.id)
        .update(request.toMap());
  }
}
