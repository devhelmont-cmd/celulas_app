import 'package:flutter/material.dart';
import '../../domain/entities/cell_member_entity.dart';
import '../../data/models/cell_join_request_model.dart';

class ApproveRequestDialog extends StatefulWidget {
  final CellJoinRequestEntity request;
  final List<CellMemberEntity> currentMembers; // Membros atuais da célula

  const ApproveRequestDialog({
    super.key,
    required this.request,
    required this.currentMembers,
  });

  @override
  State<ApproveRequestDialog> createState() => _ApproveRequestDialogState();
}

class _ApproveRequestDialogState extends State<ApproveRequestDialog> {
  // Filtra apenas membros sem app (userId == null)
  late List<CellMemberEntity> _phantomMembers;
  String? _selectedPhantomMemberId;
  bool _isLinkingToExisting = false;

  @override
  void initState() {
    super.initState();
    _phantomMembers = widget.currentMembers
        .where((m) => m.userId == null || m.userId!.isEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Aprovar ${widget.request.userName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Como deseja adicionar este usuário à célula?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Opção 1: Criar novo membro
            RadioListTile<bool>(
              title: const Text('Cadastrar como Novo Membro'),
              subtitle: const Text('Cria um novo perfil de membro na célula.'),
              value: false,
              groupValue: _isLinkingToExisting,
              onChanged: (val) => setState(() {
                _isLinkingToExisting = val!;
                _selectedPhantomMemberId = null;
              }),
            ),

            // Opção 2: Vincular a membro fantasma existente (se houver)
            if (_phantomMembers.isNotEmpty) ...[
              RadioListTile<bool>(
                title: const Text('Vincular a Membro Sem App Já Cadastrado'),
                subtitle: const Text(
                  'Migra o histórico de presença do perfil manual para esta conta de usuário.',
                ),
                value: true,
                groupValue: _isLinkingToExisting,
                onChanged: (val) => setState(() => _isLinkingToExisting = val!),
              ),

              if (_isLinkingToExisting) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedPhantomMemberId,
                  decoration: const InputDecoration(
                    labelText: 'Selecione o membro manual',
                    border: OutlineInputBorder(),
                  ),
                  items: _phantomMembers.map((m) {
                    return DropdownMenuItem(
                      value: m.id,
                      child: Text(m.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedPhantomMemberId = val);
                  },
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLinkingToExisting && _selectedPhantomMemberId == null
              ? null
              : () {
            // Retorna um Map com a decisão
            Navigator.pop(context, {
              'action': 'approve',
              'matchedMemberId': _selectedPhantomMemberId,
            });
          },
          child: const Text('Confirmar Aprovação'),
        ),
      ],
    );
  }
}