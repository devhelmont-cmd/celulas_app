import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/cell_reports/domain/repositories/i_cell_reports_repository.dart';
import 'package:celulas_app/src/features/cells/data/datasources/cell_remote_datasource.dart';
import 'package:celulas_app/src/features/members/presentation/pages/members_management_page.dart';

class PastorNotifications {
  final int pendingJoinRequestsCount;
  final int pendingDeletionRequestsCount;
  final int pendingReportsCount;
  final int pendingRolesCount;
  final int unlinkedMembersCount;
  final int pendingJustificationsCount;

  PastorNotifications({
    required this.pendingJoinRequestsCount,
    required this.pendingDeletionRequestsCount,
    required this.pendingReportsCount,
    required this.pendingRolesCount,
    required this.unlinkedMembersCount,
    required this.pendingJustificationsCount,
  });
}

class PastorDashboardWidget extends StatelessWidget {
  final UserEntity currentUser; // <--- Adicionado para resolver o erro do widget.currentUser
  final Function(int tabIndex, {int? cellTabInitialIndex, bool selectPastoralView})? onNavigateTab;

  const PastorDashboardWidget({
    super.key,
    required this.currentUser,
    this.onNavigateTab,
  });

  Future<Map<String, dynamic>> _fetchPastorData() async {
    final firestore = FirebaseFirestore.instance;
    final cellDataSource = getIt<ICellRemoteDataSource>(); // <--- Instanciado corretamente

    // 1. Busca Células e Membros
    final cellsSnapshot = await firestore.collection('cells').get();
    final membersSnapshot = await firestore.collection('members').get();

    // Busca a contagem de pessoas sem célula
    final unlinkedList = await cellDataSource.getUsersAndMembersWithoutCell();
    final unlinkedMembersCount = unlinkedList.length;

    // 2. Usuários requisitando entrar em células
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

        if (data['deletionRequested'] == true) {
          pendingDeletionRequestsCount++;
        }

        final DateTime meetingDate =
            (data['meetingDate'] as Timestamp?)?.toDate() ?? now;
        final bool isReportFilled = data['isReportFilled'] ?? false;

        final expiry = DateTime(meetingDate.year, meetingDate.month, meetingDate.day + 1);
        final bool isExpired = now.isAfter(expiry);

        if (isExpired && !isReportFilled) {
          cellHasPendingReport = true;
        }

        final status = data['status'] ?? 'normal';
        if (!isExpired && status != 'canceled') {
          validMeetings.add(meetingDoc);
        }
      }

      if (cellHasPendingReport) pendingReportsCount++;

      if (validMeetings.isNotEmpty) {
        validMeetings.sort((a, b) {
          final dateA = (a.data()['meetingDate'] as Timestamp?)?.toDate() ?? now;
          final dateB = (b.data()['meetingDate'] as Timestamp?)?.toDate() ?? now;
          return dateA.compareTo(dateB);
        });

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

    int pendingJustificationsCount = 0;
    try {
      final reportsRepo = getIt<ICellReportsRepository>();
      final allReports = await reportsRepo.getAllReports();
      for (var r in allReports) {
        for (var att in r.attendances) {
          if (att.isPendingApproval) pendingJustificationsCount++;
        }
      }
    } catch (_) {}

    return {
      'cells': cellsSnapshot.docs.length,
      'members': membersSnapshot.docs.length,
      'notifications': PastorNotifications(
        pendingJoinRequestsCount: pendingJoinRequestsCount,
        pendingDeletionRequestsCount: pendingDeletionRequestsCount,
        pendingReportsCount: pendingReportsCount,
        pendingRolesCount: pendingRolesCount,
        unlinkedMembersCount: unlinkedMembersCount,
        pendingJustificationsCount: pendingJustificationsCount,
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

      final isDark = Theme.of(context).brightness == Brightness.dark;

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
                child: InkWell(
                  onTap: () => onNavigateTab?.call(1, cellTabInitialIndex: 0),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.purple.shade900.withOpacity(0.3) : Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.groups, size: 28, color: isDark ? Colors.purple.shade300 : Colors.purple),
                        const SizedBox(height: 8),
                        snapshot.connectionState == ConnectionState.waiting
                            ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : Text(
                          '$cellsCount',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.purple.shade200 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Células',
                          style: TextStyle(color: isDark ? Colors.purple.shade300 : Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => onNavigateTab?.call(1, cellTabInitialIndex: 1),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.person, size: 28, color: isDark ? Colors.blue.shade300 : Colors.blue),
                        const SizedBox(height: 8),
                        snapshot.connectionState == ConnectionState.waiting
                            ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : Text(
                          '$membersCount',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.blue.shade200 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Membros',
                          style: TextStyle(color: isDark ? Colors.blue.shade300 : Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ================= NOTIFICAÇÕES DO PASTOR =================
          if (notifications != null) ...[
            if (notifications.unlinkedMembersCount > 0) ...[
              Card(
                color: isDark ? Colors.purple.shade900.withOpacity(0.3) : Colors.purple.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? Colors.purple.shade700 : Colors.purple.shade200),
                ),
                child: ListTile(
                  leading: Icon(Icons.person_off, color: isDark ? Colors.purple.shade300 : Colors.purple),
                  title: Text(
                    '${notifications.unlinkedMembersCount} Pessoa(s) sem Célula',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.purple.shade200 : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Membros ou usuários cadastrados aguardando vínculo.',
                    style: TextStyle(
                      color: isDark ? Colors.purple.shade300 : Colors.black54,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.purple.shade300 : Colors.grey),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MembersManagementPage(
                          currentUser: currentUser,
                          initialFilterWithoutCell: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (notifications.pendingJoinRequestsCount > 0) ...[
              Card(
                color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? Colors.blue.shade700 : Colors.blue.shade200),
                ),
                child: ListTile(
                  leading: Icon(Icons.person_add, color: isDark ? Colors.blue.shade300 : Colors.blue),
                  title: Text(
                    '${notifications.pendingJoinRequestsCount} Solicitação(ões) de Entrada',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.blue.shade200 : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Usuários aguardando aprovação para entrar na célula.',
                    style: TextStyle(
                      color: isDark ? Colors.blue.shade300 : Colors.black54,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.blue.shade300 : Colors.grey),
                  onTap: () {
                    onNavigateTab?.call(1);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (notifications.pendingJustificationsCount > 0) ...[
              Card(
                color: isDark ? Colors.amber.shade900.withOpacity(0.3) : Colors.amber.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? Colors.amber.shade700 : Colors.amber.shade300),
                ),
                child: ListTile(
                  leading: Icon(Icons.verified_user, color: isDark ? Colors.amber.shade300 : Colors.amber),
                  title: Text(
                    '${notifications.pendingJustificationsCount} Justificativa(s) de Falta Pendente(s)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.amber.shade200 : Colors.brown,
                    ),
                  ),
                  subtitle: Text(
                    'Solicitações de falta ou presença aguardando validação.',
                    style: TextStyle(
                      color: isDark ? Colors.amber.shade300 : Colors.brown.shade800,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.amber.shade300 : Colors.grey),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MembersManagementPage(
                          currentUser: currentUser,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (notifications.pendingDeletionRequestsCount > 0) ...[
              Card(
                color: isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? Colors.red.shade700 : Colors.red.shade200),
                ),
                child: ListTile(
                  leading: Icon(Icons.delete_sweep, color: isDark ? Colors.red.shade300 : Colors.red),
                  title: Text(
                    '${notifications.pendingDeletionRequestsCount} Solicitação(ões) de Exclusão',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.red.shade200 : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Líderes solicitaram a exclusão de relatórios ou reuniões.',
                    style: TextStyle(
                      color: isDark ? Colors.red.shade300 : Colors.black54,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.red.shade300 : Colors.grey),
                  onTap: () {
                    onNavigateTab?.call(2, selectPastoralView: true);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (notifications.pendingReportsCount > 0) ...[
              Card(
                color: isDark ? Colors.amber.shade900.withOpacity(0.3) : Colors.amber.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? Colors.amber.shade700 : Colors.amber.shade300),
                ),
                child: ListTile(
                  leading: Icon(Icons.warning_amber_rounded, color: isDark ? Colors.amber.shade300 : Colors.amber),
                  title: Text(
                    '${notifications.pendingReportsCount} Célula(s) com Relatórios Pendentes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.amber.shade200 : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Reuniões que já aconteceram e ainda não foram preenchidas.',
                    style: TextStyle(
                      color: isDark ? Colors.amber.shade300 : Colors.black54,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.amber.shade300 : Colors.grey),
                  onTap: () {
                    onNavigateTab?.call(2, selectPastoralView: true);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (notifications.pendingRolesCount > 0) ...[
              Card(
                color: isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? Colors.orange.shade700 : Colors.orange.shade200),
                ),
                child: ListTile(
                  leading: Icon(Icons.assignment_ind_outlined, color: isDark ? Colors.orange.shade300 : Colors.deepOrange),
                  title: Text(
                    '${notifications.pendingRolesCount} Célula(s) sem Atribuição de Funções',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.orange.shade200 : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Responsáveis pelas próximas reuniões pendentes.',
                    style: TextStyle(
                      color: isDark ? Colors.orange.shade300 : Colors.black54,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right, color: isDark ? Colors.orange.shade300 : Colors.grey),
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
              side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            ),
            child: ListTile(
              leading: Icon(Icons.bar_chart, color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple),
              title: Text(
                'Relatório de Crescimento Geral',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'Acompanhar frequência e multiplicadores',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
              onTap: () => onNavigateTab?.call(2),
            ),
          ),
        ],
      );
    },
    );
  }
}