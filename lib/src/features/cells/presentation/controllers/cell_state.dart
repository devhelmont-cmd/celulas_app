import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';

abstract class CellState {
  const CellState();
}

class CellInitialState extends CellState {
  const CellInitialState();
}

class CellLoadingState extends CellState {
  const CellLoadingState();
}

class CellLoadedState extends CellState {
  final List<CellEntity> cells;

  const CellLoadedState(this.cells);
}

class CellOperationSuccessState extends CellState {
  final String message;

  const CellOperationSuccessState(this.message);
}

class CellErrorState extends CellState {
  final String message;

  const CellErrorState(this.message);
}
