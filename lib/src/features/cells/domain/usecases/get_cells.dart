import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/domain/repositories/i_cell_repository.dart';

class GetCells {
  final ICellRepository _repository;

  GetCells(this._repository);

  /// Se [filterByUserId] for informado, filtra as células vinculadas àquele usuário.
  /// Caso seja null (visão do Pastor/Coordenador), retorna todas as células.
  Future<List<CellEntity>> call({String? filterByUserId}) async {
    return await _repository.getCells(filterByUserId: filterByUserId);
  }
}
