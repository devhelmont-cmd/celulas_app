// lib/src/features/members/presentation/pages/members_management_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';
import 'package:celulas_app/src/features/members/presentation/pages/member_analysis_page.dart';

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
  final _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _membersWithCell = [];
  List<Map<String, dynamic>> _membersWithoutCell = [];
  Map<String, String> _cellNamesMap = {};
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
      final results = await Future.wait([
        _dataSource.getAllMembers(),
        _dataSource.getCells(currentUser: widget.currentUser),
        _firestore.collection('users').get(),
      ]);

      final rawMembers = results[0] as List<Map<String, dynamic>>;
      final allCells = results[1] as List<CellModel>;
      final usersSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;

      // Mapeia dados dos usuários por ID para enriquecimento rápido
      final usersMap = <String, Map<String, dynamic>>{};
      for (var doc in usersSnap.docs) {
        usersMap[doc.id] = doc.data();
      }

      final cellMap = <String, String>{};
      for (var cell in allCells) {
        cellMap[cell.id] = cell.name ?? 'Sem Nome';
      }

      final withCell = <Map<String, dynamic>>[];
      final withoutCell = <Map<String, dynamic>>[];

      for (var member in rawMembers) {
        final mergedMember = Map<String, dynamic>.from(member);
        final userId = mergedMember['userId'] as String?;

        // Enriquece foto e telefone se o usuário possuir perfil em 'users'
        if (userId != null && usersMap.containsKey(userId)) {
          final uData = usersMap[userId]!;
          if ((mergedMember['photoUrl'] == null ||
                  (mergedMember['photoUrl'] as String).isEmpty) &&
              uData['photoUrl'] != null) {
            mergedMember['photoUrl'] = uData['photoUrl'];
          }
          if (uData['phone'] != null || uData['whatsapp'] != null) {
            mergedMember['phone'] = uData['phone'] ?? uData['whatsapp'];
          }
        }

        final cellId =
            (mergedMember['cellId'] ?? mergedMember['primaryCellId'])
                as String?;
        final hasCell =
            cellId != null && cellId.trim().isNotEmpty && cellId != 'null';

        if (hasCell) {
          withCell.add(mergedMember);
        } else {
          withoutCell.add(mergedMember);
        }
      }

      if (mounted) {
        setState(() {
          _membersWithCell = withCell;
          _membersWithoutCell = withoutCell;
          _cellNamesMap = cellMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Erro ao carregar dados de membros: $e');
    }
  }

  void _navigateToMemberAnalysis(Map<String, dynamic> memberData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => MemberAnalysisPage(
              memberData: memberData,
              currentUser: widget.currentUser,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciamento de Membros'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Com Célula'),
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
                  _buildMemberList(_membersWithCell, isLinked: true),
                  _buildMemberList(_membersWithoutCell, isLinked: false),
                ],
              ),
    );
  }

  Widget _buildMemberList(
    List<Map<String, dynamic>> members, {
    required bool isLinked,
  }) {
    if (members.isEmpty) {
      return Center(
        child: Text(
          isLinked
              ? 'Nenhum membro vinculado a célula.'
              : 'Nenhuma pessoa sem célula cadastrada.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: members.length,
        itemBuilder: (context, index) {
          final member = members[index];
          final name = member['name'] ?? 'Sem Nome';
          final photoUrl = member['photoUrl'] as String?;
          final cellId =
              (member['cellId'] ?? member['primaryCellId']) as String?;
          final cellName =
              (cellId != null && _cellNamesMap.containsKey(cellId))
                  ? _cellNamesMap[cellId]
                  : 'Sem Célula';

          // Verifica se possui conta vinculada no sistema (userId válido)
          final userId = member['userId'] as String?;
          final hasAccount = userId != null && userId.trim().isNotEmpty;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              onTap: () => _navigateToMemberAnalysis(member),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade200,
                backgroundImage:
                    (photoUrl != null && photoUrl.trim().isNotEmpty)
                        ? CachedNetworkImageProvider(photoUrl)
                        : null,
                child:
                    (photoUrl == null || photoUrl.trim().isNotEmpty == false)
                        ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                        : null,
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        isLinked
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        size: 14,
                        color: isLinked ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isLinked ? 'Célula: $cellName' : 'Sem célula atribuída',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isLinked
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        hasAccount
                            ? Icons.person_outline
                            : Icons.person_off_outlined,
                        size: 14,
                        color: hasAccount ? Colors.indigo : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasAccount
                            ? 'Com conta no sistema'
                            : 'Sem conta no sistema',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              hasAccount
                                  ? Colors.indigo.shade700
                                  : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}
