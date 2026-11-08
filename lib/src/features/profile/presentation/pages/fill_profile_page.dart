// lib/src/features/profile/presentation/pages/fill_profile_page.dart

import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:celulas_app/src/features/auth/data/models/user_model.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FillProfilePage extends StatefulWidget {
  final UserEntity user;
  final VoidCallback onProfileUpdated;

  const FillProfilePage({
    super.key,
    required this.user,
    required this.onProfileUpdated,
  });

  @override
  State<FillProfilePage> createState() => _FillProfilePageState();
}

class _FillProfilePageState extends State<FillProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _authDataSource = getIt<AuthRemoteDataSource>();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _professionCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _originChurchCtrl;
  late TextEditingController _ministryCtrl;
  late TextEditingController _completedCoursesCtrl; // Novo campo para Cursos/Trilhas

  DateTime? _birthDate;
  DateTime? _conversionDate;
  DateTime? _waterBaptismDate;

  String? _gender;
  String? _maritalStatus;
  bool _isWaterBaptized = false;
  bool _isHolySpiritBaptized = false;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u.name);
    _phoneCtrl = TextEditingController(text: u.phone);
    _professionCtrl = TextEditingController(text: u.profession);
    _addressCtrl = TextEditingController(text: u.address);
    _originChurchCtrl = TextEditingController(text: u.originChurch);
    _ministryCtrl = TextEditingController(text: u.ministry);
    _completedCoursesCtrl = TextEditingController(text: u.completedCourses); // Inicializa

    _birthDate = u.birthDate;
    _conversionDate = u.conversionDate;
    _waterBaptismDate = u.waterBaptismDate;

    _gender = u.gender;
    _maritalStatus = u.maritalStatus;
    _isWaterBaptized = u.isWaterBaptized ?? false;
    _isHolySpiritBaptized = u.isHolySpiritBaptized ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _professionCtrl.dispose();
    _addressCtrl.dispose();
    _originChurchCtrl.dispose();
    _ministryCtrl.dispose();
    _completedCoursesCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
      BuildContext context,
      DateTime? initial,
      Function(DateTime) onSelected,
      ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => onSelected(picked));
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      final updatedModel = UserModel(
        id: widget.user.id,
        email: widget.user.email,
        photoUrl: widget.user.photoUrl,
        roles: widget.user.roles,
        primaryCellId: widget.user.primaryCellId,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        birthDate: _birthDate,
        gender: _gender,
        maritalStatus: _maritalStatus,
        profession: _professionCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        conversionDate: _conversionDate,
        isWaterBaptized: _isWaterBaptized,
        waterBaptismDate: _isWaterBaptized ? _waterBaptismDate : null,
        isHolySpiritBaptized: _isHolySpiritBaptized,
        originChurch: _originChurchCtrl.text.trim(),
        ministry: _ministryCtrl.text.trim(),
        completedCourses: _completedCoursesCtrl.text.trim(), // Salva o novo campo
      );

      await _authDataSource.updateUserProfile(updatedModel);
      widget.onProfileUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSaving ? null : _saveProfile,
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // CABEÇALHO DO PERFIL
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: widget.user.photoUrl != null &&
                        widget.user.photoUrl!.isNotEmpty
                        ? NetworkImage(widget.user.photoUrl!)
                        : null,
                    child: (widget.user.photoUrl == null ||
                        widget.user.photoUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.user.email,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SEÇÃO: DADOS PESSOAIS (OBRIGATÓRIOS)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dados Pessoais (Obrigatórios)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome Completo *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Informe seu nome completo'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp / Telefone *',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe seu WhatsApp para contato'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cake_outlined),
                      title: Text(
                        _birthDate == null
                            ? 'Data de Nascimento * (Clique para definir)'
                            : 'Nascimento: ${DateFormat('dd/MM/yyyy').format(_birthDate!)}',
                      ),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                      onTap: () => _selectDate(
                        context,
                        _birthDate,
                            (d) => _birthDate = d,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Sexo *',
                        prefixIcon: Icon(Icons.wc_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'masculino',
                          child: Text('Masculino'),
                        ),
                        DropdownMenuItem(
                          value: 'feminino',
                          child: Text('Feminino'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _gender = v),
                      validator: (v) =>
                      v == null ? 'Selecione o sexo' : null,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // SEÇÃO: INFORMAÇÕES COMPLEMENTARES (OPCIONAIS)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informações Complementares',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _maritalStatus,
                      decoration: const InputDecoration(
                        labelText: 'Estado Civil',
                        prefixIcon: Icon(Icons.favorite_border),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'solteiro',
                          child: Text('Solteiro(a)'),
                        ),
                        DropdownMenuItem(
                          value: 'casado',
                          child: Text('Casado(a)'),
                        ),
                        DropdownMenuItem(
                          value: 'divorciado',
                          child: Text('Divorciado(a)'),
                        ),
                        DropdownMenuItem(
                          value: 'viuvo',
                          child: Text('Viúvo(a)'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _maritalStatus = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _professionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Profissão / Área de Atuação',
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Endereço Residencial',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // SEÇÃO: JORNADA ESPIRITUAL & MINISTERIAL (Com ordem cronológica ajustada)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jornada Espiritual & Ministerial',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Igreja de Origem / Sede
                    TextFormField(
                      controller: _originChurchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Igreja de Origem / Sede (Opcional)',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Data de Conversão / Decisão
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_available_outlined),
                      title: Text(
                        _conversionDate == null
                            ? 'Data de Conversão / Decisão (Opcional)'
                            : 'Conversão: ${DateFormat('dd/MM/yyyy').format(_conversionDate!)}',
                      ),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                      onTap: () => _selectDate(
                        context,
                        _conversionDate,
                            (d) => _conversionDate = d,
                      ),
                    ),
                    const Divider(height: 20),

                    // 3. Batismo nas Águas
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Batizado nas Águas'),
                      value: _isWaterBaptized,
                      onChanged: (v) => setState(() => _isWaterBaptized = v),
                    ),
                    if (_isWaterBaptized) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.water_drop_outlined),
                        title: Text(
                          _waterBaptismDate == null
                              ? 'Data do Batismo (Opcional)'
                              : 'Data Batismo: ${DateFormat('dd/MM/yyyy').format(_waterBaptismDate!)}',
                        ),
                        onTap: () => _selectDate(
                          context,
                          _waterBaptismDate,
                              (d) => _waterBaptismDate = d,
                        ),
                      ),
                    ],

                    // 4. Batizado no Espírito Santo
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Batizado no Espírito Santo'),
                      value: _isHolySpiritBaptized,
                      onChanged: (v) =>
                          setState(() => _isHolySpiritBaptized = v),
                    ),
                    const Divider(height: 20),

                    // 5. Cursos / Trilhas Concluídas
                    TextFormField(
                      controller: _completedCoursesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cursos / Trilhas Concluídas',
                        hintText: 'Ex: Encontro com Deus, Escola de Líderes',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 6. Ministério em que Serve
                    TextFormField(
                      controller: _ministryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ministério em que Serve',
                        hintText: 'Ex: Louvor, Recepção',
                        prefixIcon:
                        Icon(Icons.volunteer_activism_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: const Text('Salvar Alterações'),
            ),
          ],
        ),
      ),
    );
  }
}