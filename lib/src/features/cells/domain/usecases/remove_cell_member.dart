import 'package:celulas_app/src/features/cells/domain/repositories/i_cell_repository.dart';

class RemoveCellMember {
  final ICellRepository _repository;

  RemoveCellMember(this._repository);

  Future<void> call({required String memberId, required String cellId}) async {
    await _repository.removeCellMember(memberId, cellId);
  }
}
