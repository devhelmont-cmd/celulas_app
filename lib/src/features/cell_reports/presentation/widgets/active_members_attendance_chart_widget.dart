// lib/src/features/cell_reports/presentation/widgets/active_members_attendance_chart_widget.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:celulas_app/src/core/utils/pastoral_cycle_helper.dart';
import 'package:celulas_app/src/core/utils/string_utils.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_member_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';
import 'package:celulas_app/src/features/cells/data/models/member_period_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';

class _MemberPeriodStats {
  final CellMemberEntity member;
  final String cellName;
  int presences = 0;
  int justified = 0;
  int unexcused = 0;

  _MemberPeriodStats({
    required this.member,
    required this.cellName,
  });

  int get totalMeetings => presences + justified + unexcused;

  double get attendanceRate =>
      totalMeetings > 0 ? (presences / totalMeetings) * 100.0 : 0.0;
}

class ActiveMembersAttendanceChartWidget extends StatefulWidget {
  final List<CellReportEntity> reports;
  final List<CellMemberEntity> members;
  final List<CellModel> cells;
  final String selectedMonthKey; // Ex: "all" ou "2026-03"
  final String? cellIdFilter; // Filtro opcional por célula específica

  const ActiveMembersAttendanceChartWidget({
    super.key,
    required this.reports,
    required this.members,
    required this.cells,
    required this.selectedMonthKey,
    this.cellIdFilter,
  });

  @override
  State<ActiveMembersAttendanceChartWidget> createState() =>
      _ActiveMembersAttendanceChartWidgetState();
}

class _ActiveMembersAttendanceChartWidgetState
    extends State<ActiveMembersAttendanceChartWidget> {
  bool _isLoadingPeriods = true;
  int _touchedPieIndex = -1;
  bool _showAllMembers = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Mapa de ID do Membro -> Lista de Períodos
  final Map<String, List<MemberPeriodModel>> _memberPeriodsMap = {};
  // Mapa de ID do Membro -> Entidade do Membro (inclui todos os cadastrados)
  final Map<String, CellMemberEntity> _allMembersMap = {};

  @override
  void initState() {
    super.initState();
    _loadMembersAndPeriods();
  }

  @override
  void didUpdateWidget(covariant ActiveMembersAttendanceChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cellIdFilter != widget.cellIdFilter ||
        oldWidget.selectedMonthKey != widget.selectedMonthKey) {
      // Recarrega se houver alteração significativa nos filtros
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Carrega todos os membros e os períodos cadastrados na subcoleção 'periods'
  Future<void> _loadMembersAndPeriods() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Carrega todos os documentos de membros
      final membersSnap = await firestore.collection('members').get();
      for (var doc in membersSnap.docs) {
        final m = CellMemberModel.fromMap(doc.data(), doc.id);
        _allMembersMap[m.id] = m;
        if (m.userId != null && m.userId!.isNotEmpty) {
          _allMembersMap[m.userId!] = m;
        }
      }

      // Adiciona também membros recebidos via widget (para garantir sincronia)
      for (var m in widget.members) {
        _allMembersMap[m.id] = m;
        if (m.userId != null && m.userId!.isNotEmpty) {
          _allMembersMap[m.userId!] = m;
        }
      }

      // 2. Busca todos os períodos cadastrados via collectionGroup('periods')
      final periodsSnap = await firestore.collectionGroup('periods').get();
      for (var doc in periodsSnap.docs) {
        final parentMemberId = doc.reference.parent.parent?.id;
        if (parentMemberId != null && parentMemberId.isNotEmpty) {
          final period = MemberPeriodModel.fromMap(doc.data(), doc.id);
          _memberPeriodsMap.putIfAbsent(parentMemberId, () => []).add(period);
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar períodos dos membros para o gráfico: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPeriods = false);
      }
    }
  }

  /// Verifica se um determinado membro estava ativo na célula em uma data específica
  bool _isMemberActiveInCellOnDate({
    required CellMemberEntity member,
    required String cellId,
    required DateTime date,
  }) {
    final targetDate = DateTime(date.year, date.month, date.day);
    final memberId = member.id;
    final periods = _memberPeriodsMap[memberId] ?? [];

    if (periods.isNotEmpty) {
      for (var p in periods) {
        if (p.cellId != cellId) continue;

        final startOnly =
            DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
        final endOnly = p.endDate != null
            ? DateTime(p.endDate!.year, p.endDate!.month, p.endDate!.day)
            : null;

        if (!targetDate.isBefore(startOnly) &&
            (endOnly == null || !targetDate.isAfter(endOnly))) {
          return true;
        }
      }
      return false;
    }

    // Se não há histórico na subcoleção 'periods', verifica joinedAt e cellId direta
    if (member.cellId == cellId) {
      final joinedOnly = DateTime(
        member.joinedAt.year,
        member.joinedAt.month,
        member.joinedAt.day,
      );
      return !targetDate.isBefore(joinedOnly);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPeriods) {
      return const Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // 1. Filtrar relatórios pelo mês selecionado e célula (desconsidera cancelados)
    List<CellReportEntity> activeReports = widget.reports.where((r) {
      if (r.status == ReportStatus.cacelled) return false;

      if (widget.selectedMonthKey != 'all') {
        final cycleKey = (r.cycleKey != null && r.cycleKey!.isNotEmpty)
            ? r.cycleKey!
            : PastoralCycleHelper.getCycleKeyString(r.scheduledDate);
        if (!cycleKey.startsWith(widget.selectedMonthKey)) return false;
      }

      if (widget.cellIdFilter != null && widget.cellIdFilter!.isNotEmpty) {
        if (r.cellId != widget.cellIdFilter) return false;
      }

      return true;
    }).toList();

    if (activeReports.isEmpty) {
      return const Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'Nenhum relatório de reunião realizada encontrado no período.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // Mapeamento de nomes de células
    final Map<String, String> cellNameMap = {
      for (var c in widget.cells) c.id: c.name
    };

    // 2. Acumuladores globais e por membro
    int totalPresences = 0;
    int totalJustified = 0;
    int totalUnexcused = 0;

    // Garante lista única de membros para iterar
    final uniqueMembers = _allMembersMap.values.toSet().toList();
    final Map<String, _MemberPeriodStats> statsByMember = {};

    for (var report in activeReports) {
      final reportDate = report.scheduledDate;
      final reportCellId = report.cellId;

      for (var member in uniqueMembers) {
        final isActiveInCell = _isMemberActiveInCellOnDate(
          member: member,
          cellId: reportCellId,
          date: reportDate,
        );

        if (!isActiveInCell) continue;

        final cellName =
            member.cellName ?? cellNameMap[reportCellId] ?? 'Célula';
        final stats = statsByMember.putIfAbsent(
          member.id,
          () => _MemberPeriodStats(member: member, cellName: cellName),
        );

        // Procura chamada do membro neste relatório
        final attendance = report.attendances.cast<AttendanceEntity?>().firstWhere(
          (att) =>
              att?.cellMemberId == member.id ||
              (member.userId != null &&
                  member.userId!.isNotEmpty &&
                  att?.cellMemberId == member.userId),
          orElse: () => null,
        );

        if (attendance != null) {
          if (attendance.isPresent) {
            totalPresences++;
            stats.presences++;
          } else if (attendance.isJustificationApproved) {
            totalJustified++;
            stats.justified++;
          } else {
            totalUnexcused++;
            stats.unexcused++;
          }
        } else {
          // Membro ativo na data sem registro explícito = falta
          totalUnexcused++;
          stats.unexcused++;
        }
      }
    }

    final int totalOccurrences =
        totalPresences + totalJustified + totalUnexcused;

    if (totalOccurrences == 0) {
      return const Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'Nenhuma chamada registrada para os membros ativos nos períodos selecionados.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // 3. Preparar lista ordenada de membros por assiduidade
    List<_MemberPeriodStats> memberStatsList =
        statsByMember.values.where((s) => s.totalMeetings > 0).toList();

    memberStatsList.sort((a, b) {
      final rateComp = b.attendanceRate.compareTo(a.attendanceRate);
      if (rateComp != 0) return rateComp;
      return a.member.name.compareToNormalized(b.member.name);
    });

    // Filtro de busca simples
    List<_MemberPeriodStats> displayedStats = memberStatsList;
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.normalizeSearch();
      displayedStats = memberStatsList.where((s) {
        return s.member.name.normalizeSearch().contains(query) ||
            s.cellName.normalizeSearch().contains(query);
      }).toList();
    }

    final double presencePercentage = (totalPresences / totalOccurrences) * 100.0;
    final double justifiedPercentage = (totalJustified / totalOccurrences) * 100.0;
    final double unexcusedPercentage = (totalUnexcused / totalOccurrences) * 100.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título e Subtítulo
            const Text(
              'Assiduidade dos Membros nas Células',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Volume consolidado de presenças vs faltas considerando os períodos ativos dos membros.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Cartões de Resumo Consolidado
            Row(
              children: [
                _buildSummaryStatCard(
                  'Presença Real',
                  '${presencePercentage.toStringAsFixed(0)}%',
                  Colors.green,
                  Icons.check_circle_outline,
                ),
                const SizedBox(width: 8),
                _buildSummaryStatCard(
                  'Justificadas',
                  '${justifiedPercentage.toStringAsFixed(0)}%',
                  Colors.orange,
                  Icons.info_outline,
                ),
                const SizedBox(width: 8),
                _buildSummaryStatCard(
                  'Faltas',
                  '${unexcusedPercentage.toStringAsFixed(0)}%',
                  Colors.red,
                  Icons.cancel_outlined,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Gráfico de Pizza (PieChart)
            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedPieIndex = -1;
                              return;
                            }
                            _touchedPieIndex = pieTouchResponse
                                .touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 3,
                      centerSpaceRadius: 45,
                      sections: _buildPieChartSections(
                        totalPresences: totalPresences,
                        totalJustified: totalJustified,
                        totalUnexcused: totalUnexcused,
                        totalOccurrences: totalOccurrences,
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${presencePercentage.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Text(
                          'Presença',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Legendas Detalhadas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendBadge(
                  'Presenças',
                  '$totalPresences',
                  '${presencePercentage.toStringAsFixed(1)}%',
                  Colors.green,
                ),
                _buildLegendBadge(
                  'Justificadas',
                  '$totalJustified',
                  '${justifiedPercentage.toStringAsFixed(1)}%',
                  Colors.orange,
                ),
                _buildLegendBadge(
                  'Faltas',
                  '$totalUnexcused',
                  '${unexcusedPercentage.toStringAsFixed(1)}%',
                  Colors.red,
                ),
              ],
            ),
            const Divider(height: 32),

            // Ranking e Detalhamento de Membros
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detalhamento por Membro',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${displayedStats.length} membro(s)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Campo de Busca
            if (memberStatsList.length > 5) ...[
              SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Buscar membro...',
                    hintStyle:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blueAccent),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Lista de Membros
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _showAllMembers
                  ? displayedStats.length
                  : (displayedStats.length > 5 ? 5 : displayedStats.length),
              itemBuilder: (context, index) {
                final stat = displayedStats[index];
                final double progress =
                    (stat.attendanceRate / 100.0).clamp(0.0, 1.0);
                final Color rateColor = _getRateColor(stat.attendanceRate);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    stat.member.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    stat.cellName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              Text(
                                '${stat.presences}P / ${stat.justified}J / ${stat.unexcused}F',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: rateColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${stat.attendanceRate.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: rateColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Botão Ver Mais / Ver Menos
            if (displayedStats.length > 5) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAllMembers = !_showAllMembers;
                    });
                  },
                  icon: Icon(
                    _showAllMembers
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                  ),
                  label: Text(
                    _showAllMembers
                        ? 'Mostrar menos'
                        : 'Ver todos os ${displayedStats.length} membros',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections({
    required int totalPresences,
    required int totalJustified,
    required int totalUnexcused,
    required int totalOccurrences,
  }) {
    final List<PieChartSectionData> sections = [];

    if (totalOccurrences == 0) return sections;

    // Presenças (Verde)
    if (totalPresences > 0) {
      final isTouched = _touchedPieIndex == 0;
      final radius = isTouched ? 45.0 : 38.0;
      final percentage = (totalPresences / totalOccurrences) * 100.0;
      sections.add(
        PieChartSectionData(
          color: Colors.green,
          value: totalPresences.toDouble(),
          title: '${percentage.toStringAsFixed(0)}%',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: isTouched ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    // Justificadas (Laranja)
    if (totalJustified > 0) {
      final isTouched = _touchedPieIndex == 1;
      final radius = isTouched ? 45.0 : 38.0;
      final percentage = (totalJustified / totalOccurrences) * 100.0;
      sections.add(
        PieChartSectionData(
          color: Colors.orange,
          value: totalJustified.toDouble(),
          title: '${percentage.toStringAsFixed(0)}%',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: isTouched ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    // Faltas (Vermelho)
    if (totalUnexcused > 0) {
      final isTouched = _touchedPieIndex == 2;
      final radius = isTouched ? 45.0 : 38.0;
      final percentage = (totalUnexcused / totalOccurrences) * 100.0;
      sections.add(
        PieChartSectionData(
          color: Colors.red,
          value: totalUnexcused.toDouble(),
          title: '${percentage.toStringAsFixed(0)}%',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: isTouched ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return sections;
  }

  Color _getRateColor(double rate) {
    if (rate >= 75.0) return Colors.green;
    if (rate >= 50.0) return Colors.orange;
    return Colors.red;
  }

  Widget _buildSummaryStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendBadge(
    String label,
    String count,
    String percentage,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label: $count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              percentage,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }
}
