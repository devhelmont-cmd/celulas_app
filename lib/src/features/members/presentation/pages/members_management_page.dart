import 'package:flutter/material.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cells/data/models/unlinked_user_or_member_model.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/core/injections/injection_container.dart';

class MembersManagementPage extends StatefulWidget {
  final UserEntity currentUser;
  final bool initialFilterWithoutCell;

  const MembersManagementPage({
    super.key,
    required this.currentUser,
    this.initialFilterWithoutCell = false,
  });

  @override
  State<MembersManagementPage> createState() => _MembersManagementPageState();
}

class _MembersManagementPageState extends State<MembersManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dataSource = getIt<ICellRemoteDataSource>();

  List<UnlinkedUserOrMember> _unlinkedList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialFilterWithoutCell ? 1 : 0,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final unlinked = await _dataSource.getUsersAndMembersWithoutCell();
      if (mounted) {
        setState(() {
          _unlinkedList = unlinked;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciamento de Membros'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Todos os Membros'),
            Tab(text: 'Sem Célula / Avulsos'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  const Center(
                    child: Text('Lista Geral de Membros e Frequência'),
                  ),
                  _buildUnlinkedTab(),
                ],
              ),
    );
  }

  Widget _buildUnlinkedTab() {
    if (_unlinkedList.isEmpty) {
      return const Center(child: Text('Nenhuma pessoa sem célula encontrada.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _unlinkedList.length,
      itemBuilder: (context, index) {
        final item = _unlinkedList[index];
        final isUser = item.isRegisteredUser;

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isUser ? Colors.blue.shade100 : Colors.grey.shade200,
              child: Icon(isUser ? Icons.person : Icons.person_outline),
            ),
            title: Text(item.name),
            subtitle: Text(
              isUser
                  ? 'Usuário com conta (${item.email ?? "sem e-mail"})'
                  : 'Membro sem conta',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'link_cell') _assignToCell(item);
                if (val == 'link_member') _linkUserToMember(item);
                if (val == 'delete') _deleteMember(item);
              },
              itemBuilder:
                  (context) => [
                    if (isUser)
                      const PopupMenuItem(
                        value: 'link_member',
                        child: Text('Vincular a Membro Existente'),
                      ),
                    const PopupMenuItem(
                      value: 'link_cell',
                      child: Text('Vincular a uma Célula'),
                    ),
                    if (!isUser)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Excluir do Sistema',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _assignToCell(UnlinkedUserOrMember item) async {
    // Diálogo para escolher a célula de destino
  }

  Future<void> _linkUserToMember(UnlinkedUserOrMember item) async {
    // Exibe diálogo com membros sem conta para fundir registros
  }

  Future<void> _deleteMember(UnlinkedUserOrMember item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Excluir Membro'),
            content: Text(
              'Deseja excluir ${item.name} permanentemente do sistema?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Excluir',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      // Executa exclusão no Firestore e recarrega a lista
      await _loadData();
    }
  }
}
