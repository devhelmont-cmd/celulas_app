import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/cells/domain/entities/cell_entity.dart';
import 'package:celulas_app/src/features/cells/presentation/controllers/cell_controller.dart';
import 'package:celulas_app/src/features/cells/presentation/controllers/cell_state.dart';
import 'package:flutter/material.dart';

class CreateCellPage extends StatefulWidget {
  const CreateCellPage({super.key});

  @override
  State<CreateCellPage> createState() => _CreateCellPageState();
}

class _CreateCellPageState extends State<CreateCellPage> {
  final _cellController = getIt<CellController>();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _neighborhoodController = TextEditingController();

  String _selectedDay = 'Terça-feira';
  String _selectedCategory = 'Geral';
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 30);

  final List<String> _daysOfWeek = const [
    'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira',
    'Sexta-feira', 'Sábado', 'Domingo',
  ];

  final List<String> _categories = const [
    'Geral', 'Jovens', 'Casais', 'Adultos',
    'Kids', 'Mulheres', 'Homens', 'Adolescentes',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _neighborhoodController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      final newCell = CellEntity(
        id: '',
        name: _nameController.text.trim(),
        leaderId: null, // Será atribuído posteriormente
        coLeaderId: null, // Será atribuído posteriormente
        hostId: null, // Será atribuído posteriormente
        address: _addressController.text.trim(),
        neighborhood: _neighborhoodController.text.trim(),
        meetingDay: _selectedDay,
        meetingTime: _formatTimeOfDay(_selectedTime),
        category: _selectedCategory,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final success = await _cellController.createCell(newCell);

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Célula cadastrada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova Célula')),
      body: ValueListenableBuilder<CellState>(
        valueListenable: _cellController,
        builder: (context, state, child) {
          final isLoading = state is CellLoadingState;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state is CellErrorState) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        state.message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Text(
                    'Informações Básicas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _nameController,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Célula *',
                      prefixIcon: Icon(Icons.groups_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Informe o nome da célula';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(value: category, child: Text(category));
                    }).toList(),
                    onChanged: isLoading ? null : (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Dia e Horário das Reuniões',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedDay,
                          decoration: const InputDecoration(
                            labelText: 'Dia da Semana',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: _daysOfWeek.map((day) {
                            return DropdownMenuItem(
                              value: day,
                              child: Text(day, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: isLoading ? null : (val) {
                            if (val != null) setState(() => _selectedDay = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: isLoading ? null : () => _selectTime(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Horário',
                              prefixIcon: Icon(Icons.access_time_outlined),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _formatTimeOfDay(_selectedTime),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Localização',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _addressController,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Endereço (Rua, Número, Comp.) *',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Informe o endereço da célula';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _neighborhoodController,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Bairro *',
                      prefixIcon: Icon(Icons.map_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Informe o bairro';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: isLoading ? null : _submitForm,
                      child: isLoading
                          ? const SizedBox(
                        height: 24, width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Text('Cadastrar Célula', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}