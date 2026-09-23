import 'package:flutter/material.dart';

class MemberDashboardWidget extends StatelessWidget {
  const MemberDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.church, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Text(
                      'Minha Célula: Boanerges',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16),
                    SizedBox(width: 8),
                    Text('Quinta-feira às 19:30'),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('Rua das Oliveiras, 123'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Interações',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.favorite_outline),
                label: const Text('Pedir Oração'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.event_busy_outlined),
                label: const Text('Justificar Falta'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
