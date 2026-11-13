// lib/src/features/cell_reports/presentation/widgets/member_analytics_widget.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/core/utils/pastoral_cycle_helper.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../members/presentation/pages/member_analysis_page.dart';

class _CellHistoryJourney {
  final String cellId;
  final String cellName;
  final DateTime startDate;
  final DateTime? endDate; // null se for a célula atual ativa
  final bool isCurrent;

  _CellHistoryJourney({
    required this.cellId,
    required this.cellName,
    required this.startDate,
    this.endDate,
    this.isCurrent = false,
  });
}

class MemberAnalyticsWidget extends StatefulWidget {
  final UserEntity currentUser; // Membro cujo perfil está sendo analisado
  final UserEntity? viewerUser; // Quem está visualizando
  final bool isEmbedded;
  final bool showAvatar;
  final bool enableTapToAnalyze;

  const MemberAnalyticsWidget({
    super.key,
    required this.currentUser,
    this.viewerUser,
    this.isEmbedded = false,
    this.showAvatar = true,
    this.enableTapToAnalyze = false,
  });

  @override
  State<MemberAnalyticsWidget> createState() => _MemberAnalyticsWidgetState();
}

class _MemberAnalyticsWidgetState extends State<MemberAnalyticsWidget> {
  late final ICellReportsRepository _reportsRepository;
  late final ICellRemoteDataSource _cellDataSource;

  bool _isLoading = true;
  CellMemberEntity? _currentMember;
  List<CellReportEntity> _allMemberReports = [];
  List<_CellHistoryJourney> _cellJourneys = [];
  String? _currentCellId;
  String? _currentCellName;
  String? _memberPhotoUrl;

  String _selectedCellId = 'all'; // 'all' = Histórico Geral
  String _selectedMonthKey = 'all';

  @override
  void initState() {
    super.initState();
    _reportsRepository = getIt<ICellReportsRepository>();
    _cellDataSource = getIt<ICellRemoteDataSource>();
    _loadMemberAnalyticsData();
  }

  Future<void> _loadMemberAnalyticsData() async {
    setState(() => _isLoading = true);
    try {
      final user = widget.currentUser;
      String? targetCellId = user.primaryCellId;

      final allCells = await _cellDataSource.getCells(currentUser: user);
      final Map<String, String> cellNamesById = {
        for (var c in allCells) c.id: c.name,
      };

      // Busca o registro atual em members (mesmo se estiver sem célula no momento)
      CellMemberEntity? foundMember;
      final allGlobalMembers = await _cellDataSource.getAllMembers();

      for (var gm in allGlobalMembers) {
        final gmId = gm['id']?.toString() ?? '';
        final gmUserId = gm['userId']?.toString() ?? '';
        final gmName = gm['name']?.toString() ?? '';

        bool matchesId = gmId == user.id ||
            (gmUserId.isNotEmpty && gmUserId == user.id);
        bool matchesName = user.name != null &&
            gmName.trim().toLowerCase() == user.name!.trim().toLowerCase();

        if (matchesId || matchesName) {
          final cellId = gm['cellId']?.toString() ?? '';
          if (targetCellId == null || targetCellId.isEmpty) {
            targetCellId = cellId.isNotEmpty ? cellId : null;
          }
          foundMember = CellMemberEntity(
            id: gmId,
            cellId: cellId,
            userId: gmUserId.isNotEmpty ? gmUserId : null,
            name: gmName,
            role: gm['role']?.toString() ?? 'membro',
            joinedAt: (gm['joinedAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            cellName: cellNamesById[cellId],
            photoUrl: gm['photoUrl']?.toString(),
          );
          break;
        }
      }

      // Se não achou na lista global, tenta na célula primária
      if (foundMember == null &&
          targetCellId != null &&
          targetCellId
              .trim()
              .isNotEmpty) {
        final members = await _cellDataSource.getCellMembers(targetCellId);
        try {
          foundMember = members.firstWhere(
                (m) =>
            m.id == user.id ||
                m.userId == user.id ||
                (user.name != null &&
                    m.name.trim().toLowerCase() ==
                        user.name!.trim().toLowerCase()),
          );
        } catch (_) {}
      }

      // Busca foto se ainda não tiver
      String? fetchedPhotoUrl = foundMember?.photoUrl;
      final effectiveUserId = foundMember?.userId ?? user.id;
      if (effectiveUserId.isNotEmpty &&
          (fetchedPhotoUrl == null || fetchedPhotoUrl.isEmpty)) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(effectiveUserId)
              .get();
          if (userDoc.exists) {
            fetchedPhotoUrl = userDoc.data()?['photoUrl'] as String?;
          }
        } catch (_) {}
      }

      // Busca TODOS os relatórios do sistema para reconstruir o histórico completo do membro
      final allReportsInSystem = await _reportsRepository.getAllReports();
      final Set<String> candidateIds = {
        user.id,
        if (foundMember != null) foundMember.id,
        if (foundMember?.userId != null && foundMember!.userId!.isNotEmpty)
          foundMember!.userId!,
      };

      // Filtra relatórios onde o membro participou ou esteve listado na frequência
      final List<CellReportEntity> memberReports = [];
      for (var report in allReportsInSystem) {
        final hasRecord = report.attendances.any(
              (a) => candidateIds.contains(a.cellMemberId),
        );
        if (hasRecord) {
          memberReports.add(report);
        }
      }

      // Ordena cronologicamente (do mais antigo para o mais recente)
      memberReports.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

      // Reconstrói a linha do tempo de células do membro
      final List<_CellHistoryJourney> journeys = [];
      final Map<String, List<DateTime>> datesByCell = {};
      final List<String> orderedCellIds = [];

      for (var report in memberReports) {
        if (!datesByCell.containsKey(report.cellId)) {
          datesByCell[report.cellId] = [];
          orderedCellIds.add(report.cellId);
        }
        datesByCell[report.cellId]!.add(
          DateTime(
            report.scheduledDate.year,
            report.scheduledDate.month,
            report.scheduledDate.day,
          ),
        );
      }

      // Garante que a célula atual esteja na lista mesmo antes do primeiro relatório nela
      if (targetCellId != null &&
          targetCellId.isNotEmpty &&
          !datesByCell.containsKey(targetCellId)) {
        orderedCellIds.add(targetCellId);
        datesByCell[targetCellId] = [
          foundMember != null
              ? DateTime(
            foundMember.joinedAt.year,
            foundMember.joinedAt.month,
            foundMember.joinedAt.day,
          )
              : DateTime.now(),
        ];
      }

      for (int i = 0; i < orderedCellIds.length; i++) {
        final cId = orderedCellIds[i];
        final dates = datesByCell[cId]!
          ..sort();
        final isCurrentCell = (cId == targetCellId);

        DateTime start = dates.first;
        if (i == 0 && foundMember != null) {
          final joinedOnly = DateTime(
            foundMember.joinedAt.year,
            foundMember.joinedAt.month,
            foundMember.joinedAt.day,
          );
          if (joinedOnly.isBefore(start)) {
            start = joinedOnly;
          }
        }

        DateTime? end;
        if (!isCurrentCell) {
          // Se não é a célula atual, a data final é a última reunião registrada nessa célula
          // ou um dia antes de iniciar na próxima célula
          if (i + 1 < orderedCellIds.length) {
            final nextStart = datesByCell[orderedCellIds[i + 1]]!.first;
            end = nextStart.isAfter(dates.last)
                ? nextStart.subtract(const Duration(days: 1))
                : dates.last;
          } else {
            end = dates.last;
          }
        }

        String cName = cellNamesById[cId] ?? '';
        if (cName.isEmpty) {
          try {
            final cEntity = await _cellDataSource.getCellById(cId);
            cName = cEntity.name;
            cellNamesById[cId] = cName;
          } catch (_) {
            cName = 'Célula Anterior';
          }
        }

        journeys.add(
          _CellHistoryJourney(
            cellId: cId,
            cellName: cName,
            startDate: start,
            endDate: end,
            isCurrent: isCurrentCell,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _currentCellId = targetCellId;
          _currentCellName =
          targetCellId != null ? cellNamesById[targetCellId] : null;
          _currentMember = foundMember;
          _memberPhotoUrl = fetchedPhotoUrl;
          _allMemberReports = memberReports;
          _cellJourneys = journeys;
          _selectedCellId = 'all'; // Inicia sempre no Histórico Geral
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Erro ao carregar analíticos do membro: $e');
    }
  }

  List<CellReportEntity> _getReportsForSelectedCell() {
    if (_selectedCellId == 'all') {
      return _allMemberReports;
    }
    return _allMemberReports
        .where((r) => r.cellId == _selectedCellId)
        .toList();
  }

  List<Map<String, String>> _getAvailableMonths(
      List<CellReportEntity> sourceReports) {
    final Set<String> monthKeys = {};

    for (var r in sourceReports) {
      final cycleKey = (r.cycleKey != null && r.cycleKey!.isNotEmpty)
          ? r.cycleKey!
          : PastoralCycleHelper.getCycleKeyString(r.scheduledDate);

      if (cycleKey.length >= 7) {
        monthKeys.add(cycleKey.substring(0, 7));
      }
    }

    final sortedKeys = monthKeys.toList()
      ..sort((a, b) => b.compareTo(a));
    final List<Map<String, String>> result = [
      {'key': 'all', 'label': 'Todos os Períodos'},
    ];

    for (var key in sortedKeys) {
      final parts = key.split('-');
      if (parts.length >= 2) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final date = DateTime(year, month, 1);

        String monthName = DateFormat("MMMM 'de' yyyy", 'pt_BR').format(date);
        monthName = monthName[0].toUpperCase() + monthName.substring(1);

        result.add({'key': key, 'label': monthName});
      }
    }

    return result;
  }

  String _formatShortDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentMember == null && _allMemberReports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Nenhum histórico de participação encontrado para este membro.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
          ),
        ),
      );
    }

    final loggedUserId = widget.viewerUser?.id;
    final targetUserId = widget.currentUser.id;
    final bool isViewingSelf =
        loggedUserId == null || loggedUserId == targetUserId;

    final memberName =
        _currentMember?.name ?? widget.currentUser.name ?? 'Membro';
    final firstName = memberName
        .split(' ')
        .first;

    final jornadaTitle = _selectedCellId == 'all'
        ? 'Histórico Geral'
        : 'Jornada na Célula';

    final jornadaSubtitle = isViewingSelf
        ? 'Acompanhe sua frequência e participações.'
        : 'Acompanhe a frequência e participações de $firstName.';

    final cooperacaoTitle = isViewingSelf
        ? 'Minha Cooperação em Servir'
        : 'Cooperação de $firstName em Servir';

    // Reports filtrados pela célula selecionada
    final cellScopedReports = _getReportsForSelectedCell();
    final availableMonths = _getAvailableMonths(cellScopedReports);

    final activeMonthKey =
    availableMonths.any((m) => m['key'] == _selectedMonthKey)
        ? _selectedMonthKey
        : 'all';

    // Data de início efetiva considerando o histórico global ou a célula selecionada
    DateTime? effectiveStartDate;
    if (_selectedCellId != 'all') {
      final journey = _cellJourneys.cast<_CellHistoryJourney?>().firstWhere(
            (j) => j != null && j.cellId == _selectedCellId,
        orElse: () => null,
      );
      effectiveStartDate = journey?.startDate;
    } else if (_cellJourneys.isNotEmpty) {
      effectiveStartDate = _cellJourneys.first.startDate;
    } else if (_currentMember != null) {
      effectiveStartDate = DateTime(
        _currentMember!.joinedAt.year,
        _currentMember!.joinedAt.month,
        _currentMember!.joinedAt.day,
      );
    }

    List<CellReportEntity> filteredReports = cellScopedReports;
    if (activeMonthKey != 'all') {
      filteredReports = cellScopedReports.where((r) {
        final cycleKey = (r.cycleKey != null && r.cycleKey!.isNotEmpty)
            ? r.cycleKey!
            : PastoralCycleHelper.getCycleKeyString(r.scheduledDate);
        return cycleKey.startsWith(activeMonthKey);
      }).toList();
    }

    final Set<String> candidateIds = {
      widget.currentUser.id,
      if (_currentMember != null) _currentMember!.id,
      if (_currentMember?.userId != null &&
          _currentMember!.userId!.isNotEmpty)
        _currentMember!.userId!,
    };

    int totalValidMeetingsHeld = 0;
    int presences = 0;
    int justifiedAbsences = 0;
    final Map<String, int> rolesCountMap = {};

    for (var report in filteredReports) {
      if (report.status == ReportStatus.cacelled) continue;

      final meetingDateOnly = DateTime(
        report.scheduledDate.year,
        report.scheduledDate.month,
        report.scheduledDate.day,
      );

      if (effectiveStartDate != null &&
          meetingDateOnly.isBefore(effectiveStartDate)) {
        continue;
      }

      final attendance = report.attendances
          .cast<AttendanceEntity?>()
          .firstWhere(
            (a) => a != null && candidateIds.contains(a.cellMemberId),
        orElse: () => null,
      );

      if (attendance != null) {
        totalValidMeetingsHeld++;
        if (attendance.isPresent) {
          presences++;
          for (var role in attendance.rolesPerformed) {
            rolesCountMap[role] = (rolesCountMap[role] ?? 0) + 1;
          }
        } else if (attendance.isJustified) {
          justifiedAbsences++;
        }
      }
    }

    double attendanceRate = totalValidMeetingsHeld > 0
        ? (presences / totalValidMeetingsHeld) * 100
        : 0.0;

    // Texto de período da jornada (Início -> Fim/Atual)
    String periodRangeLabel = '';
    if (_selectedCellId == 'all' && _cellJourneys.isNotEmpty) {
      final firstStart = _formatShortDate(_cellJourneys.first.startDate);
      final hasActiveCell = _currentCellId != null &&
          _currentCellId!.isNotEmpty;
      final endLabel = hasActiveCell
          ? 'Atual'
          : (_cellJourneys.last.endDate != null
          ? _formatShortDate(_cellJourneys.last.endDate!)
          : 'Atual');
      periodRangeLabel = 'Período no Sistema: $firstStart até $endLabel';
    } else if (_selectedCellId != 'all') {
      final journey = _cellJourneys.cast<_CellHistoryJourney?>().firstWhere(
            (j) => j != null && j.cellId == _selectedCellId,
        orElse: () => null,
      );
      if (journey != null) {
        final startStr = _formatShortDate(journey.startDate);
        final endStr = journey.isCurrent
            ? 'Atual'
            : (journey.endDate != null
            ? _formatShortDate(journey.endDate!)
            : 'Atual');
        periodRangeLabel = 'Período na Célula: $startStr até $endStr';
      }
    }

    final listViewContent = ListView(
      shrinkWrap: widget.isEmbedded,
      physics: widget.isEmbedded ? const NeverScrollableScrollPhysics() : null,
      padding: widget.isEmbedded ? EdgeInsets.zero : const EdgeInsets.all(16),
      children: [
        InkWell(
          onTap: widget.enableTapToAnalyze
              ? () {
            final memberMap = {
              'userId': _currentMember?.userId,
              'id': _currentMember?.id ?? widget.currentUser.id,
              'name': memberName,
              'cellId': _currentCellId ?? widget.currentUser.primaryCellId,
              'photoUrl': _memberPhotoUrl,
              'role': _currentMember?.role ?? 'membro',
            };
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MemberAnalysisPage(
                      memberData: memberMap,
                      currentUser: widget.viewerUser ?? widget.currentUser,
                    ),
              ),
            );
          }
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                if (widget.showAvatar) ...[
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: (_memberPhotoUrl != null &&
                        _memberPhotoUrl!.trim().isNotEmpty)
                        ? CachedNetworkImageProvider(_memberPhotoUrl!)
                        : null,
                    child: (_memberPhotoUrl == null ||
                        _memberPhotoUrl!.trim().isEmpty)
                        ? Text(
                      memberName.isNotEmpty
                          ? memberName[0].toUpperCase()
                          : 'M',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    )
                        : null,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jornadaTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (_currentCellName != null &&
                          _currentCellName!.isNotEmpty)
                        Text(
                          'Célula Atual: $_currentCellName',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          jornadaSubtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 12),

        // FILTROS DE TRAJETÓRIA (CÉLULA + PERÍODO MENSAL)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_cellJourneys.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCellId,
                    icon: const Icon(
                      Icons.account_tree_outlined,
                      size: 16,
                      color: Colors.indigo,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'all',
                        child: Text('Histórico Geral (Todas as Células)'),
                      ),
                      ..._cellJourneys.map((j) {
                        final badge = j.isCurrent ? ' (Atual)' : ' (Anterior)';
                        return DropdownMenuItem<String>(
                          value: j.cellId,
                          child: Text('${j.cellName}$badge'),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCellId = val;
                          _selectedMonthKey = 'all';
                        });
                      }
                    },
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: activeMonthKey,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.blueAccent,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                  items: availableMonths.map((item) {
                    return DropdownMenuItem<String>(
                      value: item['key'],
                      child: Text(item['label']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedMonthKey = val);
                    }
                  },
                ),
              ),
            ),
          ],
        ),

        // BANNER DO PERÍODO NA TRAJETÓRIA / CÉLULA
        if (periodRangeLabel.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.history_edu, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    periodRangeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
        Row(
          children: [
            _buildMetricCard(
              'Frequência',
              '${attendanceRate.toStringAsFixed(0)}%',
              Icons.pie_chart_outline,
              Colors.blue,
            ),
            const SizedBox(width: 12),
            _buildMetricCard(
              'Presenças',
              '$presences/$totalValidMeetingsHeld',
              Icons.check_circle_outline,
              Colors.green,
            ),
            const SizedBox(width: 12),
            _buildMetricCard(
              'Justificadas',
              '$justifiedAbsences',
              Icons.info_outline,
              Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.volunteer_activism,
                      color: Colors.purple,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      cooperacaoTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (rolesCountMap.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      'Nenhuma função registrada no período selecionado.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: rolesCountMap.entries.map((entry) {
                      return Chip(
                        avatar: CircleAvatar(
                          backgroundColor: Colors.purple.shade100,
                          child: Text(
                            '${entry.value}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade900,
                            ),
                          ),
                        ),
                        label: Text(entry.key),
                        backgroundColor: Colors.purple.shade50,
                        side: BorderSide(color: Colors.purple.shade200),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return listViewContent;
    }

    return RefreshIndicator(
      onRefresh: _loadMemberAnalyticsData,
      child: listViewContent,
    );
  }

  Widget _buildMetricCard(String title,
      String value,
      IconData icon,
      Color color,) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}