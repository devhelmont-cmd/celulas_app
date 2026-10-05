import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:celulas_app/src/features/cells/domain/repositories/i_cell_repository.dart';

import '../models/cell_member_model.dart';

class CellRepositoryImpl implements ICellRepository {
  final ICellRemoteDataSource _dataSource;

  CellRepositoryImpl(this._dataSource);

  // ================= CÉLULAS =================
  Future<List<CellEntity>> getCells({String? filterByUserId}) async {
    return await _dataSource.getCells(filterByUserId: filterByUserId);
  }

  Stream<List<CellEntity>> watchCells({String? filterByUserId}) {
    return _dataSource.watchCells(filterByUserId: filterByUserId);
  }

  Future<CellEntity> getCellById(String id) async {
    return await _dataSource.getCellById(id);
  }

  Future<void> createCell(CellEntity cell) async {
    await _dataSource.createCell(CellModel.fromEntity(cell));
  }

  Future<void> updateCell(CellEntity cell) async {
    await _dataSource.updateCell(CellModel.fromEntity(cell));
  }

  // ================= MEMBROS =================
  Future<List<CellMemberEntity>> getCellMembers(String cellId) async {
    return await _dataSource.getCellMembers(cellId);
  }

  Stream<List<CellMemberEntity>> watchCellMembers(String cellId) {
    return _dataSource.watchCellMembers(cellId);
  }

  Future<void> addCellMember(CellMemberEntity member) async {
    await _dataSource.addCellMember(CellMemberModel.fromEntity(member));
  }

  Future<void> updateCellMember(CellMemberEntity member) async {
    await _dataSource.updateCellMember(CellMemberModel.fromEntity(member));
  }

  Future<void> removeCellMember(String memberId, String cellId) async {
    await _dataSource.removeCellMember(memberId, cellId);
  }

  Future<void> linkMemberToUserAccount({
    required String cellId,
    required String memberId,
    required String newUserId,
  }) async {
    await _dataSource.linkMemberToUserAccount(
      cellId: cellId,
      memberId: memberId,
      newUserId: newUserId,
    );
  }
}
