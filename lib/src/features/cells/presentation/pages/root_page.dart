// lib/src/features/cells/presentation/pages/root_page.dart

import 'package:flutter/material.dart';

import '../../../../core/injections/injection_container.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../controllers/user_cell_onboarding_controller.dart';
import 'no_cell_page.dart';
import 'pending_request_page.dart';

class RootPage extends StatefulWidget {
  final UserEntity user;

  const RootPage({super.key, required this.user});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  final _onboardingController = getIt<UserCellOnboardingController>();

  @override
  void initState() {
    super.initState();
    // Sempre verifica o status real no Firestore via controller ao carregar a página
    _onboardingController.checkUserCellStatus(widget.user.id);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Passe livre imediato apenas para Pastor ou Coordenador
    // (O usuário pastor que acabou de logar irá direto para a HomePage)
    if (widget.user.isPastorOrCoordinator) {
      return HomePage(user: widget.user);
    }

    // 2. Para membros e líderes, valida dinamicamente pelo controller consultando o banco
    return ValueListenableBuilder<UserCellOnboardingState>(
      valueListenable: _onboardingController,
      builder: (context, state, child) {
        if (state is UserCellOnboardingInitialState ||
            state is UserCellOnboardingLoadingState) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Se o banco confirmou que o usuário possui célula vinculada
        if (state is UserHasCellState) {
          return HomePage(user: widget.user);
        }

        if (state is UserPendingRequestState) {
          return PendingRequestPage(
            request: state.request,
            onRefresh: () =>
                _onboardingController.checkUserCellStatus(widget.user.id),
            onCancel: () => _onboardingController.cancelJoinRequest(
              state.request.id,
              widget.user.id,
            ),
          );
        }

        if (state is UserNoCellState) {
          return NoCellPage(
            userId: widget.user.id,
            userName: widget.user.name ?? widget.user.email,
            isPastorOrCoordinator: widget.user.isPastorOrCoordinator,
            onSkip: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => HomePage(user: widget.user)),
              );
            },
            onSuccessRequest: () =>
                _onboardingController.checkUserCellStatus(widget.user.id),
          );
        }

        if (state is UserCellOnboardingErrorState) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Ocorreu um erro ao verificar sua célula:\n${state.message}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _onboardingController
                          .checkUserCellStatus(widget.user.id),
                      child: const Text('Tentar Novamente'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}