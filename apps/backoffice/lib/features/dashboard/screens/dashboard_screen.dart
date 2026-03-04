import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../draws/providers/draws_provider.dart' show serverDateProvider;
import '../../../core/widgets/app_shell.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoRefresh());
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      final now = DateTime.now().toUtc();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      ref.invalidate(dashboardSummaryProvider(dateStr));
    });
  }

  @override
  Widget build(BuildContext context) {
    // Usar fecha del servidor (Rep. Dominicana) para que coincida con el backend; evita que "hoy" vacío por desfase UTC.
    final serverDateAsync = ref.watch(serverDateProvider);
    final serverDate = serverDateAsync.valueOrNull;
    final fallback = DateTime.now().toUtc();
    final dateStr = serverDate ?? '${fallback.year}-${fallback.month.toString().padLeft(2, '0')}-${fallback.day.toString().padLeft(2, '0')}';
    final summaryAsync = ref.watch(dashboardSummaryProvider(dateStr));

    ref.listen(dashboardSummaryProvider(dateStr), (prev, next) {
      next.whenData((_) {
        ref.read(lastDashboardRefreshProvider.notifier).state = DateTime.now();
      });
    });

    final lastRefresh = ref.watch(lastDashboardRefreshProvider);
    final currentTime = ref.watch(dashboardCurrentTimeProvider).value ?? DateTime.now();

    return AppShell(
      currentPath: '/dashboard',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Hora: ${_formatRefreshTime(currentTime)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (lastRefresh != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Datos actualizados: ${_formatRefreshTime(lastRefresh)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => ref.invalidate(dashboardSummaryProvider(dateStr)),
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refrescar datos',
                    style: IconButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          summaryAsync.when(
            data: (data) => _DashboardContent(data: data, dateStr: dateStr, ref: ref),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                    const SizedBox(height: 16),
                    Text('Error al cargar: $e', style: TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data, required this.dateStr, required this.ref});
  final Map<String, dynamic> data;
  final String dateStr;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final sales = data['sales'] as Map<String, dynamic>? ?? {};
    final voids = data['voids'] as Map<String, dynamic>? ?? {};
    final pos = data['pos'] as Map<String, dynamic>? ?? {};
    final draws = data['draws'] as List<dynamic>? ?? [];
    final hasDraws = draws.isNotEmpty;
    final pendingList = data['pendingResults'] as List<dynamic>? ?? [];
    final pendingCount = data['pendingResultsCount'] as int? ?? 0;
    final recentResults = data['recentResults'] as List<dynamic>? ?? [];
    final todayResults = data['todayResults'] as List<dynamic>? ?? [];

    final totalSales = (sales['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final ticketCount = sales['ticketCount'] as int? ?? 0;
    final voidCount = voids['count'] as int? ?? 0;
    final voidAmount = (voids['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final posOnline = pos['online'] as int? ?? 0;
    final posTotal = pos['total'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(
                  title: 'Ventas hoy',
                  value: _formatMoney(totalSales),
                  subtitle: '$ticketCount tickets',
                  icon: Icons.point_of_sale,
                  color: AppColors.primary,
                ),
                _MetricCard(
                  title: 'Tickets vendidos',
                  value: '$ticketCount',
                  subtitle: 'Hoy',
                  icon: Icons.confirmation_number,
                  color: AppColors.secondary,
                ),
                _MetricCard(
                  title: 'Anulaciones hoy',
                  value: '$voidCount',
                  subtitle: _formatMoney(voidAmount),
                  icon: Icons.cancel_outlined,
                  color: AppColors.warning,
                ),
                _MetricCard(
                  title: 'POS conectados',
                  value: '$posOnline / ${posTotal == 0 ? '—' : posTotal}',
                  subtitle: posOnline > 0 ? 'En línea' : 'Ninguno activo',
                  icon: Icons.devices,
                  color: posOnline > 0 ? AppColors.success : AppColors.textMuted,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text('Sorteos de hoy', style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (draws.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Column(
                              children: [
                                Text('No hay sorteos generados para hoy', style: TextStyle(color: AppColors.textMuted)),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () => _generateDraws(context, ref, dateStr),
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: const Text('Generar sorteos hoy'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Table(
                          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1.2)},
                          children: [
                            TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Lotería', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Hora', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Exposición', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                              ],
                            ),
                            ...draws.map<TableRow>((d) {
                              final draw = d as Map<String, dynamic>;
                              final lottery = draw['lottery'] as Map<String, dynamic>?;
                              final state = draw['state'] as String? ?? '—';
                              final exposure = (draw['exposure'] as num?)?.toDouble() ?? 0.0;
                              return TableRow(
                                children: [
                                  Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(lottery?['name']?.toString() ?? '—')),
                                  Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(draw['drawTime']?.toString() ?? '—')),
                                  Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: _StateChip(state: state)),
                                  Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(_formatMoney(exposure))),
                                ],
                              );
                            }),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.assignment, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Text('Resultados pendientes', style: Theme.of(context).textTheme.titleLarge),
                          if (pendingCount > 0) ...[
                            const SizedBox(width: 8),
                            Chip(
                              label: Text('$pendingCount'),
                              backgroundColor: AppColors.warning.withOpacity(0.2),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (pendingList.isEmpty)
                        Text('Ninguno', style: TextStyle(color: AppColors.textMuted))
                      else
                        ...pendingList.take(5).map((r) {
                          final row = r as Map<String, dynamic>;
                          final lottery = row['lottery'] as Map<String, dynamic>?;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('${lottery?['name'] ?? '—'} · ${row['drawTime'] ?? ''}', style: Theme.of(context).textTheme.bodyMedium),
                          );
                        }),
                      if (pendingCount > 5) Padding(padding: const EdgeInsets.only(top: 4), child: Text('+ ${pendingCount - 5} más', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: () => context.go('/results'),
                        child: const Text('Ir a Resultados'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment_turned_in, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Text('Resultados de hoy', style: Theme.of(context).textTheme.titleLarge),
                    if (todayResults.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text('${todayResults.length}'),
                        backgroundColor: AppColors.secondary.withOpacity(0.2),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                if (todayResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('No hay resultados ingresados para hoy.', style: TextStyle(color: AppColors.textMuted)),
                  )
                else
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.5),
                      1: FlexColumnWidth(0.6),
                      2: FlexColumnWidth(0.9),
                      3: FlexColumnWidth(0.6),
                      4: FlexColumnWidth(0.6),
                      5: FlexColumnWidth(0.6),
                    },
                    children: [
                      const TableRow(
                        children: [
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Lotería', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Hora', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('1era', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('2da', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('3ra', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                        ],
                      ),
                      ...todayResults.map<TableRow>((r) {
                        final row = r as Map<String, dynamic>;
                        final lottery = row['lottery'] as Map<String, dynamic>?;
                        final results = row['results'];
                        final status = row['status'] as String? ?? '—';
                        String primera = '—', segunda = '—', tercera = '—';
                        if (results is Map) {
                          primera = results['primera']?.toString() ?? '—';
                          segunda = results['segunda']?.toString() ?? '—';
                          tercera = results['tercera']?.toString() ?? '—';
                        }
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(lottery?['name']?.toString() ?? '—')),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(_drawTimeShort(row['drawTime']))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: _ResultStatusChip(status: status)),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(primera)),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(segunda)),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(tercera)),
                          ],
                        );
                      }),
                    ],
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: () => context.go('/results'), icon: const Icon(Icons.assignment), label: const Text('Ir a Resultados')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (recentResults.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text('Últimos resultados aprobados', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Table(
                    columnWidths: const {0: FlexColumnWidth(1.5), 1: FlexColumnWidth(0.8), 2: FlexColumnWidth(2)},
                    children: [
                      const TableRow(
                        children: [
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Lotería', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Hora', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Resultado', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                        ],
                      ),
                      ...recentResults.map<TableRow>((r) {
                        final row = r as Map<String, dynamic>;
                        final lottery = row['lottery'] as Map<String, dynamic>?;
                        final results = row['results'];
                        String resultStr = '—';
                        if (results != null) {
                          if (results is Map) {
                            resultStr = (results as Map).entries.map((e) => '${e.key}: ${e.value}').join(' · ');
                          } else {
                            resultStr = results.toString();
                          }
                        }
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(lottery?['name']?.toString() ?? '—')),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(row['drawTime']?.toString() ?? '—')),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(resultStr, style: Theme.of(context).textTheme.bodySmall)),
                          ],
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: () => context.go('/results'), icon: const Icon(Icons.assignment), label: const Text('Ver todos los resultados')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Tooltip(
                  message: hasDraws
                      ? 'Los sorteos de hoy ya están generados.'
                      : 'Genera todos los sorteos de hoy según los horarios configurados en Loterías.',
                  child: FilledButton.icon(
                    onPressed: hasDraws ? null : () => _generateDraws(context, ref, dateStr),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Generar sorteos hoy'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(onPressed: () => context.go('/draws'), icon: const Icon(Icons.event_note), label: const Text('Ver sorteos')),
                const SizedBox(width: 12),
                OutlinedButton.icon(onPressed: () => context.go('/pos-connected'), icon: const Icon(Icons.point_of_sale), label: const Text('POS conectados')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generateDraws(BuildContext context, WidgetRef ref, String dateStr) async {
    final api = ref.read(apiClientProvider);
    final resp = await api.post('/draws/generate', queryParams: {'date': dateStr}, body: {});
    if (context.mounted) {
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        ref.invalidate(dashboardSummaryProvider(dateStr));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sorteos generados')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${resp.body}')));
      }
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.color});
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 12),
                  Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 12),
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});
  final String state;

  @override
  Widget build(BuildContext context) {
    Color bg;
    if (state == 'open') bg = AppColors.success.withOpacity(0.2);
    else if (state == 'closed') bg = AppColors.warning.withOpacity(0.2);
    else if (state == 'posteado') bg = AppColors.primary.withOpacity(0.2);
    else bg = AppColors.textMuted.withOpacity(0.2);
    return Chip(
      label: Text(state, style: const TextStyle(fontSize: 12)),
      backgroundColor: bg,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ResultStatusChip extends StatelessWidget {
  const _ResultStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    String label;
    switch (status) {
      case 'approved':
        bg = AppColors.success.withOpacity(0.2);
        label = 'Aprobado';
        break;
      case 'pending_approval':
        bg = AppColors.warning.withOpacity(0.2);
        label = 'Pendiente';
        break;
      case 'rejected':
        bg = AppColors.danger.withOpacity(0.2);
        label = 'Rechazado';
        break;
      default:
        bg = AppColors.textMuted.withOpacity(0.2);
        label = status;
    }
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: bg,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

String _drawTimeShort(dynamic drawTime) {
  final s = drawTime?.toString() ?? '—';
  return s.length >= 5 ? s.substring(0, 5) : s;
}

String _formatMoney(double n) {
  if (n == 0) return 'RD\$ 0';
  return 'RD\$ ${n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2)}';
}

String _formatRefreshTime(DateTime dt) {
  final d = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  final t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  return '$d $t';
}
