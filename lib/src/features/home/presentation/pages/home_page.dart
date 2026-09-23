import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:celulas_app/src/features/auth/presentation/pages/login_page.dart';
import 'package:celulas_app/src/features/home/presentation/widgets/leader_dashboard_widget.dart';
import 'package:celulas_app/src/features/home/presentation/widgets/member_dashboard_widget.dart';
import 'package:celulas_app/src/features/home/presentation/widgets/pastor_dashboard_widget.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  final UserEntity user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

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
          const Center(child: Text('Tela de Céluas')),
          const Center(child: Text('Tela de Relatórios')),
          const Center(child: Text('Perfil')),
        ],
      ),
      floatingActionButton:
          widget.user.isPastorOrCoordinator
              ? FloatingActionButton.extended(
                onPressed: () {},
                label: const Text('Nova Célula'),
                icon: const Icon(Icons.add),
              )
              : null,
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
        //1. Cabecalho de Identificacao
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage:
                  widget.user.photoUrl != null
                      ? NetworkImage(widget.user.photoUrl!)
                      : null,
              child:
                  widget.user.photoUrl == null
                      ? const Icon(Icons.person, size: 28)
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

        //2. Renderizacao Condicional por Perfil (Hierarquica)
        if (widget.user.isPastorOrCoordinator) ...[
          const PastorDashboardWidget(),
          const SizedBox(height: 20),
        ],

        if (widget.user.isLeader) ...[
          const LeaderDashboardWidget(),
          const SizedBox(height: 20),
        ],

        //Todos usuario ve a secao de membro da sua propria celula
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
