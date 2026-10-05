import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/domain/repositories/i_cell_repository.dart';

class CreateCell {
  final ICellRepository _repository;

  CreateCell(this._repository);

  Future<void> call(CellEntity cell) async {
    // Aqui podemos inserir validações de regra de negócio no futuro
    // Ex: verificar se o nome da célula já existe, se os campos obrigatórios estão preenchidos, etc.
    if (cell.name.trim().isEmpty) {
      throw Exception('O nome da célula não pode ser vazio.');
    }

    await _repository.createCell(cell);
  }
}
