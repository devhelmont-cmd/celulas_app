import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:celulas_app/src/features/cells/domain/repositories/i_cell_repository.dart';

class AddCellMember {
  final ICellRepository _repository;

  AddCellMember(this._repository);

  Future<void> call(CellMemberEntity member) async {
    if (member.name.trim().isEmpty) {
      throw Exception('O nome do membro é obrigatório.');
    }
    await _repository.addCellMember(member);
  }
}
