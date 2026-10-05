import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/cell_join_request_model.dart';
import '../../data/datasources/cell_remote_datasource.dart';

abstract class UserCellOnboardingState {
  const UserCellOnboardingState();
}

class UserCellOnboardingInitialState extends UserCellOnboardingState {}

class UserCellOnboardingLoadingState extends UserCellOnboardingState {}

class UserHasCellState extends UserCellOnboardingState {}

class UserPendingRequestState extends UserCellOnboardingState {
  final CellJoinRequestEntity request;

  const UserPendingRequestState(this.request);
}

class UserNoCellState extends UserCellOnboardingState {}

class UserCellOnboardingErrorState extends UserCellOnboardingState {
  final String message;

  const UserCellOnboardingErrorState(this.message);
}

class UserCellOnboardingController extends ValueNotifier<UserCellOnboardingState> {
  final ICellRemoteDataSource _dataSource;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserCellOnboardingController(this._dataSource)
      : super(UserCellOnboardingInitialState());

  /// Verifica o status do usuário em relação a células
  Future<void> checkUserCellStatus(String userId) async {
    value = UserCellOnboardingLoadingState();
    try {
      // 1. Busca solicitações pendentes
      final pending = await _dataSource.getUserPendingRequest(userId);
      if (pending != null) {
        value = UserPendingRequestState(pending);
        return;
      }

      // 2. Verifica diretamente no documento do usuário no Firestore se possui primaryCellId
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;
          final primaryCellId = data?['primaryCellId'] as String?;
          if (primaryCellId != null && primaryCellId.trim().isNotEmpty) {
            value = UserHasCellState();
            return;
          }
        }
      } catch (_) {
        // Se houver falha na leitura direta, prossegue para a validação por células
      }

      // 3. Fallback: Verifica se já é membro listado em alguma célula
      final cells = await _dataSource.getCells(filterByUserId: userId);
      if (cells.isNotEmpty) {
        value = UserHasCellState();
        return;
      }

      // 4. Caso contrário, realmente não tem célula
      value = UserNoCellState();
    } catch (e) {
      value = UserCellOnboardingErrorState(
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Envia pedido de vínculo para a célula selecionada
  Future<bool> sendJoinRequest({
    required String cellId,
    required String cellName,
    required String userId,
    required String userName,
    String? userPhone,
  }) async {
    try {
      final request = CellJoinRequestEntity(
        id: '',
        cellId: cellId,
        cellName: cellName,
        userId: userId,
        userName: userName,
        userPhone: userPhone,
        status: RequestStatus.pending,
        createdAt: DateTime.now(),
      );

      await _dataSource.requestCellJoin(request);
      await checkUserCellStatus(userId);
      return true;
    } catch (e) {
      value = UserCellOnboardingErrorState(
        e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Cancela a solicitação pendente do usuário
  Future<void> cancelJoinRequest(String requestId, String userId) async {
    try {
      value = UserCellOnboardingLoadingState();

      // 1. Deleta a solicitação no Firestore
      await _dataSource.cancelCellJoinRequest(requestId);

      // 2. Força diretamente o estado de sem célula (evita delay/cache do Firestore)
      value = UserNoCellState();
    } catch (e) {
      value = UserCellOnboardingErrorState(
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}