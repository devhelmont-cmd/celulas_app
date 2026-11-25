// lib/src/features/cell_reports/presentation/widgets/multiplication_analytics_widget.dart

import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_meeting_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_model.dart';
import 'package:celulas_app/src/features/cells/data/models/cell_multiplication_progress_model.dart';
import 'package:celulas_app/src/features/cells/data/models/multiplication_settings_model.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_member_entity.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'multiplication_settings_dialog.dart';

class MultiplicationAnalyticsWidget extends StatefulWidget {
  const MultiplicationAnalyticsWidget({super.key});

  @override
  State<MultiplicationAnalyticsWidget> createState() =>
      _MultiplicationAnalyticsWidgetState();
}

class _MultiplicationAnalyticsWidgetState
    extends State<MultiplicationAnalyticsWidget> {
  bool _isLoading = true;
  MultiplicationSettingsModel _settings = const MultiplicationSettingsModel();
  List<CellMultiplicationProgressModel> _progressList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dataSource = getIt<ICellRemoteDataSource>();
      final reportsRepo = getIt<ICellReportsRepository>();

      final settings = await dataSource.getMultiplicationSettings();
      final cells = await dataSource.getCells();
      cells.sort((a, b) => a.name.compareTo(b.name));

      List<CellMultiplicationProgressModel> progressList = [];

      for (var cell in cells) {
        List<CellMemberEntity> members = [];
        try {
          members = await dataSource.getCellMembers(cell.id);
        } catch (_) {}

        List<dynamic> reports = [];
        try {
          reports = await reportsRepo.getReportsByCell(cell.id);
        } catch (_) {}

        List<CellMeetingModel> meetings = [];
        try {
          meetings = await dataSource.getAllMeetingsForCell(cell.id);
        } catch (_) {}

        final progress = CellMultiplicationProgressModel.calculate(
          cell: cell,
          members: members,
          reports: reports.map((r) => r as dynamic).toList().cast(),
          meetings: meetings,
          settings: settings,
        );

        progressList.add(progress);
      }

      // Ordena por maior percentual de progresso
      progressList.sort((a, b) => b.overallPercentage.compareTo(a.overallPercentage));

      if (mounted) {
        setState(() {
          _settings = settings;
          _progressList = progressList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados de multiplicação: $e')),
        );
      }
    }
  }

  Future<void> _openSettings() async {
    final updated = await showDialog<MultiplicationSettingsModel>(
      context: context,
      builder: (ctx) => MultiplicationSettingsDialog(initialSettings: _settings),
    );

    if (updated != null) {
      final dataSource = getIt<ICellRemoteDataSource>();
      await dataSource.saveMultiplicationSettings(updated);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parâmetros globais atualizados com sucesso!')),
        );
      }
    }
  }

  Future<void> _openIndividualCellGoalsDialog(CellMultiplicationProgressModel progress) async {
    final targetMembersController = TextEditingController(
      text: (progress.cell.customTargetMembers ?? progress.settings.targetMembers).toString(),
    );
    final targetMonthsController = TextEditingController(
      text: (progress.cell.customTargetMonths ?? progress.settings.targetMonths).toString(),
    );
    final minAttendanceController = TextEditingController(
      text: (progress.cell.customMinAttendancePercentage ?? progress.settings.minAttendancePercentage).toString(),
    );
    final minVisitorController = TextEditingController(
      text: (progress.cell.customMinVisitorAverage ?? progress.settings.minVisitorAverage).toString(),
    );
    bool futureHostDefined = progress.cell.futureHostDefined;
    DateTime? customStartDate = progress.cell.customMultiplicationStartDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final effectiveDefaultStartDate = progress.settings.multiplicationStartDate ?? progress.cell.createdAt;
            final defaultLabel = progress.settings.multiplicationStartDate != null
                ? 'Herdando da Rede (${DateFormat('dd/MM/yyyy').format(progress.settings.multiplicationStartDate!)})'
                : 'Herdando da Célula (${DateFormat('dd/MM/yyyy').format(progress.cell.createdAt)})';

            return AlertDialog(
              title: Text('Metas Individuais: ${progress.cell.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: targetMembersController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Meta de Membros', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetMonthsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Prazo Alvo (Meses)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final initial = customStartDate ?? effectiveDefaultStartDate;
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          locale: const Locale('pt', 'BR'),
                        );
                        if (picked != null) {
                          setDialogState(() => customStartDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Data de Início da Contagem',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          suffixIcon: customStartDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () => setDialogState(() => customStartDate = null),
                                  tooltip: 'Limpar (Herdar data)',
                                )
                              : null,
                        ),
                        child: Text(
                          customStartDate != null
                              ? DateFormat('dd/MM/yyyy').format(customStartDate!)
                              : defaultLabel,
                          style: TextStyle(
                            color: customStartDate != null ? Colors.black87 : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minAttendanceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Assiduidade Mínima (%)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minVisitorController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Média Mínima de Visitantes', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Futuro Anfitrião / Local Definido'),
                      value: futureHostDefined,
                      onChanged: (val) => setDialogState(() => futureHostDefined = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Salvar Metas')),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      try {
        final customMembers = int.tryParse(targetMembersController.text);
        final customMonths = int.tryParse(targetMonthsController.text);
        final customAttendance = double.tryParse(minAttendanceController.text);
        final customVisitor = double.tryParse(minVisitorController.text);

        final updatedCell = progress.cell.copyWith(
          futureHostDefined: futureHostDefined,
          customTargetMembers: customMembers,
          customTargetMonths: customMonths,
          customMinAttendancePercentage: customAttendance,
          customMinVisitorAverage: customVisitor,
          customMultiplicationStartDate: customStartDate,
          clearCustomMultiplicationStartDate: customStartDate == null,
        );

        final dataSource = getIt<ICellRemoteDataSource>();
        await dataSource.updateCell(updatedCell);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Metas individuais atualizadas com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao atualizar metas: $e')),
          );
        }
      }
    }
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

    final readyCount = _progressList.where((p) => p.isReadyForMultiplication).length;
    final averagePct = _progressList.isNotEmpty
        ? _progressList.fold<double>(0.0, (sum, p) => sum + p.overallPercentage) /
            _progressList.length
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho / Resumo
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Visão Geral de Multiplicação',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Configurar Parâmetros',
              onPressed: _openSettings,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Cards de Resumo da Rede
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Prontas',
                value: '$readyCount',
                subtitle: 'Células aptas',
                color: Colors.green,
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'Média da Rede',
                value: '${averagePct.toStringAsFixed(1)}%',
                subtitle: 'Progresso geral',
                color: Colors.blue,
                icon: Icons.analytics_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        const Text(
          'Ranking de Prontidão das Células',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Toque em uma célula para ver o detalhamento dos critérios de multiplicação.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        if (_progressList.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('Nenhuma célula cadastrada.'),
            ),
          )
        else
          ..._progressList.map((progress) => _buildCellProgressCard(progress)),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Card(
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
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildCellProgressCard(CellMultiplicationProgressModel progress) {
    final color = progress.isReadyForMultiplication
        ? Colors.green
        : progress.overallPercentage >= 70
            ? Colors.orange
            : Colors.red;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                progress.cell.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (progress.isReadyForMultiplication)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: const Text(
                  'Apta!',
                  style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progresso Geral: ${progress.overallPercentage.toStringAsFixed(1)}%'),
                  Text('${progress.metCriteriaCount} / ${progress.totalCriteria} metas'),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (progress.overallPercentage / 100.0).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                color: color,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Divider(),
                const SizedBox(height: 8),
                _buildCriterionRow(
                  title: 'Membros da Célula',
                  current: '${progress.currentMembersCount}',
                  target: '${progress.effectiveTargetMembers}',
                  isMet: progress.isMembersTargetMet,
                  icon: Icons.group,
                ),
                _buildCriterionRow(
                  title: 'Liderança Preparada',
                  current: progress.hasLeaderInTraining
                      ? (progress.leaderInTrainingName ?? 'Definido')
                      : (progress.hasCoLeader ? (progress.coLeaderName ?? 'Co-líder') : 'Não definido'),
                  target: progress.effectiveRequiredRole == 'lider_treinamento'
                      ? 'Líder em Treinamento'
                      : progress.effectiveRequiredRole == 'colider'
                          ? 'Co-líder'
                          : 'LT ou Co-líder',
                  isMet: progress.isLeadershipTargetMet,
                  icon: Icons.person_outline,
                ),
                if (progress.effectiveRequireHost)
                  _buildCriterionRow(
                    title: 'Futuro Anfitrião / Local',
                    current: progress.futureHostDefined ? 'Definido' : 'Não definido',
                    target: 'Necessário',
                    isMet: progress.isHostTargetMet,
                    icon: Icons.home_outlined,
                  ),
                _buildCriterionRow(
                  title: 'Média de Visitantes',
                  current: progress.visitorAverage.toStringAsFixed(1),
                  target: '${progress.effectiveMinVisitorAvg}',
                  isMet: progress.isVisitorTargetMet,
                  icon: Icons.person_add_outlined,
                ),
                _buildCriterionRow(
                  title: 'Assiduidade Média',
                  current: '${progress.attendancePercentage.toStringAsFixed(1)}%',
                  target: '${progress.effectiveMinAttendance}%',
                  isMet: progress.isAttendanceTargetMet,
                  icon: Icons.trending_up,
                ),
                _buildCriterionRow(
                  title: 'Relatórios Entregues',
                  current: '${progress.reportRegularityPercentage.toStringAsFixed(1)}%',
                  target: '${progress.effectiveMinReportRegularity}%',
                  isMet: progress.isReportTargetMet,
                  icon: Icons.assignment_turned_in_outlined,
                ),
                _buildCriterionRow(
                  title: 'Tempo de Célula',
                  current: progress.isStartDateInFuture
                      ? 'Inicia em ${DateFormat('dd/MM/yyyy').format(progress.effectiveStartDate)}'
                      : '${progress.elapsedMonths} meses',
                  target: '${progress.effectiveTargetMonths} meses',
                  subtitle: 'Início: ${DateFormat('dd/MM/yyyy').format(progress.effectiveStartDate)} • Meta: ${DateFormat('dd/MM/yyyy').format(progress.targetEndDate)}${progress.isCustomStartDateActive ? " (Individual)" : ""}',
                  isMet: progress.isTimeTargetMet,
                  icon: Icons.timer_outlined,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('Editar Metas Individuais Desta Célula'),
                    onPressed: () => _openIndividualCellGoalsDialog(progress),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriterionRow({
    required String title,
    required String current,
    required String target,
    String? subtitle,
    required bool isMet,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Text(
                '$current (Meta: $target)',
                style: TextStyle(
                  fontSize: 12,
                  color: isMet ? Colors.green[700] : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isMet ? Icons.check_circle : Icons.cancel_outlined,
                size: 18,
                color: isMet ? Colors.green : Colors.grey[400],
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 26.0),
              child: Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
