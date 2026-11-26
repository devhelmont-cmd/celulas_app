// lib/src/features/cell_reports/presentation/widgets/multiplication_settings_dialog.dart

import 'package:celulas_app/src/features/cells/data/models/multiplication_settings_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MultiplicationSettingsDialog extends StatefulWidget {
  final MultiplicationSettingsModel initialSettings;

  const MultiplicationSettingsDialog({
    super.key,
    required this.initialSettings,
  });

  @override
  State<MultiplicationSettingsDialog> createState() =>
      _MultiplicationSettingsDialogState();
}

class _MultiplicationSettingsDialogState
    extends State<MultiplicationSettingsDialog> {
  late TextEditingController _monthsController;
  late TextEditingController _membersController;
  late TextEditingController _attendanceController;
  late TextEditingController _visitorController;
  late TextEditingController _reportsController;
  late String _requiredRole;
  late bool _requireHost;
  DateTime? _multiplicationStartDate;

  @override
  void initState() {
    super.initState();
    _monthsController =
        TextEditingController(text: widget.initialSettings.targetMonths.toString());
    _membersController =
        TextEditingController(text: widget.initialSettings.targetMembers.toString());
    _attendanceController = TextEditingController(
        text: widget.initialSettings.minAttendancePercentage.toString());
    _visitorController = TextEditingController(
        text: widget.initialSettings.minVisitorAverage.toString());
    _reportsController = TextEditingController(
        text: widget.initialSettings.minReportRegularityPercentage.toString());
    _requiredRole = widget.initialSettings.requiredLeadershipRole;
    _requireHost = widget.initialSettings.requireHost;
    _multiplicationStartDate = widget.initialSettings.multiplicationStartDate;
  }

  @override
  void dispose() {
    _monthsController.dispose();
    _membersController.dispose();
    _attendanceController.dispose();
    _visitorController.dispose();
    _reportsController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final initial = _multiplicationStartDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() => _multiplicationStartDate = picked);
    }
  }

  void _save() {
    final months = int.tryParse(_monthsController.text) ?? 6;
    final members = int.tryParse(_membersController.text) ?? 15;
    final attendance = double.tryParse(_attendanceController.text) ?? 80.0;
    final visitor = double.tryParse(_visitorController.text) ?? 3.0;
    final reports = double.tryParse(_reportsController.text) ?? 80.0;

    final updated = MultiplicationSettingsModel(
      targetMonths: months,
      targetMembers: members,
      minAttendancePercentage: attendance,
      minVisitorAverage: visitor,
      minReportRegularityPercentage: reports,
      requiredLeadershipRole: _requiredRole,
      requireHost: _requireHost,
      multiplicationStartDate: _multiplicationStartDate,
    );

    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Parâmetros de Multiplicação'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Defina os critérios exigidos para que uma célula esteja apta a se multiplicar:',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _monthsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Prazo Alvo (Meses)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer_outlined),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickStartDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Data de Início da Contagem (Global)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  suffixIcon: _multiplicationStartDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () => setState(() => _multiplicationStartDate = null),
                          tooltip: 'Limpar (Usar data de criação da célula)',
                        )
                      : null,
                ),
                child: Text(
                  _multiplicationStartDate != null
                      ? DateFormat('dd/MM/yyyy').format(_multiplicationStartDate!)
                      : 'Padrão (Data de criação de cada célula)',
                  style: TextStyle(
                    color: _multiplicationStartDate != null
                        ? Colors.black87
                        : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _membersController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantidade de Membros Necessária',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _attendanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Assiduidade Mínima dos Membros (%)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.trending_up),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _visitorController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Média Mínima de Visitantes por Reunião',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_add_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reportsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pontualidade de Relatórios (%)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.assignment_turned_in_outlined),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _requiredRole,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Cargo de Liderança Exigido',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'lider_treinamento_ou_colider',
                  child: Text(
                    'Líder em Treinamento ou Co-líder',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'lider_treinamento',
                  child: Text(
                    'Apenas Líder em Treinamento',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'colider',
                  child: Text(
                    'Apenas Co-líder',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _requiredRole = val);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Exigir Anfitrião / Local Definido'),
              value: _requireHost,
              onChanged: (val) => setState(() => _requireHost = val),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Salvar Parâmetros'),
        ),
      ],
    );
  }
}

