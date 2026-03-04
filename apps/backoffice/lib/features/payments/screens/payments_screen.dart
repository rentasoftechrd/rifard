import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../providers/payments_provider.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final _codeController = TextEditingController();
  String _searchCode = '';
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _error = 'Ingrese el código del ticket';
        _data = null;
      });
      return;
    }
    setState(() {
      _searchCode = code;
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final data = await getTicketForPayment(ref, code);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _data = data;
        if (data == null) _error = 'Ticket no encontrado o error al buscar.';
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Error: $e';
        _data = null;
      });
    }
  }

  Future<void> _markAsPaid() async {
    final ticket = _data?['ticket'] as Map<String, dynamic>?;
    final id = ticket?['id'] as String?;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final updated = await markTicketAsPaid(ref, id);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _data = updated;
        if (updated != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket marcado como pagado.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo marcar como pagado.'), backgroundColor: AppColors.danger),
          );
        }
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentPath: '/payments',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Icon(Icons.paid, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text('Pagos', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Después de aprobar los resultados, busque el ticket por código o escanee el código de barras. '
            'Si es ganador podrá marcarlo como pagado. Si la persona intenta cobrar en otro punto verá que ya fue pagado.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Buscar ticket', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            labelText: 'Código del ticket',
                            hintText: 'Ej. P-1234567890-abc123 o escanee código de barras',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: _loading ? null : _search,
                        icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
                        label: const Text('Buscar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.danger.withOpacity(0.15),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.danger),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!, style: TextStyle(color: AppColors.danger))),
                  ],
                ),
              ),
            ),
          ],
          if (_data != null) ...[
            const SizedBox(height: 24),
            _PaymentTicketCard(
              data: _data!,
              onMarkPaid: _data?['canBePaid'] == true ? _markAsPaid : null,
              loading: _loading,
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentTicketCard extends StatelessWidget {
  const _PaymentTicketCard({required this.data, this.onMarkPaid, this.loading = false});
  final Map<String, dynamic> data;
  final VoidCallback? onMarkPaid;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ticket = data['ticket'] as Map<String, dynamic>? ?? {};
    final lines = data['linesWithWinning'] as List<dynamic>? ?? [];
    final totalWinning = (data['totalWinningAmount'] as num?)?.toDouble() ?? 0.0;
    final canBePaid = data['canBePaid'] == true;
    final message = data['message'] as String?;
    final status = ticket['status'] as String? ?? '—';
    final paidAt = ticket['paidAt'];
    final paidBy = ticket['paidBy'] as Map<String, dynamic>?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Código: ${ticket['ticketCode'] ?? '—'}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 12),
                _StatusChip(status: status),
              ],
            ),
            if (message != null && message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message, style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w500)),
            ],
            if (paidAt != null || paidBy != null) ...[
              const SizedBox(height: 8),
              Text(
                'Pagado${paidAt != null ? ' · ${paidAt.toString().substring(0, 19)}' : ''}${paidBy != null ? ' por ${paidBy['fullName'] ?? '—'}' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 16),
            Text('Líneas', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1), 2: FlexColumnWidth(0.8), 3: FlexColumnWidth(0.8)},
              children: [
                const TableRow(
                  children: [
                    Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Lotería', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                    Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Números / Tipo', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                    Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Gana', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                    Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Monto', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                  ],
                ),
                ...lines.map<TableRow>((l) {
                  final line = l as Map<String, dynamic>;
                  final lottery = line['lottery'] as Map?;
                  final isWinner = line['isWinner'] == true;
                  final payout = (line['winningPayout'] as num?)?.toDouble() ?? 0.0;
                  return TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(lottery?['name']?.toString() ?? '—')),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('${line['numbers']} · ${line['betType'] ?? '—'}'),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: isWinner ? Icon(Icons.check_circle, color: AppColors.success, size: 20) : const Text('—'),
                      ),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(payout > 0 ? '\$${payout.toStringAsFixed(2)}' : '—')),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Total a pagar: ', style: Theme.of(context).textTheme.titleMedium),
                Text('\$${totalWinning.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
              ],
            ),
            if (onMarkPaid != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: loading ? null : onMarkPaid,
                icon: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.paid),
                label: Text(loading ? 'Guardando...' : 'Marcar como pagado'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'sold':
        color = AppColors.primary;
        label = 'Vendido';
        break;
      case 'paid':
        color = AppColors.success;
        label = 'Pagado';
        break;
      case 'voided':
        color = AppColors.danger;
        label = 'Anulado';
        break;
      default:
        color = AppColors.textMuted;
        label = status;
    }
    return Chip(
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      backgroundColor: color.withOpacity(0.2),
      padding: EdgeInsets.zero,
    );
  }
}
