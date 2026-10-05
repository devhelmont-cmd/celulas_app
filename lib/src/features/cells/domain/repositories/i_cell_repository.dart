import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';

abstract class ICellRepository {
  // ================= CÉLULAS =================
  /// Retorna as células baseadas no nível de acesso.
  /// Um pastor vê todas, um líder/membro vê as suas.
  Future<List<CellEntity>> getCells({String? filterByUserId});

  Stream<List<CellEntity>> watchCells({String? filterByUserId});

  Future<CellEntity> getCellById(String id);

  Future<void> createCell(CellEntity cell);

  Future<void> updateCell(CellEntity cell);

  // ================= MEMBROS =================
  /// Busca membros de uma célula específica
  Future<List<CellMemberEntity>> getCellMembers(String cellId);

  Stream<List<CellMemberEntity>> watchCellMembers(String cellId);

  /// Adiciona um membro (com ou sem app)
  Future<void> addCellMember(CellMemberEntity member);

  Future<void> updateCellMember(CellMemberEntity member);

  Future<void> removeCellMember(String memberId, String cellId);

  /// Migra um membro "fantasma" para um usuário real do App,
  /// mantendo o mesmo CellMemberEntity e o histórico.
  Future<void> linkMemberToUserAccount({
    required String cellId,
    required String memberId,
    required String newUserId,
  });
}
