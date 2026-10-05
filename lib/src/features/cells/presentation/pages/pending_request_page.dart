import 'package:flutter/material.dart';

import '../../../../core/injections/injection_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../data/models/cell_join_request_model.dart';

class PendingRequestPage extends StatefulWidget {
  final CellJoinRequestEntity? request;
  final VoidCallback onRefresh;
  final Future<void> Function()? onCancel;

  const PendingRequestPage({
    super.key,
    required this.request,
    required this.onRefresh,
    this.onCancel,
  });

  @override
  State<PendingRequestPage> createState() => _PendingRequestPageState();
}

class _PendingRequestPageState extends State<PendingRequestPage> {
  bool _isCancelling = false;

  Future<void> _confirmAndCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Solicitação?'),
        content: const Text(
          'Tem certeza de que deseja cancelar esta solicitação? Você poderá escolher outra célula em seguida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancelar Solicitação'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);

    if (widget.onCancel != null) {
      await widget.onCancel!();
    }

    if (mounted) {
      setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitação em Análise'),
        actions: [
          IconButton(
            onPressed: () async {
              await getIt<AuthController>().signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Aguardando Aprovação',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.request != null
                  ? 'A sua solicitação para entrar na célula "${widget.request!.cellName}" foi enviada e está a ser analisada pelo líder.'
                  : 'A sua solicitação foi enviada e está a ser analisada pelo líder da célula.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isCancelling ? null : widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Verificar Estado'),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _isCancelling ? null : () => _confirmAndCancel(context),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.error,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _isCancelling
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.error,
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.close_rounded,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cancelar Solicitação',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}