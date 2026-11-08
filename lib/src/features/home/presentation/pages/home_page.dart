// lib/src/features/home/presentation/pages/home_page.dart

import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/data/models/user_model.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:celulas_app/src/features/auth/presentation/pages/login_page.dart';
import 'package:celulas_app/src/features/cell_reports/presentation/pages/reports_page.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/presentation/pages/cells_list_page.dart';
import 'package:celulas_app/src/features/home/presentation/widgets/leader_dashboard_widget.dart';
import 'package:celulas_app/src/features/home/presentation/widgets/member_dashboard_widget.dart';
import 'package:celulas_app/src/features/home/presentation/widgets/pastor_dashboard_widget.dart';
import 'package:celulas_app/src/features/profile/presentation/pages/fill_profile_page.dart';
import 'package:celulas_app/src/features/profile/presentation/pages/profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final cells = await _cellDataSource.getCells();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.id)
          .get();

      UserEntity updatedUser = _currentUser;
      if (userDoc.exists && userDoc.data() != null) {
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
      if (mounted) setState(() => _isLoadingCells = false);
      debugPrint('Erro ao carregar dados da home: $e');
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
            onRefresh: _loadUserData,
            currentUser: _currentUser,
          ),
          ReportsPage(currentUser: _currentUser),
          ProfilePage(user: _currentUser, onProfileUpdated: _loadUserData)
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
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: _currentUser.photoUrl != null &&
                  _currentUser.photoUrl!.isNotEmpty
                  ? NetworkImage(_currentUser.photoUrl!)
                  : null,
              child: (_currentUser.photoUrl == null ||
                  _currentUser.photoUrl!.isEmpty)
                  ? (_currentUser.name != null &&
                  _currentUser.name!.trim().isNotEmpty)
                  ? Text(
                _currentUser.name!.trim()[0].toUpperCase(),
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
                  'Olá, ${_currentUser.name ?? _currentUser.email.split('@').first}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getUserRoleLabel(_currentUser),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // CARD DE ALERTA SE O PERFIL ESTIVER INCOMPLETO
        if (!_currentUser.isProfileComplete) ...[
          Card(
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.amber.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.amber, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Complete seu Perfil',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.brown,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Preencha seu telefone, data de nascimento e sexo para ajudar no acompanhamento pastoral.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.brown.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _currentIndex = 3),
                    child: const Text('Preencher'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 1. Visão do Pastor / Coordenador
        if (_currentUser.isPastorOrCoordinator) ...[
          PastorDashboardWidget(
            currentUser: _currentUser,
            onNavigateTab: (index, {bool selectPastoralView = false}) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          const SizedBox(height: 20),
        ],

        // 2. Visão do Líder de Célula
        if (_currentUser.isLeader) ...[
          LeaderDashboardWidget(
            user: _currentUser,
            onNavigateToReports: () => setState(() => _currentIndex = 2),
            onNavigateToCells: () => setState(() => _currentIndex = 1),
          ),
          const SizedBox(height: 20),
        ],

        // 3. Visão de Membro
        if (_currentUser.isMember) ...[
          MemberDashboardWidget(user: _currentUser),
        ],
      ],
    );
  }

  String _getUserRoleLabel(UserEntity user) {
    final bool isPastor = user.roles.contains(UserRole.pastor);
    final bool isCoordinator = user.roles.contains(UserRole.coordinator);
    final bool isLeader = user.roles.contains(UserRole.leader);

    if (isPastor && isLeader) return 'Pastor / Líder de Célula';
    if (isCoordinator && isLeader) return 'Coordenador / Líder de Célula';
    if (isPastor) return 'Pastor';
    if (isCoordinator) return 'Coordenador';
    if (isLeader) return 'Líder de Célula';
    return 'Membro';
  }
}