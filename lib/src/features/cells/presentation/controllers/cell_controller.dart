import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/domain/usecases/create_cell.dart';
import 'package:celulas_app/src/features/cells/domain/usecases/get_cells.dart';
import 'package:celulas_app/src/features/cells/presentation/controllers/cell_state.dart';
import 'package:flutter/cupertino.dart';

class CellController extends ValueNotifier<CellState> {
  final GetCells _getCellsUseCase;
  final CreateCell _createCellUseCase;
  final ICellRemoteDataSource _dataSource;

  List<CellEntity> _cachedCells = [];

  CellController({
    required GetCells getCellsUseCase,
    required CreateCell createCellUseCase,
    required ICellRemoteDataSource dataSource,
  }) : _getCellsUseCase = getCellsUseCase,
        _createCellUseCase = createCellUseCase,
        _dataSource = dataSource,
        super(const CellInitialState());

  List<CellEntity> get cells => _cachedCells;

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

  Future<bool> createCell(CellEntity cell, {String? filterByUserId}) async {
    value = const CellLoadingState();

    try {
      await _createCellUseCase(cell);
      final updateList = await _getCellsUseCase(
        filterByUserId: filterByUserId,
      );
      _cachedCells = updateList;

      value = const CellOperationSuccessState('Célula criada com sucesso!');
      value = CellLoadedState(_cachedCells);
      return true;
    } catch (e) {
      value = CellErrorState(_cleanErrorMessage(e.toString()));
      return false;
    }
  }

  Future<bool> updateCell(CellEntity cell, {String? filterByUserId}) async {
    value = const CellLoadingState();
    try {
      final cellModel =
      cell is CellEntity ? (cell as dynamic).toModel() : cell;
      await _dataSource.updateCell(cellModel);
      await fetchCells(filterByUserId: filterByUserId);
      return true;
    } catch (e) {
      value = CellErrorState(_cleanErrorMessage(e.toString()));
      return false;
    }
  }

  Future<bool> deleteCell(String cellId, {String? filterByUserId}) async {
    value = const CellLoadingState();
    try {
      await _dataSource.deleteCell(cellId);
      await fetchCells(filterByUserId: filterByUserId);
      return true;
    } catch (e) {
      value = CellErrorState(_cleanErrorMessage(e.toString()));
      return false;
    }
  }

  Future<bool> toggleCellStatus(
      String cellId,
      bool isActive, {
        String? filterByUserId,
      }) async {
    value = const CellLoadingState();
    try {
      await _dataSource.toggleCellStatus(cellId, isActive);
      await fetchCells(filterByUserId: filterByUserId);
      return true;
    } catch (e) {
      value = CellErrorState(_cleanErrorMessage(e.toString()));
      return false;
    }
  }

  String _cleanErrorMessage(String rawMessage) {
    return rawMessage.replaceAll('Exception: ', '').replaceAll('Exception', '');
  }
}