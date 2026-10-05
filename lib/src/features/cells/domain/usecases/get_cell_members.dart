import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:celulas_app/src/features/cells/domain/repositories/i_cell_repository.dart';

class GetCellMembers {
  final ICellRepository _repository;

  GetCellMembers(this._repository);

  Future<List<CellMemberEntity>> call(String cellId) async {
    if (cellId.isEmpty) {
      throw Exception('ID da célula inválido.');
    }
    return await _repository.getCellMembers(cellId);
  }
}
