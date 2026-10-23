// lib/src/features/home/presentation/widgets/pastor_dashboard_widget.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PastorNotifications {
  final int pendingJoinRequestsCount;
  final int pendingDeletionRequestsCount;
  final int pendingReportsCount;
  final int pendingRolesCount;

  PastorNotifications({
    required this.pendingJoinRequestsCount,
    required this.pendingDeletionRequestsCount,
    required this.pendingReportsCount,
    required this.pendingRolesCount,
  });
}

class PastorDashboardWidget extends StatelessWidget {
  final Function(int tabIndex, {bool selectPastoralView})? onNavigateTab;

  const PastorDashboardWidget({
    super.key,
    this.onNavigateTab,
  });

  Future<Map<String, dynamic>> _fetchPastorData() async {
    final firestore = FirebaseFirestore.instance;

    // 1. Busca Células e Membros[cite: 77]
    final cellsSnapshot = await firestore.collection('cells').get();
    final membersSnapshot = await firestore.collection('members').get();

    // 2. Usuários requisitando entrar em células[cite: 77]
    final requestsSnapshot = await firestore
        .collection('cell_requests')
        .where('status', isEqualTo: 'pending')
        .get();
    final pendingJoinRequestsCount = requestsSnapshot.docs.length;

    int pendingDeletionRequestsCount = 0;
    int pendingReportsCount = 0;
    int pendingRolesCount = 0;

    final now = DateTime.now();

    for (var cellDoc in cellsSnapshot.docs) {
      final cellId = cellDoc.id;

      final meetingsSnapshot = await firestore
          .collection('cells')
          .doc(cellId)
          .collection('meetings')
          .get();

      bool cellHasPendingReport = false;
      bool cellHasPendingRoles = false;
      List<QueryDocumentSnapshot<Map<String, dynamic>>> validMeetings = [];

      for (var meetingDoc in meetingsSnapshot.docs) {
        final data = meetingDoc.data();

        // 3. Solicitação de exclusão de relatório / reunião[cite: 77]
        if (data['deletionRequested'] == true) {
          pendingDeletionRequestsCount++;
        }

        final DateTime meetingDate =
            (data['meetingDate'] as Timestamp?)?.toDate() ?? now;
        final bool isReportFilled = data['isReportFilled'] ?? false;

        // Expirou se passou do dia da ocorrência[cite: 77]
        final expiry = DateTime(meetingDate.year, meetingDate.month, meetingDate.day + 1);
        final bool isExpired = now.isAfter(expiry);

        // 4. Célula pendente de relatório (qualquer reunião passada não preenchida)[cite: 77]
        if (isExpired && !isReportFilled) {
          cellHasPendingReport = true;
        }

        // Coleta apenas reuniões futuras ou de hoje que NÃO estão canceladas[cite: 77]
        final status = data['status'] ?? 'normal';
        if (!isExpired && status != 'canceled') {
          validMeetings.add(meetingDoc);
        }
      }

      if (cellHasPendingReport) pendingReportsCount++;

      // 5. Célula pendente de funções: analisa APENAS a próxima reunião (mais próxima no futuro)
      if (validMeetings.isNotEmpty) {
        // Ordena da data mais próxima para a mais distante
        validMeetings.sort((a, b) {
          final dateA = (a.data()['meetingDate'] as Timestamp?)?.toDate() ?? now;
          final dateB = (b.data()['meetingDate'] as Timestamp?)?.toDate() ?? now;
          return dateA.compareTo(dateB);
        });

        // Pega exclusivamente a próxima reunião
        final nextMeetingData = validMeetings.first.data();
        final status = nextMeetingData['status'] ?? 'normal';

        if (status != 'canceled') {
          final bool rolesPending = (nextMeetingData['initialPrayerName'] == null || (nextMeetingData['initialPrayerName'] as String).trim().isEmpty) ||
              (nextMeetingData['icebreakerName'] == null || (nextMeetingData['icebreakerName'] as String).trim().isEmpty) ||
              (nextMeetingData['worshipName'] == null || (nextMeetingData['worshipName'] as String).isEmpty) ||
              (nextMeetingData['wordName'] == null || (nextMeetingData['wordName'] as String).isEmpty) ||
              (nextMeetingData['finalPrayerName'] == null || (nextMeetingData['finalPrayerName'] as String).isEmpty) ||
              (nextMeetingData['snackName'] == null || (nextMeetingData['snackName'] as String).isEmpty) ||
              (nextMeetingData['officialPhotoName'] == null || (nextMeetingData['officialPhotoName'] as String).isEmpty) ||
              (nextMeetingData['reportFillerName'] == null || (nextMeetingData['reportFillerName'] as String).isEmpty);

          if (rolesPending) {
            cellHasPendingRoles = true;
          }
        }
      }

      if (cellHasPendingRoles) pendingRolesCount++;
    }

    return {
      'cells': cellsSnapshot.docs.length,
      'members': membersSnapshot.docs.length,
      'notifications': PastorNotifications(
        pendingJoinRequestsCount: pendingJoinRequestsCount,
        pendingDeletionRequestsCount: pendingDeletionRequestsCount,
        pendingReportsCount: pendingReportsCount,
        pendingRolesCount: pendingRolesCount,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchPastorData(),
      builder: (context, snapshot) {
        int cellsCount = 0;
        int membersCount = 0;
        PastorNotifications? notifications;

        if (snapshot.hasData) {
          cellsCount = snapshot.data!['cells'] ?? 0;
          membersCount = snapshot.data!['members'] ?? 0;
          notifications = snapshot.data!['notifications'] as PastorNotifications?;
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

            // ================= NOTIFICAÇÕES DO PASTOR =================
            if (notifications != null) ...[
              if (notifications.pendingJoinRequestsCount > 0) ...[
                Card(
                  color: Colors.blue.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.blue.shade200),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.person_add, color: Colors.blue),
                    title: Text(
                      '${notifications.pendingJoinRequestsCount} Solicitação(ões) de Entrada',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Usuários aguardando aprovação para entrar na célula.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      onNavigateTab?.call(1);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (notifications.pendingDeletionRequestsCount > 0) ...[
                Card(
                  color: Colors.red.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.delete_sweep, color: Colors.red),
                    title: Text(
                      '${notifications.pendingDeletionRequestsCount} Solicitação(ões) de Exclusão',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Líderes solicitaram a exclusão de relatórios ou reuniões.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      onNavigateTab?.call(2, selectPastoralView: true);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (notifications.pendingReportsCount > 0) ...[
                Card(
                  color: Colors.amber.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.amber.shade300),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                    title: Text(
                      '${notifications.pendingReportsCount} Célula(s) com Relatórios Pendentes',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Reuniões que já aconteceram e ainda não foram preenchidas.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      onNavigateTab?.call(2, selectPastoralView: true);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (notifications.pendingRolesCount > 0) ...[
                Card(
                  color: Colors.orange.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.orange.shade200),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.assignment_ind_outlined, color: Colors.deepOrange),
                    title: Text(
                      '${notifications.pendingRolesCount} Célula(s) sem Atribuição de Funções',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Responsáveis pelas próximas reuniões pendentes.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      onNavigateTab?.call(1);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],

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
                onTap: () {},
              ),
            ),
          ],
        );
      },
    );
  }
}