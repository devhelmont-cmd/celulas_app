import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:celulas_app/src/features/auth/presentation/pages/login_page.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/presentation/pages/cells_list_page.dart';
import 'package:celulas_app/src/features/home/presentation/widgets/leader_dashboard_widget.dart';
import 'package:celulas_app/src/features/home/presentation/widgets/member_dashboard_widget.dart';
import 'package:celulas_app/src/features/home/presentation/widgets/pastor_dashboard_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../auth/data/models/user_model.dart';

class HomePage extends StatefulWidget {
  final UserEntity user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late final ICellRemoteDataSource _cellDataSource;
  late UserEntity _currentUser;

  List<CellEntity> _cells = [];
  bool _isLoadingCells = true;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _cellDataSource = getIt<ICellRemoteDataSource>();
    _loadCells();
  }

  Future<void> _loadCells() async {
    try {
      final cells = await _cellDataSource.getCells();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.id)
          .get();

      UserEntity updatedUser = _currentUser;
      if (userDoc.exists) {
        updatedUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
      }

      if (mounted) {
        setState(() {
          _cells = cells;
          _currentUser = updatedUser;
          _isLoadingCells = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCells = false;
        });
      }
      debugPrint('Erro ao carregar células: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Células App'),
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
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(context),
          _isLoadingCells
              ? const Center(child: CircularProgressIndicator())
              : CellsListPage(
            cells: _cells,
            onRefresh: _loadCells,
            currentUser: _currentUser,
          ),
          const Center(child: Text('Tela de Relatórios')),
          const Center(child: Text('Perfil')),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Células'),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Relatórios',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Cabeçalho de Identificação
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: widget.user.photoUrl != null &&
                  widget.user.photoUrl!.isNotEmpty
                  ? NetworkImage(widget.user.photoUrl!)
                  : null,
              onBackgroundImageError: widget.user.photoUrl != null &&
                  widget.user.photoUrl!.isNotEmpty
                  ? (exception, stackTrace) {
                debugPrint(
                  'Erro ao carregar foto de perfil: $exception',
                );
              }
                  : null,
              child: (widget.user.photoUrl == null ||
                  widget.user.photoUrl!.isEmpty)
                  ? (widget.user.name != null &&
                  widget.user.name!.trim().isNotEmpty)
                  ? Text(
                widget.user.name!.trim()[0].toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              )
                  : const Icon(Icons.person, size: 28)
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, ${widget.user.name ?? widget.user.email.split('@').first}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getUserRoleLabel(widget.user),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 2. Renderização Condicional por Perfil (Hierárquica)
        if (widget.user.isPastorOrCoordinator) ...[
          const PastorDashboardWidget(),
          const SizedBox(height: 20),
        ],

        if (widget.user.isLeader) ...[
          const LeaderDashboardWidget(),
          const SizedBox(height: 20),
        ],

        if (widget.user.isMember) ...[const MemberDashboardWidget()],
      ],
    );
  }

  String _getUserRoleLabel(UserEntity user) {
    if (user.roles.contains(UserRole.pastor)) return 'Pastor / Coordenador';
    if (user.roles.contains(UserRole.leader)) return 'Líder de Célula';
    return 'Membro';
  }
}