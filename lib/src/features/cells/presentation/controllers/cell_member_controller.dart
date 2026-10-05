import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:celulas_app/src/features/cells/domain/usecases/get_cell_members.dart';
import 'package:celulas_app/src/features/cells/domain/usecases/remove_cell_member.dart';
import 'package:flutter/foundation.dart';

import '../../domain/usecases/add_cell_member.dart';

abstract class CellMemberState {
  const CellMemberState();
}

class CellMemberInitialState extends CellMemberState {}

class CellMemberLoadingState extends CellMemberState {}

class CellMemberLoadedState extends CellMemberState {
  final List<CellMemberEntity> members;

  const CellMemberLoadedState(this.members);
}

class CellMemberErrorState extends CellMemberState {
  final String message;

  const CellMemberErrorState(this.message);
}

class CellMembersController extends ValueNotifier<CellMemberState> {
  final GetCellMembers _getCellMembers;
  final AddCellMember _addCellMember;
  final RemoveCellMember _removeCellMember;

  List<CellMemberEntity> _members = [];

  CellMembersController({
    required GetCellMembers getCellMembers,
    required AddCellMember addCellMember,
    required RemoveCellMember removeCellMember,
  }) : _getCellMembers = getCellMembers,
       _addCellMember = addCellMember,
       _removeCellMember = removeCellMember,
       super(CellMemberInitialState());

  List<CellMemberEntity> get members => _members;

  Future<void> fetchMembers(String cellId) async {
    value = CellMemberLoadingState();
    try {
      _members = await _getCellMembers(cellId);
      value = CellMemberLoadedState(_members);
    } catch (e) {
      value = CellMemberErrorState(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<bool> addMember(CellMemberEntity member) async {
    try {
      await _addCellMember(member);
      await fetchMembers(member.cellId);
      return true;
    } catch (e) {
      value = CellMemberErrorState(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> removeMember(String memberId, String cellId) async {
    try {
      await _removeCellMember(memberId: memberId, cellId: cellId);
      await fetchMembers(cellId);
    } catch (e) {
      value = CellMemberErrorState(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
