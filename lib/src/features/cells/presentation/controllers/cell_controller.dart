import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/domain/usecases/create_cell.dart';
import 'package:celulas_app/src/features/cells/domain/usecases/get_cells.dart';
import 'package:celulas_app/src/features/cells/presentation/controllers/cell_state.dart';
import 'package:flutter/cupertino.dart';

class CellController extends ValueNotifier<CellState> {
  final GetCells _getCellsUseCase;
  final CreateCell _createCellUseCase;

  List<CellEntity> _cachedCells = [];

  CellController({
    required GetCells getCellsUseCase,
    required CreateCell createCellUseCase,
  }) : _getCellsUseCase = getCellsUseCase,
       _createCellUseCase = createCellUseCase,
       super(const CellInitialState());

  /// Retorna a lista atual em memória para fácil acesso da UI
  List<CellEntity> get cells => _cachedCells;

  /// Carrega as células.
  /// Passar [filterByUserId] filtra as células do líder/membro.
  /// Deixar null carrega todas (visão de Pastor/Coordenador).
  Future<void> fetchCells({String? filterByUserId}) async {
    value = const CellLoadingState();

    try {
      final result = await _getCellsUseCase(filterByUserId: filterByUserId);
      _cachedCells = result;
      value = CellLoadedState(_cachedCells);
    } catch (e) {
      value = CellErrorState(_cleanErrorMessage(e.toString()));
    }
  }

  /// Cadastra uma nova célula e recarrega a listagem
  Future<bool> createCell(CellEntity cell, {String? filterByUserId}) async {
    value = const CellLoadingState();

    try {
      await _createCellUseCase(cell);

      // Recarrega a lista atualizada
      final updateList = await _getCellsUseCase(filterByUserId: filterByUserId);
      _cachedCells = updateList;

      value = const CellOperationSuccessState('Célula criada com sucesso!');
      //Atualiza o estado da UI com a nova lista
      value = CellLoadedState(_cachedCells);
      return true;
    } catch (e) {
      value = CellErrorState(_cleanErrorMessage(e.toString()));
      return false;
    }
  }

  /// Limpa a formatação de 'Exception: ' para exibir na UI
  String _cleanErrorMessage(String rawMessage) {
    return rawMessage.replaceAll('Exception: ', '').replaceAll('Exception', '');
  }
}
