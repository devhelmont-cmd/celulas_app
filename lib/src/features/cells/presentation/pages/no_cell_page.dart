// lib/src/features/cells/presentation/pages/no_cell_page.dart

import 'package:flutter/material.dart';

import '../../../../core/injections/injection_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../data/datasources/cell_remote_datasource.dart';
import '../../domain/entities/cell_entity.dart';
import '../controllers/cell_controller.dart';
import '../controllers/cell_state.dart';
import '../controllers/user_cell_onboarding_controller.dart';

class NoCellPage extends StatefulWidget {
  final String userId;
  final String userName;
  final VoidCallback onSuccessRequest;

  const NoCellPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.onSuccessRequest,
  });

  @override
  State<NoCellPage> createState() => _NoCellPageState();
}

class _NoCellPageState extends State<NoCellPage> {
  late CellController _cellController;
  late UserCellOnboardingController _onboardingController;
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String? _fatalError;

  @override
  void initState() {
    super.initState();
    try {
      _cellController = getIt<CellController>();
      _onboardingController = getIt<UserCellOnboardingController>();

      _cellController.fetchCells();
      _searchController.addListener(() {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
        });
      });
    } catch (e) {
      _fatalError = '🚨 ERRO DE INJEÇÃO (GetIt):\n$e\n\nVocê registrou o UserCellOnboardingController no injection_container.dart? Lembre-se de parar o app no Stop e rodar de novo!';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestToJoin(CellEntity cell) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Entrar em ${cell.name}'),
        content: Text('Deseja enviar uma solicitação para a célula ${cell.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar Pedido'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _onboardingController.sendJoinRequest(
        cellId: cell.id,
        cellName: cell.name,
        userId: widget.userId,
        userName: widget.userName,
      );

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitação enviada com sucesso!'), backgroundColor: Colors.green),
        );
        widget.onSuccessRequest();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fatalError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(_fatalError!, style: const TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    final dataSource = getIt<ICellRemoteDataSource>();

    try {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Vincular a uma Célula'),
          actions: [
            IconButton(
              onPressed: () async {
                await getIt<AuthController>().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                }
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade200,
              child: Column(
                children: [
                  const Text('Ainda não pertence a nenhuma célula. Pesquise abaixo:', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome ou bairro...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<CellState>(
                valueListenable: _cellController,
                builder: (context, state, child) {
                  if (state is CellLoadedState) {
                    final cells = state.cells.where((c) {
                      final name = c.name.toString().toLowerCase();
                      final neighborhood = c.neighborhood.toString().toLowerCase();
                      return name.contains(_searchQuery) || neighborhood.contains(_searchQuery);
                    }).toList();

                    cells.sort((a, b) => (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));

                    if (cells.isEmpty) return const Center(child: Text('Nenhuma célula encontrada.'));

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: cells.length,
                      itemBuilder: (context, index) {
                        final cell = cells[index];
                        final isLeaderEmpty = cell.leaderId == null || cell.leaderId!.trim().isEmpty;

                        return Card(
                          key: ValueKey(cell.id),
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cell.name ?? 'Sem Nome',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _requestToJoin(cell),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Theme.of(context).primaryColor),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Solicitar',
                                          style: TextStyle(
                                            color: Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Oculta a linha do líder caso ele não esteja definido
                                if (!isLeaderEmpty) ...[
                                  FutureBuilder<String?>(
                                    future: dataSource.getUserNameById(cell.leaderId!),
                                    builder: (context, snapshot) {
                                      final leaderName = snapshot.data ?? cell.leaderId!;
                                      return Row(
                                        children: [
                                          const Icon(Icons.person, size: 16, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Líder: $leaderName',
                                            style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                ],

                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${cell.address ?? ''} • ${cell.neighborhood ?? ''}',
                                        style: const TextStyle(color: Colors.grey),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${cell.meetingDay ?? ''} às ${cell.meetingTime ?? ''}',
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ],
        ),
      );
    } catch (e, stack) {
      return Scaffold(
        body: SafeArea(
          child: Text('🚨 ERRO NO BUILD:\n$e\n\n$stack', style: const TextStyle(color: Colors.red)),
        ),
      );
    }
  }
}