import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';

class PastorDashboardWidget extends StatelessWidget {
  const PastorDashboardWidget({super.key});

  Future<Map<String, int>> _fetchPastorStats() async {
    final firestore = FirebaseFirestore.instance;

    final cellsSnapshot = await firestore.collection('cells').get();
    final membersSnapshot = await firestore.collection('members').get();

    return {
      'cells': cellsSnapshot.docs.length,
      'members': membersSnapshot.docs.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _fetchPastorStats(),
      builder: (context, snapshot) {
        int cellsCount = 0;
        int membersCount = 0;

        if (snapshot.hasData) {
          cellsCount = snapshot.data!['cells'] ?? 0;
          membersCount = snapshot.data!['members'] ?? 0;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visão Geral das Células',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.groups, size: 28, color: Colors.purple),
                        const SizedBox(height: 8),
                        snapshot.connectionState == ConnectionState.waiting
                            ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : Text(
                          '$cellsCount',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Células',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.person, size: 28, color: Colors.blue),
                        const SizedBox(height: 8),
                        snapshot.connectionState == ConnectionState.waiting
                            ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : Text(
                          '$membersCount',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Membros',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: ListTile(
                leading: const Icon(Icons.bar_chart, color: Colors.deepPurple),
                title: const Text(
                  'Relatório de Crescimento Geral',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Acompanhar frequência e multiplicadores',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Ação futura para relatórios gerais
                },
              ),
            ),
          ],
        );
      },
    );
  }
}