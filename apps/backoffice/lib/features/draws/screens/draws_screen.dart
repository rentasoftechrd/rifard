import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../../lotteries/providers/lotteries_provider.dart';
import '../providers/draws_provider.dart' show drawsDateFilterProvider, drawsLotteryFilterProvider, drawsListProvider, exposureProvider, serverDateProvider, serverTimeLabelProvider, todayDateStr;

/// Etiquetas en español para estados del sorteo (reglas de negocio).
String _drawStateLabel(String state) {
  switch (state) {
    case 'scheduled':
      return 'Programado';
    case 'open':
      return 'Abierto';
    case 'closed':
      return 'Cerrado';
    case 'posteado':
      return 'Posteado';
    default:
      return state.isEmpty ? '—' : state;
  }
}

class DrawsScreen extends ConsumerStatefulWidget {
  const DrawsScreen({super.key});

  @override
  ConsumerState<DrawsScreen> createState() => _DrawsScreenState();
}

class _DrawsScreenState extends ConsumerState<DrawsScreen> {
  late final TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: ref.read(drawsDateFilterProvider));
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(drawsDateFilterProvider);
    final serverDate = ref.watch(serverDateProvider).valueOrNull;
    // Sincronizar filtro con fecha del servidor para que "hoy" coincida con el backend.
    if (serverDate != null && serverDate.isNotEmpty && date == todayDateStr() && date != serverDate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(drawsDateFilterProvider) == date) {
          ref.read(drawsDateFilterProvider.notifier).state = serverDate;
        }
      });
    }
    final lotteryId = ref.watch(drawsLotteryFilterProvider);
    final listAsync = ref.watch(drawsListProvider);
    final lotteriesAsync = ref.watch(lotteriesListProvider);

    return AppShell(
      currentPath: '/draws',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Icon(Icons.event, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text('Sorteos', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Aquí se generan los sorteos del día según los horarios de cada lotería (configurados en Loterías). '
              'Luego puedes abrirlos o cerrarlos para permitir ventas en POS e ingresar resultados.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 180,
                      child: InkWell(
                        onTap: () => _pickDate(context),
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fecha',
                            border: OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: Icon(Icons.calendar_today, size: 20),
                          ),
                          child: Text(date, style: Theme.of(context).textTheme.bodyLarge),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          final serverToday = await ref.read(serverDateProvider.future);
                          _dateController.text = serverToday;
                          ref.read(drawsDateFilterProvider.notifier).update((_) => serverToday);
                        } catch (_) {
                          final today = todayDateStr();
                          _dateController.text = today;
                          ref.read(drawsDateFilterProvider.notifier).update((_) => today);
                        }
                      },
                      child: const Text('Hoy'),
                    ),
                    const SizedBox(width: 16),
                    if (lotteriesAsync.hasValue) ...[
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
                        child: DropdownButtonFormField<String?>(
                          value: lotteryId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Lotería',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Todas', overflow: TextOverflow.ellipsis)),
                            ...(lotteriesAsync.value ?? []).map((l) {
                              final m = l as Map<String, dynamic>;
                              final name = m['name']?.toString() ?? '—';
                              return DropdownMenuItem<String?>(
                                value: m['id'] as String?,
                                child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1),
                              );
                            }),
                          ],
                          selectedItemBuilder: (context) {
                            final list = lotteriesAsync.value ?? [];
                            return [
                              const Row(children: [Expanded(child: Text('Todas', overflow: TextOverflow.ellipsis, maxLines: 1))]),
                              ...list.map((l) {
                                final name = (l as Map<String, dynamic>)['name']?.toString() ?? '—';
                                return Row(children: [Expanded(child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1))]);
                              }),
                            ];
                          },
                          onChanged: (v) => ref.read(drawsLotteryFilterProvider.notifier).update((_) => v),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    const SizedBox(width: 16),
                    ref.watch(serverDateProvider).when(
                      data: (serverToday) {
                        final isFuture = date.compareTo(serverToday) > 0;
                        return _buildGenerateButton(listAsync, date, isFuture);
                      },
                      loading: () => _buildGenerateButton(listAsync, date, false),
                      error: (_, __) => _buildGenerateButton(listAsync, date, false),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ref.watch(serverTimeLabelProvider).when(
            data: (label) => label.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Text(
                              'Hora servidor: $label',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Flujo: Programado → Abierto (venta en POS) → Cerrado (ingresar resultado en Resultados) → Posteado (al aprobar).',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Colores: Verde = Abierto · Amarillo = Por cerrar · Rojo = Cerrado',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          listAsync.when(
            data: (list) => _DrawsTable(
              list: list,
              onStateChanged: (draw, newState) => _changeState(context, draw, newState),
              onExposure: (draw) => _showExposure(context, draw),
            ),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.danger),
                    const SizedBox(width: 16),
                    Expanded(child: Text('Error: $e', style: TextStyle(color: AppColors.danger))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(AsyncValue<List<dynamic>> listAsync, String date, bool isFuture) {
    final list = listAsync.valueOrNull ?? [];
    final alreadyGenerated = list.isNotEmpty;
    final canGenerate = !isFuture && !alreadyGenerated;
    String message = 'Genera todos los sorteos del día según horarios de cada lotería';
    if (alreadyGenerated) message = 'Los sorteos de este día ya fueron generados (solo se puede hacer una vez al día)';
    if (isFuture) message = 'Solo se pueden generar sorteos para hoy o fechas pasadas (fecha servidor)';
    return Tooltip(
      message: message,
      child: FilledButton.icon(
        onPressed: canGenerate ? () => _generateDraws(context, date) : null,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Generar sorteos del día'),
      ),
    );
  }

  Future<void> _generateDraws(BuildContext context, String dateStr) async {
    final api = ref.read(apiClientProvider);
    final resp = await api.post('/draws/generate', queryParams: {'date': dateStr}, body: {});
    if (!mounted) return;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      ref.read(drawsLotteryFilterProvider.notifier).update((_) => null);
      ref.invalidate(drawsListProvider);
      final data = resp.body.isNotEmpty ? (jsonDecode(resp.body) as Map<String, dynamic>?) : null;
      final created = (data?['created'] as List<dynamic>?)?.length ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sorteos generados: $created. Se muestran todos los del día.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${resp.body}')));
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final dateStr = ref.read(drawsDateFilterProvider);
    DateTime initial = DateTime.now();
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        initial = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    } catch (_) {}
    DateTime lastDate = DateTime.now();
    try {
      final serverDateStr = await ref.read(serverDateProvider.future);
      final p = serverDateStr.split('-');
      if (p.length == 3) lastDate = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (_) {}
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(lastDate) ? lastDate : initial,
      firstDate: DateTime(2020),
      lastDate: lastDate,
    );
    if (picked == null || !mounted) return;
    final s = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    _dateController.text = s;
    ref.read(drawsDateFilterProvider.notifier).update((_) => s);
  }

  Future<void> _changeState(BuildContext context, Map<String, dynamic> draw, String newState) async {
    final id = draw['id'] as String?;
    if (id == null) return;
    final api = ref.read(apiClientProvider);
    final resp = await api.put('/draws/$id/state', body: {'state': newState});
    if (!mounted) return;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      ref.invalidate(drawsListProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Estado: $newState')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${resp.body}')));
    }
  }

  void _showExposure(BuildContext context, Map<String, dynamic> draw) {
    final drawId = draw['id'] as String?;
    if (drawId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => _ExposureDialog(drawId: drawId, draw: draw),
    );
  }
}

class _DrawsTable extends StatelessWidget {
  const _DrawsTable({required this.list, required this.onStateChanged, required this.onExposure});
  final List<dynamic> list;
  final void Function(Map<String, dynamic> draw, String newState) onStateChanged;
  final void Function(Map<String, dynamic>) onExposure;

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.event_busy, size: 64, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text('No hay sorteos para esta fecha', style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.8),
            1: FlexColumnWidth(0.7),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1.5),
          },
          children: [
            TableRow(
              children: [
                _th(context, 'Lotería', TextAlign.left),
                _th(context, 'Hora', TextAlign.center),
                _th(context, 'Estado', TextAlign.center),
                _th(context, 'Acciones', TextAlign.center),
              ],
            ),
            ...list.map<TableRow>((e) {
              final row = e as Map<String, dynamic>;
              final lottery = row['lottery'] as Map<String, dynamic>?;
              String time = row['drawTime']?.toString() ?? '—';
              if (time.length >= 5) time = time.substring(0, 5);
              final state = row['state']?.toString() ?? '—';
              final displayStatus = row['displayStatus']?.toString();
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Align(alignment: Alignment.centerLeft, child: Text(lottery?['name']?.toString() ?? '—')),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Center(child: Text(time))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: _StatusChip(state: state, displayStatus: displayStatus)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (state == 'scheduled' || state == 'open')
                            IconButton.filledTonal(
                              icon: const Icon(Icons.tune),
                              onPressed: () => _showChangeStateDialog(context, row, onStateChanged),
                              tooltip: 'Cambiar estado',
                            ),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.bar_chart, color: Colors.white),
                            onPressed: () => onExposure(row),
                            tooltip: 'Ver exposición',
                            style: IconButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _th(BuildContext context, String label, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: align == TextAlign.center ? Alignment.center : Alignment.centerLeft,
        child: Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
      ),
    );
  }

  static void _showChangeStateDialog(BuildContext context, Map<String, dynamic> draw, void Function(Map<String, dynamic>, String) onStateChanged) {
    final current = draw['state']?.toString() ?? '';
    final allowed = _allowedNextStates(current);
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar estado del sorteo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estado actual: ${_drawStateLabel(current)}', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 16),
              if (allowed.isEmpty)
                Text(
                  current == 'posteado'
                      ? 'Sorteo finalizado. No se puede cambiar.'
                      : 'Para marcar como Posteado, apruebe el resultado en Resultados.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                )
              else
                ...allowed.map((s) => ListTile(
                      title: Text(_drawStateLabel(s)),
                      subtitle: Text(_stateHint(s), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      onTap: () => Navigator.of(ctx).pop(s),
                    )),
            ],
          ),
        ),
      ),
    ).then((newState) {
      if (newState != null) onStateChanged(draw, newState);
    });
  }

  /// Transiciones permitidas: scheduled→open, open→closed. closed/posteado no se cambian desde aquí.
  static List<String> _allowedNextStates(String current) {
    switch (current) {
      case 'scheduled':
        return ['open'];
      case 'open':
        return ['closed'];
      default:
        return [];
    }
  }

  static String _stateHint(String state) {
    switch (state) {
      case 'open':
        return 'Permite vender jugadas en POS';
      case 'closed':
        return 'No se aceptan más jugadas; se puede ingresar resultado';
      default:
        return '';
    }
  }
}

/// Chip que usa displayStatus del backend: verde=abierto, amarillo=por cerrar, rojo=cerrado, gris=programado.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state, this.displayStatus});
  final String state;
  final String? displayStatus;

  @override
  Widget build(BuildContext context) {
    final status = displayStatus ?? state;
    Color bg;
    String label;
    switch (status) {
      case 'open':
        bg = AppColors.success.withOpacity(0.25);
        label = 'Abierto';
        break;
      case 'closing_soon':
        bg = AppColors.warning.withOpacity(0.25);
        label = 'Por cerrar';
        break;
      case 'closed':
        bg = AppColors.danger.withOpacity(0.25);
        label = 'Cerrado';
        break;
      case 'scheduled':
        bg = AppColors.textMuted.withOpacity(0.25);
        label = 'Programado';
        break;
      case 'posteado':
        bg = AppColors.primary.withOpacity(0.2);
        label = 'Posteado';
        break;
      default:
        bg = AppColors.textMuted.withOpacity(0.2);
        label = _drawStateLabel(state);
    }
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: bg,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ExposureDialog extends ConsumerWidget {
  const _ExposureDialog({required this.drawId, required this.draw});
  final String drawId;
  final Map<String, dynamic> draw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exposureAsync = ref.watch(exposureProvider(drawId));
    final lottery = draw['lottery'] as Map<String, dynamic>?;
    final name = lottery?['name'] ?? 'Sorteo';
    String time = draw['drawTime']?.toString() ?? '';
    if (time.length >= 5) time = time.substring(0, 5);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bar_chart, color: AppColors.secondary),
          const SizedBox(width: 8),
          Text('Exposición — $name $time'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: exposureAsync.when(
          data: (data) {
            final global = (data['global'] as num?)?.toDouble() ?? 0.0;
            final byNumber = data['byNumber'] as Map<String, dynamic>? ?? {};
            final byBetType = data['byBetType'] as Map<String, dynamic>? ?? {};
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row('Total', _formatMoney(global)),
                  const Divider(),
                  if (byNumber.isNotEmpty) ...[
                    Text('Por número', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ...byNumber.entries.map((e) => _row(e.key.toString(), _formatMoney((e.value as num).toDouble()))),
                    const SizedBox(height: 12),
                  ],
                  if (byBetType.isNotEmpty) ...[
                    Text('Por tipo', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ...byBetType.entries.map((e) => _row(e.key.toString(), _formatMoney((e.value as num).toDouble()))),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (e, _) => Text('Error: $e', style: TextStyle(color: AppColors.danger)),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar'))],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: const TextStyle(color: AppColors.textMuted)), Text(value)],
      ),
    );
  }

  String _formatMoney(double n) {
    if (n == 0) return 'RD\$ 0';
    return 'RD\$ ${n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2)}';
  }
}
