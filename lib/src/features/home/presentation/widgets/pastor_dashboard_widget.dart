import 'package:flutter/material.dart';

class PastorDashboardWidget extends StatelessWidget {
  const PastorDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visão Geral das Células',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                title: 'Total Células',
                value: '12',
                icon: Icons.group,
                color: Colors.purple.shade100,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                context,
                title: 'Total Membros',
                value: '148',
                icon: Icons.person,
                color: Colors.blue.shade100,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('Relatório de Crescimento Geral'),
            subtitle: const Text('Acompanhar frequência e multiplicadores'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

Widget _buildMetricCard(
  BuildContext context, {
  required String title,
  required String value,
  required IconData icon,
  required Color color,
}) {
  return Card(
    color: color,
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    ),
  );
}
