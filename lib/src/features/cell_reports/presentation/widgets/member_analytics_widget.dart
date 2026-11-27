// lib/src/features/cell_reports/presentation/widgets/member_analytics_widget.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/core/utils/pastoral_cycle_helper.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cell_reports/domain/entities/cell_report_entity.dart';
import 'package:celulas_app/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/member_period_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:celulas_app/src/features/cells/domain/entities/member_period_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'member_absence_justification_dialog.dart';
import '../../../members/presentation/pages/member_analysis_page.dart';

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
  List<MemberPeriodEntity> _memberPeriods = [];
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

  @override
  void didUpdateWidget(covariant MemberAnalyticsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.id != widget.currentUser.id ||
        oldWidget.currentUser.name != widget.currentUser.name) {
      debugPrint(
        'MemberAnalyticsWidget: Membro alterado no dropdown (${widget.currentUser.name}), recarregando...',
      );
      _loadMemberAnalyticsData();
    }
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Verifica se a data de uma reunião pertence a algum período registrado do membro naquela célula
  bool _isDateWithinPeriods(
    DateTime meetingDate,
    String cellId,
    List<MemberPeriodEntity> periods,
  ) {
    final targetDate = _dateOnly(meetingDate);
    final cellPeriods = periods.where((p) => p.cellId == cellId);

    if (cellPeriods.isEmpty) return false;

    for (final period in cellPeriods) {
      final start = _dateOnly(period.startDate);
      final end = period.endDate != null ? _dateOnly(period.endDate!) : null;

      final afterOrEqualStart = !targetDate.isBefore(start);
      final beforeOrEqualEnd = end == null || !targetDate.isAfter(end);

      if (afterOrEqualStart && beforeOrEqualEnd) {
        return true;
      }
    }
    return false;
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

      // 1. Busca direta no Firestore na coleção 'members'
      CellMemberEntity? foundMember;
      final membersSnap =
          await FirebaseFirestore.instance.collection('members').get();

      final normalizedTargetName = user.name?.trim().toLowerCase() ?? '';

      for (var doc in membersSnap.docs) {
        final gm = doc.data();
        final gmId = doc.id;
        final gmUserId = gm['userId']?.toString() ?? '';
        final gmName = gm['name']?.toString() ?? '';
        final normalizedGmName = gmName.trim().toLowerCase();

        final bool matchesId =
            gmId == user.id || (gmUserId.isNotEmpty && gmUserId == user.id);
        final bool matchesName =
            normalizedTargetName.isNotEmpty &&
            normalizedGmName == normalizedTargetName;

        if (matchesId || matchesName) {
          final cellId = gm['cellId']?.toString() ?? '';
          if (targetCellId == null || targetCellId.isEmpty) {
            targetCellId = cellId.isNotEmpty ? cellId : null;
          }
          foundMember = CellMemberEntity(
            id: gmId,
            cellId: cellId,
            userId: gmUserId.isNotEmpty ? gmUserId : null,
            name: gmName.isNotEmpty ? gmName : (user.name ?? 'Membro'),
            role: gm['role']?.toString() ?? 'membro',
            joinedAt:
                (gm['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            cellName: cellNamesById[cellId],
            photoUrl: gm['photoUrl']?.toString(),
          );
          break;
        }
      }

      // Fallback robusto: se não achar na coleção members por ID ou Nome, cria a entidade baseada no user atual
      if (foundMember == null) {
        foundMember = CellMemberEntity(
          id: user.id,
          cellId: user.primaryCellId ?? '',
          userId: user.id,
          name: user.name ?? 'Membro',
          role: 'membro',
          joinedAt: DateTime.now(),
          cellName: targetCellId != null ? cellNamesById[targetCellId] : null,
          photoUrl: user.photoUrl,
        );
      }

      // 2. Busca foto se ainda não tiver
      String? fetchedPhotoUrl = foundMember.photoUrl ?? user.photoUrl;
      final effectiveUserId = foundMember.userId ?? user.id;
      if (effectiveUserId.isNotEmpty &&
          (fetchedPhotoUrl == null || fetchedPhotoUrl.isEmpty)) {
        try {
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(effectiveUserId)
                  .get();
          if (userDoc.exists) {
            fetchedPhotoUrl = userDoc.data()?['photoUrl'] as String?;
          }
        } catch (_) {}
      }

      // 3. Busca os períodos reais na subcoleção members/{memberId}/periods
      List<MemberPeriodEntity> loadedPeriods = [];
      String memberDocId = foundMember?.id ?? user.id;

      try {
        // Removi a trava de length > 10 para ser mais flexível
        if (memberDocId.isNotEmpty && !memberDocId.startsWith('legacy_')) {
          final periodsSnapshot = await FirebaseFirestore.instance
              .collection('members')
              .doc(memberDocId)
              .collection('periods')
              .get();

          loadedPeriods = periodsSnapshot.docs
              .map((doc) => MemberPeriodModel.fromMap(doc.data(), doc.id))
              .toList()
            ..sort((a, b) => a.startDate.compareTo(b.startDate));

          debugPrint('Analytics: Carregados ${loadedPeriods.length} períodos para o membro $memberDocId');
        }
      } catch (e) {
        debugPrint('Erro ao buscar períodos: $e');
      }

      // 4. Busca relatórios baseados no histórico de períodos ou registros explícitos
      final allReportsInSystem = await _reportsRepository.getAllReports();
      final List<CellReportEntity> memberReports = [];

      for (var report in allReportsInSystem) {
        // A: O membro está na lista de presença? (Presença confirmada ou Falta registrada)
        final hasExplicitRecord = report.attendances.any((a) {
          final matchesId = a.cellMemberId == user.id || a.cellMemberId == memberDocId;
          final matchesName = normalizedTargetName.isNotEmpty &&
              a.memberName?.trim().toLowerCase() == normalizedTargetName;
          return matchesId || matchesName;
        });

        // B: A reunião ocorreu durante um período ativo do membro nesta célula?
        // Isso é o que gera a "Falta Automática" (0/1)
        final isWithinMemberHistory = _isDateWithinPeriods(
            report.scheduledDate,
            report.cellId,
            loadedPeriods
        );

        if (hasExplicitRecord || isWithinMemberHistory) {
          memberReports.add(report);
        }
        if (isWithinMemberHistory) {
          print("Reunião de ${report.scheduledDate} incluída pelo histórico do período!");
        }
      }

      memberReports.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

      // 5. Fallback para membros que ainda não têm documentos na subcoleção periods
      if (loadedPeriods.isEmpty) {
        final Map<String, List<DateTime>> datesByCell = {};
        final List<String> orderedCellIds = [];

        for (var report in memberReports) {
          if (!datesByCell.containsKey(report.cellId)) {
            datesByCell[report.cellId] = [];
            orderedCellIds.add(report.cellId);
          }
          datesByCell[report.cellId]!.add(_dateOnly(report.scheduledDate));
        }

        if (targetCellId != null &&
            targetCellId.isNotEmpty &&
            !datesByCell.containsKey(targetCellId)) {
          orderedCellIds.add(targetCellId);
          datesByCell[targetCellId] = [
            foundMember != null
                ? _dateOnly(foundMember.joinedAt)
                : _dateOnly(DateTime.now()),
          ];
        }

        for (int i = 0; i < orderedCellIds.length; i++) {
          final cId = orderedCellIds[i];
          final dates = datesByCell[cId]!..sort();
          final isCurrentCell = (cId == targetCellId);

          DateTime start =
              dates.isNotEmpty ? dates.first : _dateOnly(foundMember.joinedAt);
          if (i == 0 && foundMember != null) {
            final joinedOnly = _dateOnly(foundMember.joinedAt);
            if (joinedOnly.isBefore(start)) {
              start = joinedOnly;
            }
          }

          DateTime? end;
          if (!isCurrentCell && dates.isNotEmpty) {
            if (i + 1 < orderedCellIds.length) {
              final nextStart = datesByCell[orderedCellIds[i + 1]]!.first;
              end =
                  nextStart.isAfter(dates.last)
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

          loadedPeriods.add(
            MemberPeriodEntity(
              id: 'legacy_$cId',
              cellId: cId,
              cellName: cName,
              startDate: start,
              endDate: end,
              role: isCurrentCell ? (foundMember?.role ?? 'membro') : 'membro',
            ),
          );
        }
      } else {
        for (int i = 0; i < loadedPeriods.length; i++) {
          final p = loadedPeriods[i];
          if (p.cellName.isEmpty) {
            String resolvedName = cellNamesById[p.cellId] ?? '';
            if (resolvedName.isEmpty) {
              try {
                final cEntity = await _cellDataSource.getCellById(p.cellId);
                resolvedName = cEntity.name;
                cellNamesById[p.cellId] = resolvedName;
              } catch (_) {
                resolvedName = 'Célula Anterior';
              }
            }
            loadedPeriods[i] = MemberPeriodEntity(
              id: p.id,
              cellId: p.cellId,
              cellName: resolvedName,
              startDate: p.startDate,
              endDate: p.endDate,
              role: p.role,
            );
          }
        }
      }

      final activePeriod = loadedPeriods.cast<MemberPeriodEntity?>().firstWhere(
        (p) => p != null && p.isActive,
        orElse: () => null,
      );

      final resolvedCurrentCellId = activePeriod?.cellId ?? targetCellId;
      final resolvedCurrentCellName =
          activePeriod?.cellName ??
          (resolvedCurrentCellId != null
              ? cellNamesById[resolvedCurrentCellId]
              : null);

      if (mounted) {
        setState(() {
          _currentCellId = resolvedCurrentCellId;
          _currentCellName = resolvedCurrentCellName;
          _currentMember = foundMember;
          _memberPhotoUrl = fetchedPhotoUrl;
          _allMemberReports = memberReports;
          _memberPeriods = loadedPeriods;
          _selectedCellId = 'all';
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('=== ERRO EM _loadMemberAnalyticsData ===');
      debugPrint('$e');
      debugPrint('$stack');
      if (mounted) {
        setState(() {
          _currentMember = CellMemberEntity(
            id: widget.currentUser.id,
            cellId: widget.currentUser.primaryCellId ?? '',
            userId: widget.currentUser.id,
            name: widget.currentUser.name ?? 'Membro',
            role: 'membro',
            joinedAt: DateTime.now(),
          );
          _isLoading = false;
        });
      }
    }
  }

  List<CellReportEntity> _getReportsForSelectedCell() {
    if (_selectedCellId == 'all') {
      return _allMemberReports;
    }
    return _allMemberReports.where((r) => r.cellId == _selectedCellId).toList();
  }

  List<Map<String, String>> _getAvailableMonths(
    List<CellReportEntity> sourceReports,
  ) {
    final Set<String> monthKeys = {};

    for (var r in sourceReports) {
      final cycleKey =
          (r.cycleKey != null && r.cycleKey!.isNotEmpty)
              ? r.cycleKey!
              : PastoralCycleHelper.getCycleKeyString(r.scheduledDate);

      if (cycleKey.length >= 7) {
        monthKeys.add(cycleKey.substring(0, 7));
      }
    }

    final sortedKeys = monthKeys.toList()..sort((a, b) => b.compareTo(a));
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

  /// Agrupa células distintas presentes nos períodos do membro para popular o Dropdown
  List<Map<String, dynamic>> _getDistinctCellOptions() {
    final Map<String, Map<String, dynamic>> uniqueCells = {};

    for (final period in _memberPeriods) {
      if (!uniqueCells.containsKey(period.cellId)) {
        uniqueCells[period.cellId] = {
          'cellId': period.cellId,
          'cellName': period.cellName,
          'isActive': period.isActive,
        };
      } else if (period.isActive) {
        uniqueCells[period.cellId]!['isActive'] = true;
      }
    }

    return uniqueCells.values.toList();
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
    final firstName = memberName.split(' ').first;

    final jornadaTitle =
        _selectedCellId == 'all' ? 'Histórico Geral' : 'Jornada na Célula';

    final jornadaSubtitle =
        isViewingSelf
            ? 'Acompanhe sua frequência e participações.'
            : 'Acompanhe a frequência e participações de $firstName.';

    final cooperacaoTitle =
        isViewingSelf
            ? 'Minha Cooperação em Servir'
            : 'Cooperação de $firstName em Servir';

    // Reports filtrados pela célula selecionada
    final cellScopedReports = _getReportsForSelectedCell();
    final availableMonths = _getAvailableMonths(cellScopedReports);

    final activeMonthKey =
        availableMonths.any((m) => m['key'] == _selectedMonthKey)
            ? _selectedMonthKey
            : 'all';

    final filteredReports = _getReportsForSelectedCell();

    int totalValidMeetingsHeld = 0;
    int presences = 0;
    int justifiedAbsences = 0;
    final Map<String, int> rolesCountMap = {};

    final Set<String> candidateIds = {
      widget.currentUser.id,
      if (_currentMember != null) _currentMember!.id,
      if (_currentMember?.userId != null && _currentMember!.userId!.isNotEmpty)
        _currentMember!.userId!,
    };
    final normalizedTargetName = widget.currentUser.name?.trim().toLowerCase() ?? '';

    for (var report in filteredReports) {
      if (report.status == ReportStatus.cacelled) continue;

      // 1. Verifica se a reunião pertence ao histórico do membro (Período)
      final bool isWithinMemberHistory = _memberPeriods.isNotEmpty &&
          _isDateWithinPeriods(
            report.scheduledDate,
            report.cellId,
            _memberPeriods,
          );

      // 2. Busca o registro de presença (se existir)
      // Usamos cast para evitar o erro de tipo no orElse
      final attendance = report.attendances
          .cast<AttendanceEntity?>()
          .firstWhere(
            (a) => a != null && (
            candidateIds.contains(a.cellMemberId) ||
                (normalizedTargetName.isNotEmpty &&
                    a.memberName?.trim().toLowerCase() == normalizedTargetName)
        ),
        orElse: () => null,
      );

      // 3. LÓGICA DE CONTABILIZAÇÃO:
      // Se ele tem um registro explícito OU se a reunião era obrigatória pelo período dele
      if (attendance != null || isWithinMemberHistory) {
        totalValidMeetingsHeld++; // Aqui garante o "1" do "0/1"

        if (attendance != null) {
          if (attendance.isPresent) {
            presences++;
            for (var role in attendance.rolesPerformed) {
              rolesCountMap[role] = (rolesCountMap[role] ?? 0) + 1;
            }
          } else if (attendance.isJustificationApproved) {
            justifiedAbsences++;
          }
        }
        // Se attendance for null mas isWithinMemberHistory for true,
        // ele entra no totalValidMeetingsHeld mas não incrementa presences (FALTA).
      }
    }

    double attendanceRate = totalValidMeetingsHeld > 0
        ? (presences / totalValidMeetingsHeld) * 100
        : 0.0;

    // Texto de período da jornada (Início -> Fim/Atual) baseado nos MemberPeriods
    String periodRangeLabel = '';
    if (_selectedCellId == 'all' && _memberPeriods.isNotEmpty) {
      final firstStart = _formatShortDate(_memberPeriods.first.startDate);
      final hasActivePeriod = _memberPeriods.any((p) => p.isActive);
      final endLabel =
          hasActivePeriod
              ? 'Atual'
              : (_memberPeriods.last.endDate != null
                  ? _formatShortDate(_memberPeriods.last.endDate!)
                  : 'Atual');
      periodRangeLabel = 'Período no Sistema: $firstStart até $endLabel';
    } else if (_selectedCellId != 'all') {
      final periodsForCell =
          _memberPeriods.where((p) => p.cellId == _selectedCellId).toList();
      if (periodsForCell.isNotEmpty) {
        final ranges = periodsForCell
            .map((p) {
              final startStr = _formatShortDate(p.startDate);
              final endStr =
                  p.isActive ? 'Atual' : _formatShortDate(p.endDate!);
              return '$startStr até $endStr';
            })
            .join(' • ');
        periodRangeLabel = 'Período na Célula: $ranges';
      }
    }

    final distinctCells = _getDistinctCellOptions();

    final listViewContent = ListView(
      shrinkWrap: widget.isEmbedded,
      physics: widget.isEmbedded ? const NeverScrollableScrollPhysics() : null,
      padding: widget.isEmbedded ? EdgeInsets.zero : const EdgeInsets.all(16),
      children: [
        InkWell(
          onTap:
              widget.enableTapToAnalyze
                  ? () {
                    final memberMap = {
                      'userId': _currentMember?.userId,
                      'id': _currentMember?.id ?? widget.currentUser.id,
                      'name': memberName,
                      'cellId':
                          _currentCellId ?? widget.currentUser.primaryCellId,
                      'photoUrl': _memberPhotoUrl,
                      'role': _currentMember?.role ?? 'membro',
                    };
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => MemberAnalysisPage(
                              memberData: memberMap,
                              currentUser:
                                  widget.viewerUser ?? widget.currentUser,
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
                    backgroundImage:
                        (_memberPhotoUrl != null &&
                                _memberPhotoUrl!.trim().isNotEmpty)
                            ? CachedNetworkImageProvider(_memberPhotoUrl!)
                            : null,
                    child:
                        (_memberPhotoUrl == null ||
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
            if (distinctCells.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
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
                      ...distinctCells.map((cellOpt) {
                        final badge =
                            cellOpt['isActive'] == true
                                ? ' (Atual)'
                                : ' (Anterior)';
                        return DropdownMenuItem<String>(
                          value: cellOpt['cellId'] as String,
                          child: Text('${cellOpt['cellName']}$badge'),
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
                  items:
                      availableMonths.map((item) {
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
        if (widget.viewerUser == null ||
            widget.viewerUser!.id == widget.currentUser.id) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                MemberAbsenceJustificationDialog.show(
                  context,
                  currentUser: widget.currentUser,
                  cellId: _currentCellId,
                );
              },
              icon: const Icon(Icons.event_busy_outlined),
              label: const Text('Gerenciar Faltas e Justificativas'),
            ),
          ),
        ],
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
                    children:
                        rolesCountMap.entries.map((entry) {
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

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
