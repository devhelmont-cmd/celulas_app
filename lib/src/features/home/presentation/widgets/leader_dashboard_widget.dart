import 'package:flutter/material.dart';

class LeaderDashboardWidget extends StatelessWidget {
  const LeaderDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //Alerta de relatório pendente
        Card(
          color: Colors.amber.shade100,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Relatório da Semana Pendente',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Célula de Quinta-Feira',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Preencher'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Gestão da Minha Célula',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildQuickCard(
              context,
              icon: Icons.person_add_alt_1_outlined,
              label: 'Adicionar Membro',
              onTap: () {},
            ),
            _buildQuickCard(
              context,
              icon: Icons.event_note_outlined,
              label: 'Evento Ponte',
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }
}

Widget _buildQuickCard(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return Card(
    elevation: 1,
    /*clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),*/
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
