import 'package:cached_network_image/cached_network_image.dart';
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
      ]);

      final allMembers = results[0] as List<Map<String, dynamic>>;
      final allCells = results[1] as List<CellModel>;

      final cellMap = <String, String>{};
      for (var cell in allCells) {
        cellMap[cell.id] = cell.name ?? 'Sem Nome';
      }

      final withCell = <Map<String, dynamic>>[];
      final withoutCell = <Map<String, dynamic>>[];

      for (var member in allMembers) {
        final cellId = (member['cellId'] ?? member['primaryCellId']) as String?;
        final hasCell =
            cellId != null && cellId.trim().isNotEmpty && cellId != 'null';

        if (hasCell) {
          withCell.add(member);
        } else {
          withoutCell.add(member);
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
                    photoUrl != null && photoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(photoUrl)
                        : null,
                child:
                    (photoUrl == null || photoUrl.isEmpty)
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
