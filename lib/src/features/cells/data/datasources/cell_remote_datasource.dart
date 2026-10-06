import 'package:celulas_app/src/features/cells/data/models/cell_join_request_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_member_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

abstract class ICellRemoteDataSource {
  Future<List<CellModel>> getCells({String? filterByUserId});

  Stream<List<CellModel>> watchCells({String? filterByUserId});

  Future<CellModel> getCellById(String id);

  Future<void> createCell(CellModel cell);

  Future<void> updateCell(CellModel cell);

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
}

class CellRemoteDataSourceImpl implements ICellRemoteDataSource {
  final FirebaseFirestore _firestore;

  CellRemoteDataSourceImpl(this._firestore);

  // ================= CÉLULAS =================
  @override
  Future<List<CellModel>> getCells({String? filterByUserId}) async {
    Query query = _firestore.collection('cells');

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
  Stream<List<CellModel>> watchCells({String? filterByUserId}) {
    Query query = _firestore.collection('cells');
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
  Future<String?> getUserNameById(String userId) async {
    if (userId.trim().isEmpty) return null;
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      return data['name'] as String?;
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

  // ================= MEMBROS =================
  @override
  Future<List<CellMemberModel>> getCellMembers(String cellId) async {
    final snapshot =
    await _firestore
        .collection('cells')
        .doc(cellId)
        .collection('members')
        .get();

    return snapshot.docs
        .map((doc) => CellMemberModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Stream<List<CellMemberModel>> watchCellMembers(String cellId) {
    return _firestore
        .collection('cells')
        .doc(cellId)
        .collection('members')
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
    final cellRef = _firestore.collection('cells').doc(member.cellId);
    final memberRef =
    member.id.isEmpty
        ? cellRef.collection('members').doc()
        : cellRef.collection('members').doc(member.id);

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
      final membersSnapshot = await cellRef.collection('members').get();
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
      final membersSnapshot = await cellRef.collection('members').get();
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
      final membersSnapshot = await cellRef.collection('members').get();
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
        .collection('cells')
        .doc(member.cellId)
        .collection('members')
        .doc(member.id)
        .update(member.toMap());
  }

  @override
  Future<void> removeCellMember(String memberId, String cellId) async {
    final cellRef = _firestore.collection('cells').doc(cellId);
    final memberRef = cellRef.collection('members').doc(memberId);

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
    batch.delete(memberRef);

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
    final cellRef = _firestore.collection('cells').doc(cellId);
    final memberRef = cellRef.collection('members').doc(memberId);

    batch.update(memberRef, {'userId': newUserId});

    final cellDoc = await cellRef.get();
    if (cellDoc.exists) {
      final cellData = cellDoc.data() as Map<String, dynamic>;
      final cellUpdates = <String, dynamic>{};

      // Substitui o ID temporário pelo novo userId nas permissões da célula
      if (cellData['leaderId'] == memberId) cellUpdates['leaderId'] = newUserId;
      if (cellData['coLeaderId'] == memberId) cellUpdates['coLeaderId'] = newUserId;
      if (cellData['hostId'] == memberId) cellUpdates['hostId'] = newUserId;

      if (cellUpdates.isNotEmpty) {
        batch.update(cellRef, cellUpdates);
      }
    }

    await batch.commit();
  }

  @override
  Future<List<CellMemberModel>> getUnlinkedMembers() async {
    final cellsSnapshot = await _firestore.collection('cells').get();
    final Map<String, String> cellNameMap = {
      for (var doc in cellsSnapshot.docs)
        doc.id: (doc.data()['name'] as String?) ?? 'Sem Nome'
    };

    final snapshot = await _firestore.collectionGroup('members').get();
    final List<CellMemberModel> unlinkedMembers = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final userId = data['userId'] as String?;
      if (userId == null || userId.trim().isEmpty) {
        final cellId =
            data['cellId'] as String? ?? doc.reference.parent.parent?.id ?? '';
        final cellName = cellNameMap[cellId] ?? 'Célula Desconhecida';
        unlinkedMembers.add(
          CellMemberModel.fromMap(data, doc.id, cellName: cellName),
        );
      }
    }

    return unlinkedMembers;
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

  Future<void> _copySubcollections(
      DocumentReference src,
      DocumentReference dst,
      ) async {
    final subcollections = [
      'attendances',
      'presences',
      'activities',
      'history',
    ];
    for (final subName in subcollections) {
      final snapshot = await src.collection(subName).get();
      for (var doc in snapshot.docs) {
        await dst.collection(subName).doc(doc.id).set(doc.data());
        await doc.reference.delete();
      }
    }
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

    // Armazena as atualizações que precisam ir para o documento raiz da célula
    final Map<String, dynamic> targetCellUpdates = {};

    if (matchedMemberId != null && matchedMemberId.trim().isNotEmpty) {
      final membersGroupSnapshot =
      await _firestore.collectionGroup('members').get();
      DocumentSnapshot? foundDoc;
      for (var doc in membersGroupSnapshot.docs) {
        if (doc.id == matchedMemberId) {
          foundDoc = doc;
          break;
        }
      }

      if (foundDoc != null && foundDoc.exists) {
        final oldData = Map<String, dynamic>.from(
          foundDoc.data() as Map<String, dynamic>,
        );
        final oldCellId =
            oldData['cellId'] as String? ??
                foundDoc.reference.parent.parent?.id ??
                '';

        memberData = oldData;
        memberData['userId'] = userId;
        memberData['cellId'] = cellId;
        if (memberName.trim().isNotEmpty) {
          memberData['name'] = memberName;
        }
        if (setAsLeader) {
          memberData['role'] = 'lider';
        }

        if (oldCellId.isNotEmpty && oldCellId != cellId) {
          final oldCellRef = _firestore.collection('cells').doc(oldCellId);
          final oldMemberRef = oldCellRef.collection('members').doc(
            matchedMemberId,
          );
          targetMemberRef = targetCellRef.collection('members').doc(
            matchedMemberId,
          );

          await _copySubcollections(oldMemberRef, targetMemberRef);
          batch.delete(oldMemberRef);

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
          targetMemberRef = targetCellRef.collection('members').doc(
            matchedMemberId,
          );

          // Verifica se os campos raiz da célula atual guardavam o ID temporário
          final targetCellDoc = await targetCellRef.get();
          if (targetCellDoc.exists) {
            final cellData = targetCellDoc.data() as Map<String, dynamic>;
            if (cellData['leaderId'] == matchedMemberId) targetCellUpdates['leaderId'] = userId;
            if (cellData['coLeaderId'] == matchedMemberId) targetCellUpdates['coLeaderId'] = userId;
            if (cellData['hostId'] == matchedMemberId) targetCellUpdates['hostId'] = userId;
          }
        }
      } else {
        targetMemberRef = targetCellRef.collection('members').doc(
          matchedMemberId,
        );
        memberData = {
          'cellId': cellId,
          'userId': userId,
          'name': memberName,
          'role': setAsLeader ? 'lider' : 'membro',
          'joinedAt': FieldValue.serverTimestamp(),
        };
      }
    } else {
      targetMemberRef = targetCellRef.collection('members').doc();
      memberData = {
        'cellId': cellId,
        'userId': userId,
        'name': memberName,
        'role': setAsLeader ? 'lider' : 'membro',
        'joinedAt': FieldValue.serverTimestamp(),
      };
    }

    batch.set(targetMemberRef, memberData);

    final userRef = _firestore.collection('users').doc(userId);
    final userUpdates = <String, dynamic>{'primaryCellId': cellId};

    if (setAsLeader) {
      userUpdates['roles'] = FieldValue.arrayUnion(['leader']);
      targetCellUpdates['leaderId'] = userId;

      // Remove cargos menores caso ele já ocupasse um antes e seja promovido no vínculo
      if (targetCellUpdates.containsKey('coLeaderId')) targetCellUpdates['coLeaderId'] = null;
      if (targetCellUpdates.containsKey('hostId')) targetCellUpdates['hostId'] = null;

      final membersSnapshot = await targetCellRef.collection('members').get();
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
      final memberRef = cellRef.collection('members').doc(memberId);
      final userRef =
      userId.isNotEmpty
          ? _firestore.collection('users').doc(userId)
          : null;

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
          batch.set(
            userRef,
            {
              'roles': FieldValue.arrayRemove(['leader']),
            },
            SetOptions(merge: true),
          );
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

      final membersSnapshot = await cellRef.collection('members').get();

      if (normalizedNewRole == 'lider' || normalizedNewRole == 'leader') {
        cellUpdates['leaderId'] = actualId;
        if (userRef != null) {
          batch.set(
            userRef,
            {
              'roles': FieldValue.arrayUnion(['leader']),
            },
            SetOptions(merge: true),
          );
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
            if (role == 'anfitriao' ||
                role == 'host' ||
                role == 'anfitrião') {
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
    final currentCellRef = _firestore.collection('cells').doc(currentCellId);
    final currentMemberRef = currentCellRef.collection('members').doc(
      memberId,
    );

    final newCellRef = _firestore.collection('cells').doc(newCellId);
    final newMemberRef = newCellRef.collection('members').doc(memberId);

    final memberDoc = await currentMemberRef.get();
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

    // Atualiza célula e garante que entra na nova célula como 'membro'
    memberData['cellId'] = newCellId;
    memberData['role'] = 'membro';
    memberData['joinedAt'] = FieldValue.serverTimestamp();

    if (actualUserId.isNotEmpty) {
      memberData['userId'] = actualUserId;
    }
    if (memberName.trim().isNotEmpty) {
      memberData['name'] = memberName;
    }

    await _copySubcollections(currentMemberRef, newMemberRef);

    final batch = _firestore.batch();
    batch.set(newMemberRef, memberData);
    batch.delete(currentMemberRef);

    // Limpa atribuição de líder/co-líder/anfitrião da célula anterior
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
}